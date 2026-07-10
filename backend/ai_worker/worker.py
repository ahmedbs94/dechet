"""
ai_worker/worker.py — Worker de RATTRAPAGE IA (complément optionnel)
=====================================================================

RÔLE DE CE WORKER
-----------------
Ce worker est un OUTIL DE SECOURS. Il n'est PAS le pipeline principal
de modération. Le pipeline principal est géré directement par FastAPI
via BackgroundTasks dans routers/posts.py.

PIPELINE PRINCIPAL (toujours actif, sans ce worker) :
  POST /posts
    → post créé en DB avec status='pending_review'
    → BackgroundTask lance _run_ai_moderation()
    → status mis à jour : 'published' | 'pending_review'

RÔLE DU WORKER (optionnel) :
  Traiter les posts restés bloqués en 'pending_review' depuis trop longtemps.
  Cela peut arriver si :
    - La BackgroundTask a échoué silencieusement (erreur IA non capturée)
    - L'API a été redémarrée pendant le traitement d'un post
    - Un post a été créé manuellement en DB sans passer par l'API

Ce worker ne modifie PAS le pipeline normal. Il est complémentaire.

STATUTS UTILISÉS DANS CE PROJET
--------------------------------
  pending_review  → Post créé, en attente de modération IA (statut initial)
  published       → Post approuvé par l'IA (visible dans le fil)
  pending_review  → Post signalé par l'IA, en attente de décision admin
  rejected        → Jamais utilisé automatiquement (l'admin décide)

Note : le statut 'pending_ai' n'est PAS utilisé dans ce projet.

LANCEMENT
---------
  # Depuis backend/ (rattrapage des posts bloqués depuis > 10 min)
  python -m ai_worker.worker

  # Mode continu (polling toutes les 5 secondes)
  AI_WORKER_POLL_INTERVAL=5 python -m ai_worker.worker

  # Via Docker (voir docker-compose.yml, profil 'ai')
  docker compose --profile ai up -d
"""

import os
import sys
import time
import logging
from datetime import datetime, timezone, timedelta

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
POLL_INTERVAL = int(os.getenv("AI_WORKER_POLL_INTERVAL", "5"))   # secondes entre polls
BATCH_SIZE    = int(os.getenv("AI_WORKER_BATCH_SIZE",    "10"))  # posts par cycle
LOG_LEVEL     = os.getenv("AI_WORKER_LOG_LEVEL", "INFO").upper()

# Durée minimale pendant laquelle un post doit être bloqué avant rattrapage.
# Évite de concurrencer les BackgroundTasks encore en cours.
STALE_AFTER_MINUTES = int(os.getenv("AI_WORKER_STALE_MINUTES", "10"))

logging.basicConfig(
    level=getattr(logging, LOG_LEVEL, logging.INFO),
    format="%(asctime)s [AI-WORKER] %(levelname)s — %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
)
logger = logging.getLogger("ai_worker")


# ── Chargement des modèles IA (une seule fois au démarrage) ───────────────────
def _load_moderator():
    """Charge le modérateur IA. Retourne None si les modèles ne sont pas dispo."""
    try:
        from moderation_ai.eco_moderator import get_cnn_moderator
        moderator = get_cnn_moderator()
        logger.info("✅ Modèles IA chargés avec succès")
        return moderator
    except Exception as e:
        logger.warning(f"⚠️  Modèles IA non disponibles — mode règles basiques actif : {e}")
        return None


# ── Modération basique (fallback sans modèles IA) ─────────────────────────────
_FORBIDDEN_KEYWORDS = [
    "spam", "pub", "promo", "vente", "achat", "soldes",
    "insulte", "haine", "violence",
]

def _basic_moderation(post: Post) -> dict:
    """
    Modération par règles simples, sans modèles IA.
    Utilisé si les modèles ne sont pas installés (ex: démo légère).
    """
    text = (post.description or "").lower()
    for kw in _FORBIDDEN_KEYWORDS:
        if kw in text:
            return {
                "status": "pending_review",  # jamais rejeté automatiquement
                "score": 0.90,
                "reason": f"Mot-clé signalé : '{kw}' — vérification admin requise",
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
    Retourne un dict avec les champs à mettre à jour sur le post.
    """
    if moderator is None:
        return _basic_moderation(post)

    try:
        result = moderator.moderate(
            text=post.description or "",
            image_path=post.image_url or None,
        )
        status = result.get("status", "published")
        score  = float(result.get("score", 0.0))
        reason = result.get("reason", "")
        version = result.get("model_version", "cnn_v1.0")

        # Ce worker n'auto-rejette jamais : le rejet reste une décision admin
        if status == "rejected":
            status = "pending_review"
            reason = f"AI_FLAGGED (worker rattrapage) : {reason}"

        return {
            "status": status,
            "score": score,
            "reason": reason,
            "model_version": version,
        }
    except Exception as e:
        logger.error(f"Erreur modération post #{post.id}: {e}")
        return {
            "status": "pending_review",
            "score": 0.5,
            "reason": f"Erreur IA (worker) — revue manuelle requise : {str(e)[:200]}",
            "model_version": "error_fallback",
        }


# ── Boucle principale ─────────────────────────────────────────────────────────
def run_worker(moderator) -> None:
    """
    Boucle de rattrapage : traite les posts restés bloqués en 'pending_review'
    depuis plus de STALE_AFTER_MINUTES minutes.

    Ne touche pas aux posts fraîchement créés (BackgroundTasks encore actives).
    """
    logger.info(f"🔄 AI Worker démarré en mode RATTRAPAGE")
    logger.info(f"   → Poll toutes les {POLL_INTERVAL}s, batch={BATCH_SIZE}")
    logger.info(f"   → Traite les posts bloqués depuis > {STALE_AFTER_MINUTES} min")
    logger.info(f"   → Pipeline principal : BackgroundTasks dans routers/posts.py")

    while True:
        db: Session = SessionLocal()
        try:
            # Seuil temporel : seuls les posts assez anciens sont rattrapés
            stale_threshold = datetime.now(timezone.utc) - timedelta(minutes=STALE_AFTER_MINUTES)

            # Récupère les posts bloqués sans modération (moderated_at=None)
            # ET créés avant le seuil (pour ne pas concurrencer les BG tasks)
            stale_posts = (
                db.query(Post)
                .filter(
                    Post.status == "pending_review",
                    Post.moderated_at.is_(None),         # jamais modéré
                    Post.created_at <= stale_threshold,  # assez ancien
                )
                .order_by(Post.created_at.asc())
                .limit(BATCH_SIZE)
                .all()
            )

            if stale_posts:
                logger.info(f"🛠  {len(stale_posts)} post(s) bloqué(s) à rattraper")

            for post in stale_posts:
                logger.info(f"  → Rattrapage post #{post.id} (créé le {post.created_at})")
                decision = _moderate_post(post, moderator)

                post.status                   = decision["status"]
                post.moderation_score         = decision["score"]
                post.moderation_reason        = decision["reason"]
                post.moderation_model_version = decision["model_version"]
                post.moderated_at             = datetime.now(timezone.utc)

                db.add(post)
                logger.info(
                    f"  ✅ Post #{post.id} → {decision['status']} "
                    f"(score={decision['score']:.3f}, model={decision['model_version']})"
                )

            if stale_posts:
                db.commit()
                logger.info(f"💾 {len(stale_posts)} rattrapage(s) sauvegardé(s)")

        except Exception as e:
            logger.error(f"❌ Erreur cycle worker : {e}")
            db.rollback()
        finally:
            db.close()

        time.sleep(POLL_INTERVAL)


# ── Point d'entrée ────────────────────────────────────────────────────────────
if __name__ == "__main__":
    logger.info("=" * 60)
    logger.info("  EcoRewind — AI Moderation Worker (mode rattrapage)")
    logger.info("=" * 60)
    logger.info("Chargement des modèles IA...")
    moderator = _load_moderator()
    run_worker(moderator)
