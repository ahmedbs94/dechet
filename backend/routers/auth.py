# routers/auth.py — Authentification, OTP, Social Auth, Password
import os
import random
import secrets
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from fastapi_mail import FastMail, MessageSchema, MessageType
from sqlalchemy.orm import Session
from typing import Union


import db_models as db_models
import models as models
from app.auth.service import (
    verify_password, get_password_hash,
    create_access_token, create_refresh_token, decode_refresh_token,
)
from database import get_db
from core.deps import get_current_user
from services.firebase_service import generate_custom_token, sync_user_to_firebase, update_admin_stats

router = APIRouter(tags=["auth"])

IS_DEV = os.getenv("APP_ENV", "development").lower() != "production"


def _mail_conf():
    from fastapi_mail import ConnectionConfig
    return ConnectionConfig(
        MAIL_USERNAME=os.getenv("MAIL_USERNAME"),
        MAIL_PASSWORD=os.getenv("MAIL_PASSWORD"),
        MAIL_FROM=os.getenv("MAIL_FROM"),
        MAIL_PORT=587,
        MAIL_SERVER="smtp.gmail.com",
        MAIL_STARTTLS=True,
        MAIL_SSL_TLS=False,
        USE_CREDENTIALS=True,
        VALIDATE_CERTS=True,
    )


def _generate_otp():
    return str(random.randint(100000, 999999))


# ── Register ─────────────────────────────────────────────────────────────────

@router.post("/register", response_model=models.User)
async def register(user: models.UserCreate, db: Session = Depends(get_db)):
    if db.query(db_models.User).filter(db_models.User.email == user.email).first():
        raise HTTPException(status_code=400, detail="Email already registered")
    new_user = db_models.User(
        email=user.email,
        full_name=user.full_name,
        hashed_password=get_password_hash(user.password),
        role=user.role,
        is_verified=False,
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    # ── Sync Firebase : met à jour total_users et new_users_month ────────────
    try:
        update_admin_stats(db)
    except Exception:
        pass  # Non bloquant
    return new_user


# ── OTP ───────────────────────────────────────────────────────────────────────

@router.post("/otp/send")
async def send_otp(request: models.OTPSendRequest, db: Session = Depends(get_db)):
    identifier = request.identifier.strip()
    if not identifier:
        raise HTTPException(status_code=400, detail="Identifiant requis")

    db.query(db_models.OTPCode).filter(
        db_models.OTPCode.identifier == identifier,
        db_models.OTPCode.is_used == False,
    ).update({"is_used": True})
    db.commit()

    code = _generate_otp()
    db.add(db_models.OTPCode(
        identifier=identifier, code=code, purpose="register",
        expires_at=datetime.utcnow() + timedelta(minutes=5), is_used=False,
    ))
    db.commit()

    if request.method == "email" and "@" in identifier:
        try:
            html = f"""<html><body style="font-family:Arial;padding:40px;">
            <div style="max-width:480px;margin:auto;background:#fff;border-radius:20px;padding:40px;">
            <h1 style="color:#1E293B;text-align:center;">EcoRewind 🌿</h1>
            <p style="color:#64748B;text-align:center;">Votre code de vérification :</p>
            <div style="background:linear-gradient(135deg,#00BFA6,#00E5A0);border-radius:16px;padding:24px;text-align:center;margin:24px 0;">
            <span style="font-size:36px;font-weight:900;color:white;letter-spacing:12px;font-family:monospace;">{code}</span>
            </div>
            <p style="color:#94A3B8;text-align:center;">Expire dans <strong>5 minutes</strong>.</p>
            </div></body></html>"""
            await FastMail(_mail_conf()).send_message(
                MessageSchema(subject="🔐 EcoRewind - Code de vérification",
                              recipients=[identifier], body=html, subtype=MessageType.html)
            )
            return {"success": True, "message": "Code envoyé par email", "method": "email"}
        except Exception as e:
            if IS_DEV:
                print(f"[DEV] OTP for {identifier}: {code}")
            return {"success": True, "message": "Code envoyé (mode dev)", "method": "email"}

    if IS_DEV:
        print(f"[DEV] OTP for {identifier}: {code}")
    return {"success": True, "message": "Code envoyé", "method": request.method}


@router.post("/otp/verify")
async def verify_otp(request: models.OTPVerifyRequest, db: Session = Depends(get_db)):
    identifier = request.identifier.strip()
    code = request.code.strip()
    if not identifier or not code:
        raise HTTPException(status_code=400, detail="Identifiant et code requis")

    otp = db.query(db_models.OTPCode).filter(
        db_models.OTPCode.identifier == identifier,
        db_models.OTPCode.code == code,
        db_models.OTPCode.is_used == False,
        db_models.OTPCode.expires_at > datetime.utcnow(),
    ).order_by(db_models.OTPCode.created_at.desc()).first()

    if not otp:
        expired = db.query(db_models.OTPCode).filter(
            db_models.OTPCode.identifier == identifier,
            db_models.OTPCode.code == code,
            db_models.OTPCode.is_used == False,
            db_models.OTPCode.expires_at <= datetime.utcnow(),
        ).first()
        if expired:
            raise HTTPException(status_code=410, detail="Le code a expiré.")
        raise HTTPException(status_code=400, detail="Code invalide")

    otp.is_used = True
    db.commit()

    user = db.query(db_models.User).filter(db_models.User.email == identifier).first()
    if user:
        user.is_verified = True
        db.commit()
        db.refresh(user)
        if getattr(user, "mfa_enabled", False):
            mfa_token = create_access_token({"sub": user.email, "mfa_pending": True}, expires_delta=timedelta(minutes=5))
            return {
                "success": True, "message": "MFA requis",
                "status": "mfa_required",
                "mfa_token": mfa_token,
                "id": user.id,
                "email": user.email,
            }
        access_token = create_access_token(data={"sub": user.email})
        # Synchronise les infos utilisateur dans Firebase pour identifier le QR code
        sync_user_to_firebase(
            user_id=user.id,
            role=user.role or "user",
            qr_code=user.qr_code or "",
            full_name=user.full_name or "",
            email=user.email or "",
            score=getattr(user, 'global_score', 0) or 0,
        )
        return {
            "success": True, "message": "Compte vérifié",
            "access_token": access_token, "token_type": "bearer",
            "role": user.role, "id": user.id,
            "email": user.email, "full_name": user.full_name, "qr_code": user.qr_code,
            "firebase_token": generate_custom_token(user.id),  # pour signInWithCustomToken() Flutter
        }
    return {"success": True, "message": "Code vérifié"}


# ── Token login ───────────────────────────────────────────────────────────────

@router.post("/token", response_model=Union[models.Token, models.MFAPendingResponse])
async def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(db_models.User).filter(db_models.User.email == form_data.username).first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED,
                            detail="Incorrect email or password",
                            headers={"WWW-Authenticate": "Bearer"})
    
    if getattr(user, "mfa_enabled", False):
        mfa_token = create_access_token({"sub": user.email, "mfa_pending": True}, expires_delta=timedelta(minutes=5))
        return {
            "status": "mfa_required",
            "mfa_token": mfa_token,
            "id": user.id,
            "email": user.email,
        }

    # Synchronise les infos utilisateur dans Firebase pour identifier le QR code
    sync_user_to_firebase(
        user_id=user.id,
        role=user.role or "user",
        qr_code=user.qr_code or "",
        full_name=user.full_name or "",
        email=user.email or "",
        score=getattr(user, 'global_score', 0) or 0,
    )
    return {
        "access_token": create_access_token({"sub": user.email}),
        "refresh_token": create_refresh_token({"sub": user.email}),
        "token_type": "bearer", "role": user.role,
        "id": user.id, "email": user.email,
        "full_name": user.full_name, "qr_code": user.qr_code,
        "avatar_url": user.avatar_url or "",
        "firebase_token": generate_custom_token(user.id),  # pour signInWithCustomToken() Flutter
    }


@router.post("/token/refresh")
async def refresh_token(body: models.RefreshTokenRequest, db: Session = Depends(get_db)):
    payload = decode_refresh_token(body.refresh_token)
    if payload is None:
        raise HTTPException(status_code=401, detail="Refresh token invalide ou expiré")
    email = payload.get("sub")
    if not email:
        raise HTTPException(status_code=401, detail="Token invalide")
    user = db.query(db_models.User).filter(db_models.User.email == email).first()
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="Utilisateur introuvable ou désactivé")
    return {
        "access_token": create_access_token({"sub": user.email}),
        "refresh_token": create_refresh_token({"sub": user.email}),
        "token_type": "bearer",
    }


@router.post("/auth/mfa/verify", response_model=models.Token)
async def verify_mfa_login(body: models.MFAVerifyLoginRequest, db: Session = Depends(get_db)):
    from jose import jwt, JWTError
    from app.auth.service import SECRET_KEY, ALGORITHM
    import pyotp

    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Jeton MFA invalide ou expiré",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(body.mfa_token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        mfa_pending: bool = payload.get("mfa_pending", False)
        if email is None or not mfa_pending:
            raise credentials_exception
    except JWTError:
        raise credentials_exception

    user = db.query(db_models.User).filter(db_models.User.email == email).first()
    if not user or not user.is_active:
        raise HTTPException(status_code=401, detail="Utilisateur introuvable ou désactivé")

    if not user.mfa_secret:
        raise HTTPException(status_code=400, detail="MFA non configuré pour cet utilisateur")

    totp = pyotp.TOTP(user.mfa_secret)
    if not totp.verify(body.code, valid_window=1):
        raise HTTPException(status_code=401, detail="Code de validation incorrect ou expiré")

    # Synchronise les infos utilisateur dans Firebase pour identifier le QR code
    sync_user_to_firebase(
        user_id=user.id,
        role=user.role or "user",
        qr_code=user.qr_code or "",
        full_name=user.full_name or "",
        email=user.email or "",
        score=getattr(user, 'global_score', 0) or 0,
    )
    return {
        "access_token": create_access_token({"sub": user.email}),
        "refresh_token": create_refresh_token({"sub": user.email}),
        "token_type": "bearer", "role": user.role,
        "id": user.id, "email": user.email,
        "full_name": user.full_name, "qr_code": user.qr_code,
        "avatar_url": user.avatar_url or "",
        "firebase_token": generate_custom_token(user.id),  # pour signInWithCustomToken() Flutter
    }


# ── Social Auth ───────────────────────────────────────────────────────────────

@router.post("/auth/google", response_model=Union[models.Token, models.MFAPendingResponse])
async def google_auth(google_data: models.GoogleAuth, db: Session = Depends(get_db)):
    from google.oauth2 import id_token
    from google.auth.transport import requests as g_requests
    GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "")
    try:
        is_jwt = len(google_data.token.split(".")) == 3
        if not is_jwt:
            import requests as http_req
            resp = http_req.get(f"https://www.googleapis.com/oauth2/v3/userinfo?access_token={google_data.token}")
            if resp.status_code != 200:
                raise ValueError("Access Token Google invalide")
            id_info = resp.json()
        else:
            id_info = id_token.verify_oauth2_token(google_data.token, g_requests.Request(), GOOGLE_CLIENT_ID)

        email = id_info.get("email")
        full_name = id_info.get("name")
        sub = id_info.get("sub")

        user = db.query(db_models.User).filter(db_models.User.email == email).first()
        if not user:
            user = db_models.User(email=email, full_name=full_name,
                                  hashed_password="", google_id=sub, is_active=True)
            db.add(user)
            db.commit()
            db.refresh(user)

        if getattr(user, "mfa_enabled", False):
            mfa_token = create_access_token({"sub": user.email, "mfa_pending": True}, expires_delta=timedelta(minutes=5))
            return {
                "status": "mfa_required",
                "mfa_token": mfa_token,
                "id": user.id,
                "email": user.email,
            }

        # Synchronise les infos utilisateur dans Firebase pour identifier le QR code
        sync_user_to_firebase(
            user_id=user.id,
            role=user.role or "user",
            qr_code=user.qr_code or "",
            full_name=user.full_name or "",
            email=user.email or "",
            score=getattr(user, 'global_score', 0) or 0,
        )
        return {"access_token": create_access_token({"sub": email}),
                "token_type": "bearer", "role": user.role,
                "id": user.id, "email": user.email,
                "full_name": user.full_name, "qr_code": user.qr_code,
                "avatar_url": user.avatar_url or "",
                "firebase_token": generate_custom_token(user.id)}  # pour signInWithCustomToken() Flutter
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Erreur Google: {str(e)}")


@router.post("/auth/facebook", response_model=Union[models.Token, models.MFAPendingResponse])
async def facebook_auth(fb_data: models.FacebookAuth, db: Session = Depends(get_db)):
    import requests as http_req
    try:
        resp = http_req.get("https://graph.facebook.com/me",
                            params={"access_token": fb_data.access_token,
                                    "fields": "id,name,email,picture"}, timeout=10)
        if resp.status_code != 200:
            raise HTTPException(status_code=401, detail="Token Facebook invalide")
        fb_info = resp.json()
        if "error" in fb_info:
            raise HTTPException(status_code=401, detail=fb_info["error"].get("message", "Erreur Facebook"))

        facebook_id = fb_info.get("id")
        full_name = fb_info.get("name", "Utilisateur Facebook")
        email = fb_info.get("email")
        if not facebook_id:
            raise HTTPException(status_code=400, detail="ID Facebook introuvable")

        user = db.query(db_models.User).filter(db_models.User.facebook_id == facebook_id).first()
        if not user and email:
            user = db.query(db_models.User).filter(db_models.User.email == email).first()
        if not user:
            fallback_email = email or f"fb_{facebook_id}@noemail.ecorewind.local"
            user = db_models.User(email=fallback_email, full_name=full_name,
                                  hashed_password="", facebook_id=facebook_id,
                                  is_active=True, role="user")
            db.add(user)
            db.commit()
            db.refresh(user)
        else:
            if not user.facebook_id:
                user.facebook_id = facebook_id
                db.commit()
                db.refresh(user)

        if getattr(user, "mfa_enabled", False):
            mfa_token = create_access_token({"sub": user.email, "mfa_pending": True}, expires_delta=timedelta(minutes=5))
            return {
                "status": "mfa_required",
                "mfa_token": mfa_token,
                "id": user.id,
                "email": user.email,
            }

        # Synchronise les infos utilisateur dans Firebase pour identifier le QR code
        sync_user_to_firebase(
            user_id=user.id,
            role=user.role or "user",
            qr_code=user.qr_code or "",
            full_name=user.full_name or "",
            email=user.email or "",
            score=getattr(user, 'global_score', 0) or 0,
        )
        return {"access_token": create_access_token({"sub": user.email}),
                "token_type": "bearer", "role": user.role,
                "id": user.id, "email": user.email,
                "full_name": user.full_name, "qr_code": user.qr_code,
                "avatar_url": user.avatar_url or "",
                "firebase_token": generate_custom_token(user.id)}  # pour signInWithCustomToken() Flutter
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Erreur Facebook: {str(e)}")


# ── Password reset ────────────────────────────────────────────────────────────

@router.post("/forgot-password")
async def forgot_password(data: models.ForgotPassword, db: Session = Depends(get_db)):
    user = db.query(db_models.User).filter(db_models.User.email == data.email).first()
    if not user:
        # Toujours retourner succès pour éviter l'énumération d'emails
        return {"message": "Si l'email existe, un code a été envoyé.", "success": True}

    # Code à 6 chiffres : plus facile à saisir sur mobile
    code = _generate_otp()
    user.reset_token = code
    user.token_expires = (datetime.utcnow() + timedelta(hours=1)).isoformat()
    db.commit()

    # Envoi de l'email avec le code de réinitialisation
    try:
        html = f"""<html><body style="font-family:Arial;padding:40px;">
        <div style="max-width:480px;margin:auto;background:#fff;border-radius:20px;padding:40px;box-shadow:0 4px 24px rgba(0,0,0,0.08);">
        <h1 style="color:#1E293B;text-align:center;">EcoRewind 🌿</h1>
        <p style="color:#64748B;text-align:center;">Code de réinitialisation du mot de passe :</p>
        <div style="background:linear-gradient(135deg,#00BFA6,#00E5A0);border-radius:16px;padding:24px;text-align:center;margin:24px 0;">
        <span style="font-size:40px;font-weight:900;color:white;letter-spacing:14px;font-family:monospace;">{code}</span>
        </div>
        <p style="color:#94A3B8;text-align:center;">Ce code expire dans <strong>1 heure</strong>.</p>
        <p style="color:#CBD5E1;text-align:center;font-size:12px;">Si vous n'avez pas demandé cette réinitialisation, ignorez cet email.</p>
        </div></body></html>"""
        await FastMail(_mail_conf()).send_message(
            MessageSchema(
                subject="🔐 EcoRewind - Code de réinitialisation",
                recipients=[data.email],
                body=html,
                subtype=MessageType.html,
            )
        )
        print(f"[AUTH] Code réinitialisation envoyé à {data.email}")
    except Exception as e:
        print(f"[AUTH] Erreur envoi email à {data.email}: {e}")
        if IS_DEV:
            print(f"[DEV] Code reset pour {data.email}: {code}")

    return {"message": "Code de réinitialisation envoyé par email.", "success": True}



@router.post("/verify-reset-code")
async def verify_reset_code(data: models.VerifyResetCode, db: Session = Depends(get_db)):
    """Vérifie le code sans le consommer — permet de passer à l'étape mot de passe."""
    user = db.query(db_models.User).filter(
        db_models.User.email == data.email,
        db_models.User.reset_token == data.code,
    ).first()
    if not user:
        raise HTTPException(status_code=400, detail="Code invalide ou email incorrect")
    if not user.token_expires:
        raise HTTPException(status_code=400, detail="Code invalide")
    if datetime.fromisoformat(user.token_expires) < datetime.utcnow():
        raise HTTPException(status_code=410, detail="Code expiré — demandez un nouveau code")
    return {"success": True, "message": "Code valide"}


@router.post("/reset-password")
async def reset_password(data: models.ResetPassword, db: Session = Depends(get_db)):
    user = db.query(db_models.User).filter(db_models.User.reset_token == data.token).first()
    if not user:
        raise HTTPException(status_code=400, detail="Token invalide")
    if datetime.fromisoformat(user.token_expires) < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Token expiré")
    user.hashed_password = get_password_hash(data.new_password)
    user.reset_token = None
    user.token_expires = None
    db.commit()
    return {"message": "Mot de passe mis à jour"}


@router.post("/users/me/change-password")
async def change_password(data: models.ChangePasswordRequest, db: Session = Depends(get_db),
                           current_user: db_models.User = Depends(get_current_user)):
    if not verify_password(data.old_password, current_user.hashed_password):
        raise HTTPException(status_code=400, detail="Ancien mot de passe incorrect")
    current_user.hashed_password = get_password_hash(data.new_password)
    db.commit()
    return {"message": "Mot de passe modifié"}
