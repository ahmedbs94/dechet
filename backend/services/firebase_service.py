"""
services/firebase_service.py
-----------------------------
Service Firebase Admin SDK -- Realtime Database.
Utilise pour synchroniser le score du citoyen en temps reel
lors du scan QR sur la poubelle intelligente.

Initialisation lazy : Firebase est initialise au premier appel.
Si les credentials sont absents, le service fonctionne en mode "noop"
(pas d'erreur fatale -- le reste de l'app continue).
"""
import os
import sys
import json
import traceback
from datetime import datetime, timezone
from typing import Optional

_firebase_app = None
_firebase_initialized = False
_firebase_available = False
_firebase_db_url = None


def _safe_print(msg: str):
    """Print robuste pour Windows (evite UnicodeEncodeError)."""
    try:
        print(msg)
    except UnicodeEncodeError:
        print(msg.encode('ascii', errors='replace').decode('ascii'))


def _init_firebase() -> bool:
    """Initialise Firebase Admin SDK (lazy init avec retry en cas d'echec)."""
    global _firebase_app, _firebase_initialized, _firebase_available, _firebase_db_url

    # Si deja initialise avec succes, pas besoin de retenter
    if _firebase_initialized and _firebase_available:
        return True

    creds_path = os.getenv("FIREBASE_CREDENTIALS_PATH", "firebase_credentials.json")
    db_url = os.getenv("FIREBASE_DATABASE_URL", "")

    # Resoudre le chemin relatif depuis le dossier backend
    if not os.path.isabs(creds_path):
        creds_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", creds_path)
        creds_path = os.path.normpath(creds_path)

    if not os.path.exists(creds_path):
        if not _firebase_initialized:
            _safe_print(f"[Firebase] Credentials introuvables : {creds_path}")
            _safe_print("[Firebase] Mode noop actif -- scores Firebase desactives")
        _firebase_initialized = True
        _firebase_available = False
        return False

    if not db_url:
        if not _firebase_initialized:
            _safe_print("[Firebase] FIREBASE_DATABASE_URL non defini dans .env")
        _firebase_initialized = True
        _firebase_available = False
        return False

    try:
        import firebase_admin
        from firebase_admin import credentials

        # Si l'app existe deja avec une URL differente, la supprimer et recreer
        if firebase_admin._apps:
            existing_app = firebase_admin.get_app()
            existing_url = existing_app.options.get("databaseURL", "")
            if existing_url != db_url:
                _safe_print(f"[Firebase] URL changee ({existing_url} -> {db_url}), reinitialisation...")
                firebase_admin.delete_app(existing_app)

        if not firebase_admin._apps:
            cred = credentials.Certificate(creds_path)
            _firebase_app = firebase_admin.initialize_app(cred, {"databaseURL": db_url})
        else:
            _firebase_app = firebase_admin.get_app()

        _firebase_initialized = True
        _firebase_available = True
        _firebase_db_url = db_url
        _safe_print(f"[Firebase] [OK] Connecte a : {db_url}")
        return True

    except Exception as e:
        _safe_print(f"[Firebase] [ERREUR] Initialisation : {e}")
        _firebase_initialized = True
        _firebase_available = False
        return False


def update_user_score(user_id: int, new_total: float, points_added: float,
                      bin_type: str = "general", bin_id: Optional[str] = None) -> bool:
    """
    Met a jour le score d'un citoyen dans Firebase RTDB.
    Structure : /scores/{user_id}/
      - total       : float  (score cumule)
      - last_points : float  (points du dernier scan)
      - last_scan   : str    (ISO datetime UTC)
      - last_bin_type : str  (type de dechet scanne)
      - last_bin_id : str    (identifiant de la poubelle, optionnel)
    Retourne True si l'ecriture a reussi, False sinon.
    """
    if not _init_firebase():
        return False

    try:
        from firebase_admin import db as rtdb
        ref = rtdb.reference(f"scores/{user_id}")
        ref.update({
            "total": round(new_total, 2),
            "last_points": round(points_added, 2),
            "last_scan": datetime.now(timezone.utc).isoformat(),
            "last_bin_type": bin_type,
            "last_bin_id": bin_id or "unknown",
        })
        _safe_print(f"[Firebase] [OK] Score user {user_id} mis a jour : {new_total} pts (+{points_added})")
        return True
    except Exception as e:
        _safe_print(f"[Firebase] [ERREUR] Mise a jour score user {user_id} : {e}")
        traceback.print_exc()
        return False


def get_user_score(user_id: int) -> Optional[dict]:
    """Recupere les donnees de score d'un citoyen depuis Firebase RTDB."""
    if not _init_firebase():
        return None
    try:
        from firebase_admin import db as rtdb
        ref = rtdb.reference(f"scores/{user_id}")
        return ref.get()
    except Exception as e:
        _safe_print(f"[Firebase] [ERREUR] Lecture score user {user_id} : {e}")
        return None


def generate_custom_token(user_id: int) -> Optional[str]:
    """
    Génère un Firebase Custom Token pour un utilisateur EcoRewind.

    Firebase ne connaît pas les utilisateurs JWT FastAPI. Ce token permet
    à Flutter d'appeler FirebaseAuth.signInWithCustomToken(token) et
    d'obtenir une identité Firebase reconnue par les Security Rules.

    Le uid Firebase = str(user_id) pour que la règle
        auth.uid == $user_id
    fonctionne avec les chemins /scores/{user_id}.

    Retourne None si Firebase est indisponible (mode noop).
    """
    if not _init_firebase():
        return None
    try:
        import firebase_admin.auth as fb_auth
        # uid doit être une string — on utilise l'ID PostgreSQL converti
        uid = str(user_id)
        token_bytes = fb_auth.create_custom_token(uid)
        # create_custom_token retourne des bytes sur certaines versions
        if isinstance(token_bytes, bytes):
            return token_bytes.decode("utf-8")
        return token_bytes
    except Exception as e:
        _safe_print(f"[Firebase] [ERREUR] generate_custom_token user {user_id} : {e}")
        return None


# Bareme des points par type de dechet
WASTE_POINTS: dict[str, float] = {
    "plastique": 10.0,
    "verre":     15.0,
    "papier":    8.0,
    "carton":    8.0,
    "metal":     12.0,
    "organique": 6.0,
    "electronique": 20.0,
    "textile":   10.0,
    "general":   5.0,
}


def calculate_points(waste_type: str, weight_kg: Optional[float] = None) -> float:
    """
    Calcule les points pour un scan de poubelle.
    Si weight_kg est fourni (poubelle connectee), les points sont multiplies par le poids.
    Sinon, retourne les points de base pour le type de dechet.
    """
    base = WASTE_POINTS.get(waste_type.lower().strip(), WASTE_POINTS["general"])
    if weight_kg and weight_kg > 0:
        return round(base * weight_kg, 2)
    return base
