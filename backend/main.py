from dotenv import load_dotenv
load_dotenv()

import os
from fastapi import FastAPI, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm, OAuth2PasswordBearer
from fastapi.middleware.cors import CORSMiddleware
from google.oauth2 import id_token
from google.auth.transport import requests
from datetime import datetime, timedelta
import secrets
from fastapi_mail import FastMail, MessageSchema, ConnectionConfig, MessageType
from pydantic import EmailStr, BaseModel

from sqlalchemy.orm import Session, joinedload
from typing import List, Optional
import db_models as db_models
from database import engine, get_db
import models as models
from auth import verify_password, get_password_hash, create_access_token, ACCESS_TOKEN_EXPIRE_MINUTES

# Create database tables
db_models.Base.metadata.create_all(bind=engine)

app = FastAPI(title="EcoRewind API", version="1.0.0")

# CORS Configuration
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mail Configuration (Example with Gmail SMTP)
# IMPORTANT: In production, use environment variables
conf = ConnectionConfig(
    MAIL_USERNAME = os.getenv("MAIL_USERNAME"),
    MAIL_PASSWORD = os.getenv("MAIL_PASSWORD"),
    MAIL_FROM = os.getenv("MAIL_FROM"),
    MAIL_PORT = 587,
    MAIL_SERVER = "smtp.gmail.com",
    MAIL_STARTTLS = True,
    MAIL_SSL_TLS = False,
    USE_CREDENTIALS = True,
    VALIDATE_CERTS = True
)

GOOGLE_CLIENT_ID = os.getenv("GOOGLE_CLIENT_ID", "686199052163-tvieiu6db5vlstcnnsr5tp7q0eh6oi99.apps.googleusercontent.com")

oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

# Dépendance pour récupérer l'utilisateur courant depuis le token
async def get_current_user(token: str = Depends(oauth2_scheme), db: Session = Depends(get_db)):
    from jose import jwt, JWTError
    from auth import SECRET_KEY, ALGORITHM
    
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        email: str = payload.get("sub")
        if email is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
        
    user = db.query(db_models.User).filter(db_models.User.email == email).first()
    if user is None:
        raise credentials_exception
    return user

async def get_admin_user(current_user: db_models.User = Depends(get_current_user)):
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Seuls les administrateurs peuvent effectuer cette action"
        )
    return current_user

import random

@app.post("/register", response_model=models.User)
async def register(user: models.UserCreate, db: Session = Depends(get_db)):
    db_user = db.query(db_models.User).filter(db_models.User.email == user.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Email already registered")
    
    hashed_password = get_password_hash(user.password)
    new_user = db_models.User(
        email=user.email,
        full_name=user.full_name,
        hashed_password=hashed_password,
        role=user.role,
        is_verified=False
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user

# ============================================
# OTP SYSTEM
# ============================================

def generate_otp_code():
    """Generate a 6-digit OTP code"""
    return str(random.randint(100000, 999999))

@app.post("/otp/send")
async def send_otp(request: models.OTPSendRequest, db: Session = Depends(get_db)):
    """Send OTP code via email (or SMS placeholder)"""
    identifier = request.identifier.strip()
    method = request.method  # "email" or "sms"
    
    if not identifier:
        raise HTTPException(status_code=400, detail="Identifiant requis")
    
    # Invalidate previous unused codes for this identifier
    db.query(db_models.OTPCode).filter(
        db_models.OTPCode.identifier == identifier,
        db_models.OTPCode.is_used == False
    ).update({"is_used": True})
    db.commit()
    
    # Generate new code
    code = generate_otp_code()
    expires_at = datetime.utcnow() + timedelta(minutes=5)
    
    otp_entry = db_models.OTPCode(
        identifier=identifier,
        code=code,
        purpose="register",
        expires_at=expires_at,
        is_used=False
    )
    db.add(otp_entry)
    db.commit()
    
    # Send via email
    if method == "email" and "@" in identifier:
        try:
            message = MessageSchema(
                subject="🔐 TriDéchet - Code de vérification",
                recipients=[identifier],
                body=f"""
                <html>
                <body style="font-family: 'Segoe UI', Arial, sans-serif; background: #f4f7fa; padding: 40px;">
                    <div style="max-width: 480px; margin: auto; background: white; border-radius: 20px; padding: 40px; box-shadow: 0 4px 24px rgba(0,0,0,0.08);">
                        <div style="text-align: center; margin-bottom: 30px;">
                            <div style="width: 64px; height: 64px; background: linear-gradient(135deg, #00BFA6, #00E5A0); border-radius: 16px; margin: 0 auto 16px; display: flex; align-items: center; justify-content: center;">
                                <span style="font-size: 32px;">🌿</span>
                            </div>
                            <h1 style="color: #1E293B; font-size: 24px; margin: 0;">TriDéchet</h1>
                        </div>
                        <p style="color: #64748B; font-size: 15px; text-align: center;">Voici votre code de vérification :</p>
                        <div style="background: linear-gradient(135deg, #00BFA6, #00E5A0); border-radius: 16px; padding: 24px; text-align: center; margin: 24px 0;">
                            <span style="font-size: 36px; font-weight: 900; color: white; letter-spacing: 12px; font-family: monospace;">{code}</span>
                        </div>
                        <p style="color: #94A3B8; font-size: 13px; text-align: center;">Ce code expire dans <strong>5 minutes</strong>.</p>
                        <p style="color: #CBD5E1; font-size: 11px; text-align: center; margin-top: 30px;">Si vous n'avez pas demandé ce code, ignorez cet email.</p>
                    </div>
                </body>
                </html>
                """,
                subtype=MessageType.html
            )
            fm = FastMail(conf)
            await fm.send_message(message)
            return {"success": True, "message": "Code envoyé par email", "method": "email"}
        except Exception as e:
            print(f"OTP Email Error: {e}")
            # In dev mode, still return success with code visible in logs
            print(f"OTP CODE for {identifier}: {code}")
            return {"success": True, "message": "Code envoyé (mode dev)", "method": "email"}
    else:
        # SMS placeholder - in production, integrate Twilio or similar
        print(f"OTP CODE for {identifier}: {code}")
        return {"success": True, "message": "Code envoyé par SMS", "method": "sms"}

@app.post("/otp/verify")
async def verify_otp(request: models.OTPVerifyRequest, db: Session = Depends(get_db)):
    """Verify OTP code and mark user as verified"""
    identifier = request.identifier.strip()
    code = request.code.strip()
    
    if not identifier or not code:
        raise HTTPException(status_code=400, detail="Identifiant et code requis")
    
    # Find the latest unused, non-expired code for this identifier
    otp = db.query(db_models.OTPCode).filter(
        db_models.OTPCode.identifier == identifier,
        db_models.OTPCode.code == code,
        db_models.OTPCode.is_used == False,
        db_models.OTPCode.expires_at > datetime.utcnow()
    ).order_by(db_models.OTPCode.created_at.desc()).first()
    
    if not otp:
        # Check if code existed but expired
        expired = db.query(db_models.OTPCode).filter(
            db_models.OTPCode.identifier == identifier,
            db_models.OTPCode.code == code,
            db_models.OTPCode.is_used == False,
            db_models.OTPCode.expires_at <= datetime.utcnow()
        ).first()
        
        if expired:
            raise HTTPException(status_code=410, detail="Le code a expiré. Veuillez en demander un nouveau.")
        
        raise HTTPException(status_code=400, detail="Code invalide")
    
    # Mark code as used (single use)
    otp.is_used = True
    db.commit()
    
    # Mark user as verified
    user = db.query(db_models.User).filter(db_models.User.email == identifier).first()
    if user:
        user.is_verified = True
        db.commit()
        db.refresh(user)
        
        # Auto-login: generate access token
        access_token = create_access_token(data={"sub": user.email})
        return {
            "success": True,
            "message": "Compte vérifié avec succès",
            "access_token": access_token,
            "token_type": "bearer",
            "role": user.role,
            "id": user.id,
            "email": user.email,
            "full_name": user.full_name
        }
    
    return {"success": True, "message": "Code vérifié"}


@app.post("/token", response_model=models.Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(db_models.User).filter(db_models.User.email == form_data.username).first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token = create_access_token(data={"sub": user.email})
    return {
        "access_token": access_token, 
        "token_type": "bearer", 
        "role": user.role, 
        "id": user.id,
        "email": user.email,
        "full_name": user.full_name
    }

@app.post("/auth/google", response_model=models.Token)
async def google_auth(google_data: models.GoogleAuth, db: Session = Depends(get_db)):
    try:
        print(f"DEBUG BACKEND: Verification du token Google...")
        
        # Détection du type de token : un ID Token (JWT) a 3 segments séparés par des points
        is_jwt = len(google_data.token.split('.')) == 3
        
        if not is_jwt:
            print("DEBUG BACKEND: Format Access Token détecté (non JWT)")
            import requests as http_requests
            resp = http_requests.get(f"https://www.googleapis.com/oauth2/v3/userinfo?access_token={google_data.token}")
            if resp.status_code != 200:
                print(f"ERREUR GOOGLE API: {resp.text}")
                raise ValueError("Access Token Google invalide ou expiré")
            id_info = resp.json()
        else:
            print("DEBUG BACKEND: Format ID Token (JWT) détecté")
            id_info = id_token.verify_oauth2_token(
                google_data.token, 
                requests.Request(), 
                GOOGLE_CLIENT_ID
            )

        email = id_info.get("email")
        print(f"DEBUG BACKEND: Email verifié: {email}")
        full_name = id_info.get("name")
        sub = id_info.get("sub") # ID unique Google

        user = db.query(db_models.User).filter(db_models.User.email == email).first()

        if not user:
            print(f"DEBUG BACKEND: Nouvel utilisateur Google, création...")
            user = db_models.User(
                email=email,
                full_name=full_name,
                hashed_password="", 
                google_id=sub,
                is_active=True
            )
            db.add(user)
            db.commit()
            db.refresh(user)

        access_token = create_access_token(data={"sub": email})
        print(f"DEBUG BACKEND: Login Google réussi pour {email}")
        return {
            "access_token": access_token, 
            "token_type": "bearer", 
            "role": user.role, 
            "id": user.id,
            "email": user.email,
            "full_name": user.full_name
        }

    except Exception as e:
        print(f"ERREUR BACKEND GOOGLE AUTH: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Erreur d'authentification Google: {str(e)}",
        )

@app.post("/auth/facebook", response_model=models.Token)
async def facebook_auth(fb_data: models.FacebookAuth, db: Session = Depends(get_db)):
    try:
        print(f"DEBUG BACKEND: Vérification du token Facebook...")
        import requests as http_requests
        
        # Validation du token via l'API Graph Facebook
        resp = http_requests.get(
            "https://graph.facebook.com/me",
            params={
                "access_token": fb_data.access_token,
                "fields": "id,name,email,picture"
            },
            timeout=10
        )
        
        # Si Facebook renvoie une erreur HTTP
        if resp.status_code != 200:
            print(f"ERREUR FACEBOOK API (HTTP {resp.status_code}): {resp.text}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token Facebook invalide ou expiré. Veuillez réessayer."
            )
        
        fb_info = resp.json()
        
        # Si la réponse contient une erreur applicative Facebook
        if "error" in fb_info:
            fb_error = fb_info["error"]
            error_msg = fb_error.get("message", "Erreur Facebook inconnue")
            error_code = fb_error.get("code", 0)
            print(f"ERREUR FACEBOOK GRAPH: [{error_code}] {error_msg}")
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail=f"Erreur Facebook ({error_code}): {error_msg}"
            )
        
        facebook_id = fb_info.get("id")
        full_name = fb_info.get("name", "Utilisateur Facebook")
        email = fb_info.get("email")  # Peut être None si l'utilisateur ne partage pas son email
        
        if not facebook_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Impossible de récupérer l'identifiant Facebook. Vérifiez les permissions."
            )
        
        print(f"DEBUG BACKEND: Utilisateur Facebook: {full_name} (ID: {facebook_id}, Email: {email or 'non partagé'})")
        
        # Recherche de l'utilisateur existant : d'abord par facebook_id, puis par email
        user = db.query(db_models.User).filter(db_models.User.facebook_id == facebook_id).first()
        
        if not user and email:
            # Vérifier si un compte existe avec cet email (connexion Google ou email/pass)
            user = db.query(db_models.User).filter(db_models.User.email == email).first()
        
        if not user:
            # Créer un nouveau compte
            print(f"DEBUG BACKEND: Nouvel utilisateur Facebook, création du compte...")
            # Si pas d'email fourni, on génère un email interne unique
            fallback_email = email or f"fb_{facebook_id}@noemail.tridechet.local"
            user = db_models.User(
                email=fallback_email,
                full_name=full_name,
                hashed_password="",
                facebook_id=facebook_id,
                is_active=True,
                role="user"
            )
            db.add(user)
            db.commit()
            db.refresh(user)
        else:
            # Mettre à jour le facebook_id et le nom si nécessaire
            changed = False
            if not user.facebook_id:
                user.facebook_id = facebook_id
                changed = True
            if full_name and user.full_name != full_name and not user.full_name:
                user.full_name = full_name
                changed = True
            if changed:
                db.commit()
                db.refresh(user)
        
        access_token = create_access_token(data={"sub": user.email})
        print(f"DEBUG BACKEND: ✅ Login Facebook réussi pour {user.email}")
        return {
            "access_token": access_token,
            "token_type": "bearer",
            "role": user.role,
            "id": user.id,
            "email": user.email,
            "full_name": user.full_name
        }
    
    except HTTPException:
        raise  # Re-propager les HTTPException déjà formatées
    except Exception as e:
        print(f"ERREUR BACKEND FACEBOOK AUTH: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Erreur interne lors de l'authentification Facebook: {str(e)}",
        )


@app.post("/forgot-password")
async def forgot_password(data: models.ForgotPassword, db: Session = Depends(get_db)):
    user = db.query(db_models.User).filter(db_models.User.email == data.email).first()
    if not user:
        # We return 200 even if user doesn't exist for security (avoid email enumeration)
        return {"message": "Si l'email existe, un lien de réinitialisation sera envoyé"}
    
    # Generate reset token
    token = secrets.token_urlsafe(32)
    user.reset_token = token
    user.token_expires = (datetime.utcnow() + timedelta(hours=1)).isoformat()
    db.commit()

    # ALWAYS print to terminal for easy testing
    print(f"\n{'='*50}")
    print(f"DEBUG: Reset token for {data.email} is : {token}")
    print(f"{'='*50}\n")

    # Send Email
    if os.getenv("MAIL_PASSWORD") and os.getenv("MAIL_PASSWORD") != "votre-mot-de-passe-app":
        try:
            html_content = f"""
            <div style="font-family: Arial, sans-serif; padding: 20px; color: #333;">
                <h2 style="color: #10B981;">Réinitialisation de mot de passe - EcoRewind</h2>
                <p>Bonjour,</p>
                <p>Vous avez demandé la réinitialisation de votre mot de passe sur l'application <strong>EcoRewind</strong>.</p>
                <div style="background-color: #f3f4f6; padding: 15px; border-radius: 8px; text-align: center; margin: 20px 0;">
                    <span style="font-size: 24px; font-weight: bold; letter-spacing: 5px; color: #064E3B;">{token}</span>
                </div>
                <p>Ce code est valable pendant 1 heure.</p>
                <p>Si vous n'êtes pas à l'origine de cette demande, vous pouvez ignorer cet email.</p>
                <br>
                <p>L'équipe EcoRewind</p>
            </div>
            """
            message = MessageSchema(
                subject="Réinitialisation de votre mot de passe - EcoRewind",
                recipients=[data.email],
                body=html_content,
                subtype=MessageType.html
            )
            fm = FastMail(conf)
            await fm.send_message(message)
            print(f"📧 EMAIL: Envoyé avec succès à {data.email}")
        except Exception as e:
            print(f"❌ ERREUR ENVOI EMAIL à {data.email}: {e}")

    return {"message": "Si l'email existe, un code de réinitialisation a été envoyé."}

@app.post("/reset-password")
async def reset_password(data: models.ResetPassword, db: Session = Depends(get_db)):
    user = db.query(db_models.User).filter(db_models.User.reset_token == data.token).first()
    
    if not user:
        raise HTTPException(status_code=400, detail="Token invalide")
    
    # Check expiry
    if datetime.fromisoformat(user.token_expires) < datetime.utcnow():
        raise HTTPException(status_code=400, detail="Token expiré")
    
    # Update password
    user.hashed_password = get_password_hash(data.new_password)
    user.reset_token = None # Clear token
    user.token_expires = None
    db.commit()
    
    return {"message": "Mot de passe mis à jour avec succès"}


@app.post("/users/me/change-password")
async def change_password(data: models.ChangePasswordRequest, db: Session = Depends(get_db), current_user: db_models.User = Depends(get_current_user)):
    if not verify_password(data.old_password, current_user.hashed_password):
        raise HTTPException(status_code=400, detail="Ancien mot de passe incorrect")
    
    current_user.hashed_password = get_password_hash(data.new_password)
    db.commit()
    return {"message": "Mot de passe modifié avec succès"}

@app.get("/users/me", response_model=models.User)
async def get_me(current_user: db_models.User = Depends(get_current_user)):
    return current_user

@app.get("/")
async def root():
    return {"message": "Welcome to EcoRewind Backend API with SQLite"}

# --- GESTION DES UTILISATEURS (ADMIN) ---

@app.get("/users", response_model=List[models.User])
async def read_users(skip: int = 0, limit: int = 100, db: Session = Depends(get_db), admin: db_models.User = Depends(get_admin_user)):
    users = db.query(db_models.User).offset(skip).limit(limit).all()
    return users

@app.post("/admin/users", response_model=models.User)
async def create_user_admin(user: models.UserCreate, db: Session = Depends(get_db), admin: db_models.User = Depends(get_admin_user)):
    db_user = db.query(db_models.User).filter(db_models.User.email == user.email).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Cet email est déjà utilisé")
    
    hashed_password = get_password_hash(user.password)
    new_user = db_models.User(
        email=user.email,
        full_name=user.full_name,
        hashed_password=hashed_password,
        role=user.role,
        is_active=True
    )
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return new_user


@app.put("/admin/users/{user_id}", response_model=models.User)
async def update_user_admin(user_id: int, user_update: models.UserUpdate, db: Session = Depends(get_db), admin: db_models.User = Depends(get_admin_user)):
    db_user = db.query(db_models.User).filter(db_models.User.id == user_id).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="Utilisateur non trouvé")
    
    if user_update.full_name:
        db_user.full_name = user_update.full_name
    if user_update.role:
        db_user.role = user_update.role
    if user_update.password:
        db_user.hashed_password = get_password_hash(user_update.password)
        
    db.commit()
    db.refresh(db_user)
    return db_user

@app.delete("/admin/users/{user_id}")
async def delete_user_admin(user_id: int, db: Session = Depends(get_db), admin: db_models.User = Depends(get_admin_user)):
    db_user = db.query(db_models.User).filter(db_models.User.id == user_id).first()
    if not db_user:
        raise HTTPException(status_code=404, detail="Utilisateur non trouvé")
    
    db.delete(db_user)
    db.commit()
    return {"message": "Utilisateur supprimé avec succès"}

# --- FEED / PUBLICATIONS ---

@app.post("/posts", response_model=models.Post)
async def create_post(post: models.PostCreate, db: Session = Depends(get_db), current_user: db_models.User = Depends(get_current_user)):
    new_post = db_models.Post(
        user_id=current_user.id,
        user_name=post.user_name,
        user_avatar_url=post.user_avatar_url,
        image_url=post.image_url,
        description=post.description
    )
    db.add(new_post)
    db.commit()
    db.refresh(new_post)
    return new_post

@app.get("/posts")
async def get_posts(skip: int = 0, limit: int = 50, db: Session = Depends(get_db), authorization: Optional[str] = None):
    from fastapi import Header
    posts = db.query(db_models.Post).options(joinedload(db_models.Post.comments)).order_by(db_models.Post.created_at.desc()).offset(skip).limit(limit).all()
    
    # Try to get current user from token for is_liked/is_saved
    current_user_id = None
    # Read token from query or we'll use a different approach
    
    result = []
    for post in posts:
        post_dict = {
            "id": post.id,
            "user_id": post.user_id,
            "user_name": post.user_name,
            "user_avatar_url": post.user_avatar_url or "",
            "image_url": post.image_url or "",
            "description": post.description or "",
            "created_at": post.created_at.isoformat() if post.created_at else None,
            "likes_count": post.likes_count or 0,
            "comments": [
                {
                    "id": c.id,
                    "post_id": c.post_id,
                    "user_id": c.user_id,
                    "user_name": c.user_name,
                    "user_avatar_url": c.user_avatar_url,
                    "content": c.content,
                    "created_at": c.created_at.isoformat() if c.created_at else None,
                }
                for c in (post.comments or [])
            ],
            "is_liked": False,
            "is_saved": False,
        }
        result.append(post_dict)
    
    return result

# New endpoint: get posts with user-specific states
@app.get("/posts/feed")
async def get_feed(skip: int = 0, limit: int = 50, db: Session = Depends(get_db), current_user: db_models.User = Depends(get_current_user)):
    posts = db.query(db_models.Post).options(joinedload(db_models.Post.comments)).order_by(db_models.Post.created_at.desc()).offset(skip).limit(limit).all()
    
    user_id = current_user.id
    
    # Get all liked and saved post IDs for this user in bulk
    liked_ids = set(
        r[0] for r in db.query(db_models.Like.post_id).filter(db_models.Like.user_id == user_id).all()
    )
    saved_ids = set(
        r[0] for r in db.query(db_models.SavedPost.post_id).filter(db_models.SavedPost.user_id == user_id).all()
    )
    
    result = []
    for post in posts:
        post_dict = {
            "id": post.id,
            "user_id": post.user_id,
            "user_name": post.user_name,
            "user_avatar_url": post.user_avatar_url or "",
            "image_url": post.image_url or "",
            "description": post.description or "",
            "created_at": post.created_at.isoformat() if post.created_at else None,
            "likes_count": post.likes_count or 0,
            "comments": [
                {
                    "id": c.id,
                    "post_id": c.post_id,
                    "user_id": c.user_id,
                    "user_name": c.user_name,
                    "user_avatar_url": c.user_avatar_url,
                    "content": c.content,
                    "created_at": c.created_at.isoformat() if c.created_at else None,
                }
                for c in (post.comments or [])
            ],
            "is_liked": post.id in liked_ids,
            "is_saved": post.id in saved_ids,
        }
        result.append(post_dict)
    
    return result

@app.put("/posts/{post_id}", response_model=models.Post)
async def update_post(post_id: int, post_update: models.PostUpdate, db: Session = Depends(get_db)):
    db_post = db.query(db_models.Post).filter(db_models.Post.id == post_id).first()
    if not db_post:
        raise HTTPException(status_code=404, detail="Publication non trouvée")
    
    if post_update.description:
        db_post.description = post_update.description
    if post_update.image_url:
        db_post.image_url = post_update.image_url
        
    db.commit()
    db.refresh(db_post)
    return db_post

@app.delete("/posts/{post_id}")
async def delete_post(post_id: int, db: Session = Depends(get_db)):
    db_post = db.query(db_models.Post).filter(db_models.Post.id == post_id).first()
    if not db_post:
        raise HTTPException(status_code=404, detail="Publication non trouvée")
    
    db.delete(db_post)
    db.commit()
    return {"message": "Publication supprimée"}

# --- LIKES / MENTIONS J'AIME ---

@app.post("/posts/{post_id}/like")
async def toggle_like(post_id: int, db: Session = Depends(get_db), current_user: db_models.User = Depends(get_current_user)):
    user_id = current_user.id
    
    # Vérifier si déjà liké
    existing_like = db.query(db_models.Like).filter(
        db_models.Like.user_id == user_id,
        db_models.Like.post_id == post_id
    ).first()
    
    db_post = db.query(db_models.Post).filter(db_models.Post.id == post_id).first()
    if not db_post:
        raise HTTPException(status_code=404, detail="Post non trouvé")

    if existing_like:
        db.delete(existing_like)
        db_post.likes_count -= 1
        db.commit()
        return {"liked": False, "count": db_post.likes_count}
    
    new_like = db_models.Like(user_id=user_id, post_id=post_id)
    db.add(new_like)
    db_post.likes_count += 1
    db.commit()
    return {"liked": True, "count": db_post.likes_count}

@app.get("/posts/{post_id}/likers", response_model=List[models.UserSmall])
async def get_post_likers(post_id: int, db: Session = Depends(get_db)):
    likes = db.query(db_models.Like).filter(db_models.Like.post_id == post_id).all()
    user_ids = [like.user_id for like in likes]
    return db.query(db_models.User).filter(db_models.User.id.in_(user_ids)).all()

# --- ENREGISTREMENTS ---

@app.post("/posts/{post_id}/save")
async def save_post(post_id: int, db: Session = Depends(get_db), current_user: db_models.User = Depends(get_current_user)):
    user_id = current_user.id
    
    # Vérifier si déjà enregistré
    existing = db.query(db_models.SavedPost).filter(
        db_models.SavedPost.user_id == user_id,
        db_models.SavedPost.post_id == post_id
    ).first()
    
    if existing:
        db.delete(existing)
        db.commit()
        return {"message": "Publication retirée des favoris", "saved": False}
    
    new_save = db_models.SavedPost(user_id=user_id, post_id=post_id)
    db.add(new_save)
    db.commit()
    return {"message": "Publication enregistrée", "saved": True}

@app.post("/posts/{post_id}/comments", response_model=models.Comment)
async def create_comment(post_id: int, comment: models.CommentCreate, db: Session = Depends(get_db), current_user: db_models.User = Depends(get_current_user)):
    db_post = db.query(db_models.Post).filter(db_models.Post.id == post_id).first()
    if not db_post:
        raise HTTPException(status_code=404, detail="Publication non trouvée")
    
    new_comment = db_models.Comment(
        post_id=post_id,
        user_id=current_user.id,
        user_name=comment.user_name,
        user_avatar_url=comment.user_avatar_url,
        content=comment.content
    )
    db.add(new_comment)
    db.commit()
    db.refresh(new_comment)
    return new_comment

@app.put("/comments/{comment_id}", response_model=models.Comment)
async def update_comment(comment_id: int, comment_update: models.CommentUpdate, db: Session = Depends(get_db), current_user: db_models.User = Depends(get_current_user)):
    db_comment = db.query(db_models.Comment).filter(db_models.Comment.id == comment_id).first()
    if not db_comment:
        raise HTTPException(status_code=404, detail="Commentaire non trouvé")
    
    if db_comment.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Vous ne pouvez modifier que vos propres commentaires")
    
    db_comment.content = comment_update.content
    db.commit()
    db.refresh(db_comment)
    return db_comment

@app.delete("/comments/{comment_id}")
async def delete_comment(comment_id: int, db: Session = Depends(get_db), current_user: db_models.User = Depends(get_current_user)):
    db_comment = db.query(db_models.Comment).filter(db_models.Comment.id == comment_id).first()
    if not db_comment:
        raise HTTPException(status_code=404, detail="Commentaire non trouvé")
    
    if db_comment.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Vous ne pouvez supprimer que vos propres commentaires")
    
    db.delete(db_comment)
    db.commit()
    return {"message": "Commentaire supprimé"}

@app.get("/users/me/saved-posts", response_model=List[models.Post])
async def get_saved_posts(db: Session = Depends(get_db), current_user: db_models.User = Depends(get_current_user)):
    user_id = current_user.id
    saved_refs = db.query(db_models.SavedPost).filter(db_models.SavedPost.user_id == user_id).all()
    post_ids = [ref.post_id for ref in saved_refs]
    return db.query(db_models.Post).options(joinedload(db_models.Post.comments)).filter(db_models.Post.id.in_(post_ids)).all()
