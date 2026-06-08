"""
ai_worker/worker.py — Worker IA autonome pour la modération des posts
======================================================================
Ce worker tourne dans un PROCESSUS SÉPARÉ de FastAPI.

Avantages vs thread daemon dans FastAPI :
  - Les modèles IA sont chargés UNE SEULE FOIS, peu importe le nombre
    de workers uvicorn (--workers 4 ne multiplie plus la RAM par 4)
  - FastAPI reste léger et réactif
  - Le worker peut être redémarré indépendamment

Architecture :
  FastAPI → INSERT posts (status='pending_ai')
  ↓
  AI Worker → polling DB toutes les POLL_INTERVAL secondes
  ↓
  UPDATE posts SET status='published'|'pending_review'|'rejected',
                   moderation_score=..., moderation_reason=...,
                   moderated_at=NOW(), moderation_model_version=...

Lancement :
  # Depuis backend/
  python -m ai_worker.worker

  # Ou directement :
  python ai_worker/worker.py
"""

import os
import sys
import time
import logging
from datetime import datetime, timezone

# ── Ajouter backend/ au PYTHONPATH ───────────────────────────────────────────
_backend_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
if _backend_dir not in sys.path:
    sys.path.insert(0, _backend_dir)

from dotenv import load_dotenv
load_dotenv(os.path.join(_backend_dir, ".env"))

from sqlalchemy.orm import Session
from database import SessionLocal
from app.posts.models import Post

# ── Configuration ─────────────────────────────────────────────────────────────
POLL_INTERVAL = int(os.getenv("AI_WORKER_POLL_INTERVAL", "5"))   # secondes entre chaque poll
BATCH_SIZE    = int(os.getenv("AI_WORKER_BATCH_SIZE",    "10"))  # posts traités par cycle
LOG_LEVEL     = os.getenv("AI_WORKER_LOG_LEVEL", "INFO").upper()

logging.basicConfig(
    level=getattr(logging, LOG_LEVEL, logging.INFO),
    format="%(asctime)s [AI-WORKER] %(levelname)s — %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("ai_worker")


# ── Chargement des modèles IA (une seule fois au démarrage du worker) ──────────
def _load_moderator():
    """Charge le modérateur IA. Retourne None si les modèles ne sont pas dispo."""
    try:
        from moderation_ai.eco_moderator import get_cnn_moderator
        moderator = get_cnn_moderator()
        logger.info("✅ Modèles IA chargés avec succès (modération CNN+ResNet+Detoxify)")
        return moderator
    except Exception as e:
        logger.warning(f"⚠️  Modèles IA non disponibles — mode règles basiques actif : {e}")
        return None


# ── Modération basique (fallback sans IA) ─────────────────────────────────────
_FORBIDDEN_KEYWORDS = [
    "spam", "pub", "promo", "vente", "achat", "soldes",
    "insulte", "haine", "violence",
]

def _basic_moderation(post: Post) -> dict:
    """
    Modération par règles simples, sans modèles IA.
    Utilisé si les modèles ne sont pas installés (ex: dev léger).
    """
    text = (post.description or "").lower()
    for kw in _FORBIDDEN_KEYWORDS:
        if kw in text:
            return {
                "status": "rejected",
                "score": 0.95,
                "reason": f"Mot-clé interdit détecté : '{kw}'",
                "model_version": "rules_v1.0",
            }
    return {
        "status": "published",
        "score": 0.05,
        "reason": "Contenu validé par règles basiques",
        "model_version": "rules_v1.0",
    }


# ── Traitement d'un post ───────────────────────────────────────────────────────
def _moderate_post(post: Post, moderator) -> dict:
    """
    Applique la modération IA (ou les règles basiques si moderator=None).
    Retourne un dict avec les champs à mettre à jour.
    """
    if moderator is None:
        return _basic_moderation(post)

    try:
        result = moderator.moderate(
            text=post.description or "",
            image_path=post.image_url or None,  # chemin local ou None
        )
        # Normalisation du résultat selon l'interface eco_moderator
        status = result.get("status", "published")
        score  = float(result.get("score", 0.0))
        reason = result.get("reason", "")
        version = result.get("model_version", "cnn_v1.0")

        return {
            "status": status,
            "score": score,
            "reason": reason,
            "model_version": version,
        }
    except Exception as e:
        logger.error(f"Erreur modération post #{post.id}: {e}")
        # En cas d'erreur IA → envoi en revue manuelle
        return {
            "status": "pending_review",
            "score": 0.5,
            "reason": f"Erreur IA — revue manuelle requise : {str(e)[:200]}",
            "model_version": "error_fallback",
        }


# ── Boucle principale ─────────────────────────────────────────────────────────
def run_worker(moderator) -> None:
    """
    Boucle de polling infinie.
    Récupère les posts en attente, les modère, met à jour la DB.
    """
    logger.info(f"🚀 AI Worker démarré — poll toutes les {POLL_INTERVAL}s, batch={BATCH_SIZE}")

    while True:
        db: Session = SessionLocal()
        try:
            # Récupère les posts en attente de modération
            pending_posts = (
                db.query(Post)
                .filter(Post.status == "pending_ai")
                .order_by(Post.created_at.asc())
                .limit(BATCH_SIZE)
                .all()
            )

            if pending_posts:
                logger.info(f"📋 {len(pending_posts)} post(s) à modérer")

            for post in pending_posts:
                logger.info(f"  → Modération post #{post.id} (user={post.user_id})")
                decision = _moderate_post(post, moderator)

                # Mise à jour du post dans la DB
                post.status                  = decision["status"]
                post.moderation_score        = decision["score"]
                post.moderation_reason       = decision["reason"]
                post.moderation_model_version = decision["model_version"]
                post.moderated_at            = datetime.now(timezone.utc)

                db.add(post)
                logger.info(
                    f"  ✅ Post #{post.id} → {decision['status']} "
                    f"(score={decision['score']:.3f}, model={decision['model_version']})"
                )

            if pending_posts:
                db.commit()
                logger.info(f"💾 {len(pending_posts)} décision(s) sauvegardée(s)")

        except Exception as e:
            logger.error(f"❌ Erreur cycle worker : {e}")
            db.rollback()
        finally:
            db.close()

        time.sleep(POLL_INTERVAL)


# ── Point d'entrée ────────────────────────────────────────────────────────────
if __name__ == "__main__":
    logger.info("=" * 60)
    logger.info("  EcoRewind — AI Moderation Worker")
    logger.info("=" * 60)
    logger.info("Chargement des modèles IA...")
    moderator = _load_moderator()
    run_worker(moderator)
