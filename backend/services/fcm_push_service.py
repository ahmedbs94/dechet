"""
services/fcm_push_service.py
-----------------------------
Service d'envoi de Push Notifications via Firebase Cloud Messaging (FCM).

Utilise firebase-admin (déjà installé) avec FCM HTTP v1.
Firebase Admin SDK est partagé avec firebase_service.py (même app).

Fonctions exposées :
  - send_push_to_user(db, user_id, title, body, data)  → push à un utilisateur
  - send_push_to_all(db, title, body, data)             → broadcast à tous les users
  - register_fcm_token(db, user_id, token)              → enregistrer/mettre à jour le token
"""
import os
import traceback
from typing import Optional, Dict, Any
from sqlalchemy.orm import Session

# ── Init Firebase (partagé avec firebase_service.py) ─────────────────────────
_firebase_messaging = None
_fcm_initialized = False


def _safe_print(msg: str):
    """Print robuste pour Windows (évite UnicodeEncodeError)."""
    try:
        print(msg)
    except UnicodeEncodeError:
        print(msg.encode('ascii', errors='replace').decode('ascii'))


def _init_fcm() -> bool:
    """Initialise Firebase Admin SDK pour FCM (lazy init)."""
    global _firebase_messaging, _fcm_initialized

    if _fcm_initialized:
        return _firebase_messaging is not None

    try:
        import firebase_admin
        from firebase_admin import credentials, messaging

        creds_path = os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase_credentials.json")
        if not os.path.isabs(creds_path):
            creds_path = os.path.join(
                os.path.dirname(os.path.abspath(__file__)), "..", creds_path
            )
            creds_path = os.path.normpath(creds_path)

        # Réutiliser l'app Firebase existante si déjà initialisée
        try:
            app = firebase_admin.get_app()
        except ValueError:
            # Pas encore initialisée → on l'initialise
            if not os.path.exists(creds_path):
                _safe_print(f"[FCM] Credentials introuvables : {creds_path}")
                _fcm_initialized = True
                return False
            cred = credentials.Certificate(creds_path)
            db_url = os.getenv(
                "FIREBASE_DATABASE_URL",
                "https://ecorewind-6b5d6-default-rtdb.europe-west1.firebasedatabase.app"
            )
            app = firebase_admin.initialize_app(cred, {"databaseURL": db_url})

        _firebase_messaging = messaging
        _fcm_initialized = True
        _safe_print("[FCM] Firebase Cloud Messaging initialisé ✅")
        return True

    except Exception as e:
        _safe_print(f"[FCM] Erreur d'initialisation : {e}")
        _fcm_initialized = True
        return False


# ── Fonctions principales ──────────────────────────────────────────────────────

def register_fcm_token(db: Session, user_id: int, token: str) -> bool:
    """
    Enregistre ou met à jour le token FCM d'un utilisateur.
    Si le token est vide ou None, on le désenregistre pour cet utilisateur.
    Retourne True si succès.
    """
    try:
        from app.users.models import User
        user = db.query(User).filter(User.id == user_id).first()
        if not user:
            return False

        if not token:
            user.fcm_token = None
            db.commit()
            _safe_print(f"[FCM] Token désenregistré pour user {user_id}")
            return True

        # Enlever ce token de tout autre utilisateur pour éviter les conflits de session/appareil
        db.query(User).filter(User.fcm_token == token, User.id != user_id).update({"fcm_token": None})
        
        user.fcm_token = token
        db.commit()
        _safe_print(f"[FCM] Token enregistré pour user {user_id}")
        return True
    except Exception as e:
        _safe_print(f"[FCM] Erreur enregistrement token : {e}")
        return False


def send_push_to_user(
    db: Session,
    user_id: int,
    title: str,
    body: str,
    data: Optional[Dict[str, str]] = None,
    image_url: Optional[str] = None,
) -> bool:
    """
    Envoie une push notification FCM à un utilisateur spécifique.
    Retourne True si l'envoi a réussi.
    """
    if not _init_fcm():
        _safe_print("[FCM] Service non disponible, push ignoré.")
        return False

    try:
        from app.users.models import User
        user = db.query(User).filter(User.id == user_id).first()
        if not user or not user.fcm_token:
            _safe_print(f"[FCM] Pas de token FCM pour user {user_id}")
            return False

        token = user.fcm_token
        message = _firebase_messaging.Message(
            notification=_firebase_messaging.Notification(
                title=title,
                body=body,
                image=image_url,
            ),
            data={k: str(v) for k, v in (data or {}).items()},
            android=_firebase_messaging.AndroidConfig(
                priority="high",
                notification=_firebase_messaging.AndroidNotification(
                    icon="ic_stat_notify",
                    color="#2E7D32",
                    sound="default",
                    channel_id="ecorewind_notifications",
                ),
            ),
            apns=_firebase_messaging.APNSConfig(
                payload=_firebase_messaging.APNSPayload(
                    aps=_firebase_messaging.Aps(
                        sound="default",
                        badge=1,
                    )
                )
            ),
            token=token,
        )

        response = _firebase_messaging.send(message)
        _safe_print(f"[FCM] ✅ Push envoyé à user {user_id} → {response}")
        return True

    except _firebase_messaging.UnregisteredError:
        # Token expiré → on le supprime
        _safe_print(f"[FCM] Token expiré pour user {user_id}, suppression.")
        try:
            from app.users.models import User
            user = db.query(User).filter(User.id == user_id).first()
            if user:
                user.fcm_token = None
                db.commit()
        except Exception:
            pass
        return False

    except Exception as e:
        _safe_print(f"[FCM] Erreur envoi push à user {user_id} : {e}")
        traceback.print_exc()
        return False


def send_push_to_all(
    db: Session,
    title: str,
    body: str,
    data: Optional[Dict[str, str]] = None,
    image_url: Optional[str] = None,
) -> Dict[str, int]:
    """
    Envoie une push notification à TOUS les utilisateurs ayant un token FCM.
    Utilisé par l'admin pour des broadcasts globaux.
    Retourne un dict {"success": N, "failed": M}.
    """
    if not _init_fcm():
        _safe_print("[FCM] Service non disponible, broadcast ignoré.")
        return {"success": 0, "failed": 0}

    try:
        from app.users.models import User
        users_with_token = db.query(User).filter(
            User.fcm_token.isnot(None),
            User.fcm_token != "",
            User.is_active == True,
        ).all()

        if not users_with_token:
            _safe_print("[FCM] Aucun utilisateur avec token FCM.")
            return {"success": 0, "failed": 0}

        tokens = [u.fcm_token for u in users_with_token]
        _safe_print(f"[FCM] Broadcast vers {len(tokens)} utilisateurs...")

        # FCM Multicast (max 500 tokens par batch)
        success_count = 0
        failed_count = 0
        invalid_tokens = []

        BATCH_SIZE = 500
        for i in range(0, len(tokens), BATCH_SIZE):
            batch_tokens = tokens[i:i + BATCH_SIZE]
            multicast_msg = _firebase_messaging.MulticastMessage(
                notification=_firebase_messaging.Notification(
                    title=title,
                    body=body,
                    image=image_url,
                ),
                data={k: str(v) for k, v in (data or {}).items()},
                android=_firebase_messaging.AndroidConfig(
                    priority="high",
                    notification=_firebase_messaging.AndroidNotification(
                        icon="ic_stat_notify",
                        color="#2E7D32",
                        sound="default",
                        channel_id="ecorewind_notifications",
                    ),
                ),
                apns=_firebase_messaging.APNSConfig(
                    payload=_firebase_messaging.APNSPayload(
                        aps=_firebase_messaging.Aps(sound="default", badge=1)
                    )
                ),
                tokens=batch_tokens,
            )

            batch_response = _firebase_messaging.send_each_for_multicast(multicast_msg)
            success_count += batch_response.success_count
            failed_count += batch_response.failure_count

            # Collecter les tokens invalides pour nettoyage
            for idx, resp in enumerate(batch_response.responses):
                if not resp.success:
                    err = resp.exception
                    if hasattr(err, 'code') and err.code in ('registration-token-not-registered', 'invalid-registration-token'):
                        invalid_tokens.append(batch_tokens[idx])

        # Nettoyer les tokens invalides
        if invalid_tokens:
            db.query(User).filter(User.fcm_token.in_(invalid_tokens)).update(
                {"fcm_token": None}, synchronize_session=False
            )
            db.commit()
            _safe_print(f"[FCM] {len(invalid_tokens)} tokens invalides supprimés.")

        _safe_print(f"[FCM] Broadcast terminé : {success_count} succès, {failed_count} échecs.")
        return {"success": success_count, "failed": failed_count}

    except Exception as e:
        _safe_print(f"[FCM] Erreur broadcast : {e}")
        traceback.print_exc()
        return {"success": 0, "failed": -1}
