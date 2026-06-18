# routers/posts.py — Publications, likes, saves, comments, upload
# FCM Push Notifications intégrées
import os
import uuid
import hashlib
import json as _json
from datetime import datetime
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Header
from fastapi.responses import JSONResponse
from sqlalchemy.orm import Session, joinedload

import db_models as db_models
import models as models
from database import get_db
from core.deps import get_current_user, _utc_iso

router = APIRouter(tags=["posts"])

IS_DEV = os.getenv("APP_ENV", "development").lower() != "production"
UPLOADS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "uploads")
os.makedirs(UPLOADS_DIR, exist_ok=True)


def _rejection_details(reasons: list, score: float) -> dict:
    text = " | ".join(reasons).lower()

    if any(k in text for k in ["adulte", "inappropri", "nsfw", "nudite", "sensible"]):
        return {
            "category": "nsfw", "icon": "block",
            "title": "Image inappropriee detectee",
            "body": ("Votre image contient du contenu sensible non autorise sur EcoRewind. "
                     "Seules les photos liees a l'ecologie sont acceptees."),
            "tip": "Remplacez par une photo d'un geste eco : nettoyage, recyclage, nature.",
        }

    if any(k in text for k in ["toxique", "insult", "vulgaire", "haineux", "lang"]):
        return {
            "category": "toxic", "icon": "sentiment_very_dissatisfied",
            "title": "Langage irrespectueux detecte",
            "body": ("Votre publication contient des termes offensants. "
                     "EcoRewind est une communaute bienveillante dediee a l'ecologie."),
            "tip": "Reformulez de maniere positive et respectueuse.",
        }

    if any(k in text for k in ["anti-env", "anti-ecologie"]):
        return {
            "category": "anti_eco", "icon": "eco",
            "title": "Contenu contraire aux valeurs",
            "body": ("Votre publication va a l'encontre des valeurs d'EcoRewind, "
                     "dediee aux gestes positifs pour la nature."),
            "tip": "Partagez une action eco-responsable que vous avez realisee.",
        }

    if any(k in text for k in ["mode", "vetement", "maquillage", "cosmetique", "parfum",
                                "bijoux", "beaute", "fashion", "shopping", "mascara",
                                "lipstick", "makeup", "brush", "eyeliner"]):
        return {
            "category": "fashion", "icon": "checkroom",
            "title": "Hors sujet - Mode et Beaute",
            "body": ("Votre publication semble liee a la mode, au maquillage ou aux cosmetiques. "
                     "EcoRewind est exclusivement dedie a l'ecologie et aux gestes citoyens."),
            "tip": "Publiez une photo de votre geste eco : nettoyage, recyclage, jardinage.",
        }

    if any(k in text for k in ["sport", "match", "football", "equipe", "joueur",
                                "championnat", "fitness", "musculation", "marathon",
                                "tennis", "basket", "rugby"]):
        return {
            "category": "sport", "icon": "sports_soccer",
            "title": "Hors sujet - Sport",
            "body": ("Ce contenu semble lie au sport ou au fitness. "
                     "EcoRewind est dedie a l'ecologie citoyenne et aux gestes pour la nature."),
            "tip": "Partagez un geste eco : nettoyage, compostage, velo comme transport vert.",
        }

    if any(k in text for k in ["politique", "election", "gouvernement", "ministre",
                                "parlement", "vote", "parti", "diplomatique"]):
        return {
            "category": "politics", "icon": "how_to_vote",
            "title": "Hors sujet - Politique",
            "body": ("Ce contenu est lie a la politique ou aux elections. "
                     "EcoRewind est apolitique et dedie uniquement aux actions pour l'environnement."),
            "tip": "Partagez plutot une action citoyenne pour la nature.",
        }

    if any(k in text for k in ["economie", "finance", "bourse", "inflation",
                                "crypto", "bitcoin", "investissement", "banque"]):
        return {
            "category": "economy", "icon": "trending_up",
            "title": "Hors sujet - Finance et Economie",
            "body": ("Ce contenu est lie a la finance ou l'economie. "
                     "EcoRewind est dedie au recyclage et a la protection de la nature."),
            "tip": "Partagez un geste eco : reduction de dechets, energie renouvelable.",
        }

    if any(k in text for k in ["sante", "medecin", "vaccin", "maladie",
                                "traitement", "hopital", "nutrition"]):
        return {
            "category": "health", "icon": "local_hospital",
            "title": "Hors sujet - Sante et Medecine",
            "body": ("Ce contenu est lie a la sante ou la medecine. "
                     "EcoRewind est reserve aux publications sur l'environnement."),
            "tip": "Partagez un geste eco : trier ses dechets, planter, economiser l'eau.",
        }

    if any(k in text for k in ["education", "examen", "diplome", "universite",
                                "ecole", "etudiant", "baccalaureat"]):
        return {
            "category": "education", "icon": "school",
            "title": "Hors sujet - Education",
            "body": ("Ce contenu est lie a l'education ou aux etudes. "
                     "EcoRewind est dedie aux publications citoyennes sur l'ecologie."),
            "tip": "Partagez une action eco-citoyenne que vous avez realisee.",
        }

    if any(k in text for k in ["film", "serie", "cinema", "musique", "concert",
                                "netflix", "streaming", "album", "jeu video"]):
        return {
            "category": "entertainment", "icon": "movie",
            "title": "Hors sujet - Divertissement",
            "body": ("Ce contenu est lie au cinema, a la musique ou aux series. "
                     "EcoRewind est dedie aux gestes positifs pour l'environnement."),
            "tip": "Publiez une photo de votre dernier geste ecologique.",
        }

    if any(k in text for k in ["cuisine", "recette", "gastronomie",
                                "restaurant", "plat", "chef", "patisserie"]):
        return {
            "category": "cooking", "icon": "restaurant",
            "title": "Hors sujet - Cuisine",
            "body": ("Ce contenu est lie a la cuisine ou la gastronomie. "
                     "EcoRewind est dedie a la protection de l'environnement."),
            "tip": "Partagez un geste eco : alimentation vegetale, zero dechet, compostage.",
        }

    if any(k in text for k in ["voyage", "tourisme", "hotel", "avion",
                                "destination", "vacances", "visa"]):
        return {
            "category": "travel", "icon": "flight",
            "title": "Hors sujet - Voyage et Tourisme",
            "body": ("Ce contenu est lie au voyage ou au tourisme. "
                     "EcoRewind est dedie aux gestes ecologiques et a la protection de la nature."),
            "tip": "Partagez une action eco-responsable liee a votre quotidien.",
        }

    if any(k in text for k in ["technolog", "informatique", "programm", "cyber",
                                "intelligence artificielle", "logiciel", "smartphone"]):
        return {
            "category": "technology", "icon": "devices",
            "title": "Hors sujet - Technologie",
            "body": ("Ce contenu est lie a la technologie ou l'informatique. "
                     "EcoRewind est dedie aux publications sur l'ecologie."),
            "tip": "Publiez un geste eco : recyclage, nettoyage, plantation d'arbres.",
        }

    if any(k in text for k in ["accident", "mort", "blesse", "collision"]):
        return {
            "category": "news", "icon": "newspaper",
            "title": "Hors sujet - Actualite",
            "body": ("Ce contenu semble lie a un evenement d'actualite. "
                     "EcoRewind est dedie aux publications positives pour l'environnement."),
            "tip": "Partagez un geste eco-responsable que vous avez realise.",
        }

    if any(k in text for k in ["hors sujet", "off-topic", "off_topic", "image non eco"]):
        return {
            "category": "offtopic_image", "icon": "image_not_supported",
            "title": "Image non liee a l'environnement",
            "body": ("Notre IA a detecte que votre image ne semble pas liee a l'ecologie. "
                     "Acceptees : nettoyages, recyclage, nature, jardins, energies renouvelables."),
            "tip": "Remplacez l'image par une photo de votre geste eco-responsable.",
        }

    return {
        "category": "offtopic", "icon": "block",
        "title": "Publication non conforme",
        "body": ("Votre publication ne respecte pas les regles EcoRewind, "
                 "dediee a l'ecologie, la nature et le recyclage."),
        "tip": "Assurez-vous que votre contenu porte sur un theme environnemental.",
    }


def _rejection_message(reasons: list, score: float) -> str:
    return _rejection_details(reasons, score)["body"]


def _format_post(post, liked_ids=None, saved_ids=None, is_liked=False, is_saved=False):
    liked_ids = liked_ids or set()
    saved_ids = saved_ids or set()
    return {
        "id": post.id, "user_id": post.user_id,
        "user_name": post.user_name,
        "user_avatar_url": post.user_avatar_url or "",
        "image_url": post.image_url or "",
        "description": post.description or "",
        "created_at": _utc_iso(post.created_at),
        "likes_count": post.likes_count or 0,
        # ── Champs de modération IA ───────────────────────────────────────────
        "status": post.status or "pending_ai",
        "moderation_score": post.moderation_score or 0.0,
        "moderation_reason": post.moderation_reason or None,
        "moderated_at": _utc_iso(post.moderated_at) if post.moderated_at else None,
        "moderation_model_version": post.moderation_model_version or None,
        "comments": [
            {"id": c.id, "post_id": c.post_id, "user_id": c.user_id,
             "user_name": c.user_name, "user_avatar_url": c.user_avatar_url,
             "content": c.content, "parent_id": c.parent_id,
             "created_at": _utc_iso(c.created_at)}
            for c in (post.comments or [])
        ],
        "is_liked": (post.id in liked_ids) if liked_ids else is_liked,
        "is_saved": (post.id in saved_ids) if saved_ids else is_saved,
    }


# ── Upload ────────────────────────────────────────────────────────────────────

@router.post("/upload")
async def upload_image(file: UploadFile = File(...),
                       current_user: db_models.User = Depends(get_current_user)):
    from PIL import Image, ImageFilter, ImageOps
    from io import BytesIO
    allowed_types = ["image/jpeg", "image/png", "image/gif", "image/webp"]
    allowed_exts = [".jpg", ".jpeg", ".png", ".gif", ".webp"]
    ext = os.path.splitext(file.filename or "")[1].lower()
    if file.content_type not in allowed_types and ext not in allowed_exts:
        raise HTTPException(status_code=400, detail="Type de fichier non autorisé.")
    raw_bytes = await file.read()
    if len(raw_bytes) > 10 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Fichier trop volumineux (max 10 Mo).")
    try:
        img = Image.open(BytesIO(raw_bytes))

        # Corriger l'orientation EXIF (rotation auto des photos smartphone)
        try:
            img = ImageOps.exif_transpose(img)
        except Exception:
            pass

        if img.mode in ("RGBA", "P"):
            img = img.convert("RGB")

        # Résolution max : 1920px (adapté aux écrans modernes Full HD)
        MAX_WIDTH = 1920
        if img.width > MAX_WIDTH:
            ratio = MAX_WIDTH / img.width
            new_h = int(img.height * ratio)
            img = img.resize((MAX_WIDTH, new_h), Image.LANCZOS)
            # Appliquer un filtre de netteté post-redimensionnement
            # (contrebalance le flou inhérent au downscale)
            img = img.filter(ImageFilter.UnsharpMask(radius=1.2, percent=80, threshold=2))

        out = BytesIO()
        # Qualité 92 : excellent compromis netteté/taille (vs 80 qui était trop agressif)
        img.save(out, format="JPEG", quality=92, optimize=True, subsampling=0)
        compressed = out.getvalue()
    except Exception as e:
        if IS_DEV:
            print(f"[UPLOAD] Pillow failed, saving original: {e}")
        compressed = raw_bytes
    unique_name = f"{uuid.uuid4().hex}.jpg"
    with open(os.path.join(UPLOADS_DIR, unique_name), "wb") as f:
        f.write(compressed)
    url = f"/uploads/{unique_name}"
    return {"url": url, "image_url": url}

# ── Moderation d'image unique ────────────────────────────────────────────────────────
@router.post("/moderate-image")
async def moderate_image(file: UploadFile = File(...)):
    """Analyse une image unique sans créer de post.
        Retourne les probabilités par classe (eco, off_topic, nsfw) et le statut
        (published, pending_review, rejected) selon les seuils du modérateur.
    """
    import tempfile, os, shutil
    # Enregistrer temporairement l'image
    try:
        suffix = os.path.splitext(file.filename or "tmp")[1]
        with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
            tmp.write(await file.read())
            tmp_path = tmp.name
        # Utiliser le modérateur CNN pour analyser l'image
        from moderation_ai.eco_moderator import cnn_moderator as moderator
        result = moderator.analyze_image(tmp_path)
        # Déterminer le statut à partir du score et des décisions
        # Le modérateur renvoie un dict avec "score" et "resnet_decision"
        score = result.get("score", 0.0)
        decision = result.get("resnet_decision", "uncertain")
        # Appliquer les seuils globaux du modérateur (SAFE_THRESHOLD, REVIEW_THRESHOLD)
        from services.ai_moderator import SAFE_THRESHOLD, REVIEW_THRESHOLD
        if decision == "nsfw" or score >= REVIEW_THRESHOLD:
            status = "rejected"
        elif decision == "off_topic" or score >= SAFE_THRESHOLD:
            status = "pending_review"
        else:
            status = "published"
        # Nettoyer le fichier temporaire
        os.remove(tmp_path)
        return {"status": status, "score": round(score, 3), "decision": decision, "probabilities": result}
    except Exception as e:
        # En cas d'erreur, renvoyer un message générique
        return {"error": str(e)}

# ── Posts CRUD ────────────────────────────────────────────────────────────────

@router.post("/posts", response_model=models.Post)
async def create_post(post: models.PostCreate, db: Session = Depends(get_db),
                      current_user: db_models.User = Depends(get_current_user)):
    """
    Flux de publication avec audit IA complet :

    1. Le post est IMMÉDIATEMENT persisté en DB avec status="pending_ai".
       → Garantit la traçabilité même si l'IA plante en cours d'analyse.

    2. L'IA analyse texte + image.

    3. Le statut est mis à jour selon le résultat :
         - score < 0.30                → "published"
         - 0.30 ≤ score < 0.65        → "pending_review" (admin valide)
         - score ≥ 0.65 (ou "rejected") → "pending_review" (admin tranche,
           jamais auto-supprimé pour conserver la preuve de tentative)

    4. moderated_at et moderation_model_version sont enregistrés à chaque décision.
    """
    from moderation_ai.eco_moderator import cnn_moderator as moderator
    from fastapi.responses import JSONResponse as _JSONResponse

    # ── Étape 1 : Créer le post en DB avec status="pending_ai" ─────────────────
    # Garantit l'auditabilité même si l'analyse IA échoue.
    new_post = db_models.Post(
        user_id=current_user.id,
        user_name=post.user_name,
        user_avatar_url=post.user_avatar_url,
        image_url=post.image_url,
        description=post.description,
        status="pending_ai",        # Statut transitoire obligatoire
        moderation_score=0.0,
        moderation_reason=None,
        moderation_details=None,
        moderated_at=None,
        moderation_model_version=None,
    )
    db.add(new_post)
    db.commit()
    db.refresh(new_post)

    if IS_DEV:
        print(f"📝 [MOD] Post {new_post.id} créé → status=pending_ai (avant analyse IA)")

    # ── Étape 2 : Analyse IA ────────────────────────────────────────────────────
    # Résoudre le chemin local de l'image pour l'analyse IA
    image_local_path = ""
    if post.image_url:
        filename = os.path.basename(post.image_url)
        candidate = os.path.join(UPLOADS_DIR, filename)
        if os.path.exists(candidate):
            image_local_path = candidate

    try:
        mod_result = moderator.moderate(
            text=post.description or "",
            image_local_path=image_local_path,
        )
        ai_error = False
    except Exception as e:
        # L'IA a planté : le post reste en pending_ai (ne sera pas publié)
        # L'admin verra les posts bloqués en pending_ai et pourra intervenir.
        if IS_DEV:
            print(f"🔴 [MOD] Erreur IA sur post {new_post.id} : {e}")
        new_post.moderation_reason = f"AI_ERROR:{str(e)[:120]}"
        new_post.moderated_at = datetime.utcnow()
        db.commit()
        # Retourner le post en pending_ai — Flutter affiche un message générique
        post_data = _format_post(new_post)
        post_data["ai_flagged"] = False
        return _JSONResponse(content=post_data, status_code=200)

    if IS_DEV:
        print(f"🤖 [MOD] Post {new_post.id} score={mod_result.score:.3f} status={mod_result.status} | {mod_result.reasons}")

    # ── Étape 3 : Calculer le statut final et la version du modèle ─────────────
    # Construire la version du pipeline utilisé (ex: "cnn_text+resnet18+nudenet")
    model_parts = []
    if mod_result.text_model_used:
        model_parts.append(mod_result.text_model_used)
    if mod_result.image_model_used:
        model_parts.append(mod_result.image_model_used)
    # Ajouter le nom du pipeline CNN si disponible
    try:
        if hasattr(moderator, '_obj') and moderator._obj is not None:
            model_parts.append("EcoCNN_v1")
        elif hasattr(moderator, '_cnn_ready'):
            model_parts.append("EcoCNN_v1")
    except Exception:
        pass
    model_version = "|".join(model_parts) if model_parts else "rules_only"

    # Le contenu signalé comme rejected → envoyé en pending_review (admin décide)
    if mod_result.status == "rejected":
        details = _rejection_details(mod_result.reasons, mod_result.score)
        final_status = "pending_review"
        moderation_reason = f"AI_FLAGGED:{details['category']}"
    else:
        details = None
        final_status = mod_result.status   # "published" ou "pending_review"
        moderation_reason = mod_result.short_reason

    # ── Étape 4 : Mettre à jour le post avec le résultat de l'IA ───────────────
    new_post.status                   = final_status
    new_post.moderation_score         = mod_result.score
    new_post.moderation_reason        = moderation_reason
    new_post.moderation_details       = mod_result.to_json()
    new_post.moderated_at             = datetime.utcnow()   # Horodatage de la décision
    new_post.moderation_model_version = model_version
    db.commit()
    db.refresh(new_post)

    if IS_DEV:
        print(f"✅ [MOD] Post {new_post.id} mis à jour → status={final_status} | model={model_version}")

    # ── Étape 5 : Notifications ─────────────────────────────────────────────────
    if details is not None:
        # Contenu initialement rejeté → signalé, admin tranche
        notif = db_models.Notification(
            user_id=current_user.id,
            type="moderation",
            title="⚠️ Publication signalée par l'IA",
            body=(
                "Votre publication a été détectée comme potentiellement hors-sujet "
                "par notre IA. Elle a été transmise à un administrateur pour vérification. "
                "Vous serez notifié(e) dès sa décision."
            ),
            from_user_name="EcoRewind IA",
            post_id=new_post.id,
        )
        db.add(notif)
        db.commit()

        post_data = _format_post(new_post)
        post_data.update({
            "ai_flagged":         True,
            "rejection_category": details["category"],
            "rejection_title":    details["title"],
            "rejection_body":     details["body"],
            "rejection_tip":      details["tip"],
        })
        return _JSONResponse(content=post_data, status_code=200)

    if final_status == "pending_review":
        notif = db_models.Notification(
            user_id=current_user.id,
            type="moderation",
            title="⏳ Publication en cours de vérification",
            body="Votre publication est en attente de validation par notre équipe de modération. Vous serez notifié dès qu'elle sera traitée.",
            from_user_name="EcoRewind IA",
            post_id=new_post.id,
        )
        db.add(notif)
        db.commit()

    post_data = _format_post(new_post)
    post_data["ai_flagged"] = False
    return _JSONResponse(content=post_data, status_code=200)




@router.get("/posts/{post_id}/detail")
async def get_single_post(post_id: int, db: Session = Depends(get_db),
                          authorization: Optional[str] = Header(None)):
    from jose import jwt as _jwt, JWTError as _JWTError
    from auth import SECRET_KEY, ALGORITHM
    post = db.query(db_models.Post).options(joinedload(db_models.Post.comments)).filter(
        db_models.Post.id == post_id).first()
    if not post:
        raise HTTPException(status_code=404, detail="Publication non trouvée")
    is_liked = is_saved = False
    if authorization and authorization.startswith("Bearer "):
        try:
            payload = _jwt.decode(authorization.split(" ")[1], SECRET_KEY, algorithms=[ALGORITHM])
            email = payload.get("sub")
            if email:
                user = db.query(db_models.User).filter(db_models.User.email == email).first()
                if user:
                    is_liked = db.query(db_models.Like).filter(
                        db_models.Like.user_id == user.id,
                        db_models.Like.post_id == post_id).first() is not None
                    is_saved = db.query(db_models.SavedPost).filter(
                        db_models.SavedPost.user_id == user.id,
                        db_models.SavedPost.post_id == post_id).first() is not None
        except _JWTError:
            pass
    return _format_post(post, is_liked=is_liked, is_saved=is_saved)


@router.get("/posts")
async def get_posts(skip: int = 0, limit: int = 50, db: Session = Depends(get_db)):
    limit = min(limit, 50)
    posts = db.query(db_models.Post).options(joinedload(db_models.Post.comments)).filter(
        db_models.Post.status == "published"  # Seuls les posts approuvés
    ).order_by(
        db_models.Post.created_at.desc()).offset(skip).limit(limit).all()
    result = [_format_post(p) for p in posts]
    body = _json.dumps(result, default=str)
    etag = hashlib.md5(body.encode()).hexdigest()
    return JSONResponse(content=result, headers={
        "Cache-Control": "public, max-age=30, stale-while-revalidate=60",
        "ETag": f'"{etag}"',
    })


@router.get("/posts/feed")
async def get_feed(skip: int = 0, limit: int = 50, db: Session = Depends(get_db),
                   current_user: db_models.User = Depends(get_current_user)):
    limit = min(limit, 50)
    posts = db.query(db_models.Post).options(joinedload(db_models.Post.comments)).filter(
        db_models.Post.status == "published"  # Seuls les posts approuvés
    ).order_by(
        db_models.Post.created_at.desc()).offset(skip).limit(limit).all()
    user_id = current_user.id
    liked_ids = {r[0] for r in db.query(db_models.Like.post_id).filter(db_models.Like.user_id == user_id).all()}
    saved_ids = {r[0] for r in db.query(db_models.SavedPost.post_id).filter(db_models.SavedPost.user_id == user_id).all()}
    result = [_format_post(p, liked_ids=liked_ids, saved_ids=saved_ids) for p in posts]
    body = _json.dumps(result, default=str)
    etag = hashlib.md5(body.encode()).hexdigest()
    return JSONResponse(content=result, headers={
        "Cache-Control": "private, max-age=15, stale-while-revalidate=30",
        "ETag": f'"u{user_id}-{etag}"',
    })


@router.put("/posts/{post_id}", response_model=models.Post)
async def update_post(post_id: int, post_update: models.PostUpdate,
                      db: Session = Depends(get_db),
                      current_user: db_models.User = Depends(get_current_user)):
    db_post = db.query(db_models.Post).filter(db_models.Post.id == post_id).first()
    if not db_post:
        raise HTTPException(status_code=404, detail="Publication non trouvée")
    if db_post.user_id != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Non autorisé")
    if post_update.description:
        db_post.description = post_update.description
    if post_update.image_url:
        db_post.image_url = post_update.image_url
    db.commit()
    db.refresh(db_post)
    return db_post


@router.delete("/posts/{post_id}")
async def delete_post(post_id: int, db: Session = Depends(get_db),
                      current_user: db_models.User = Depends(get_current_user)):
    db_post = db.query(db_models.Post).filter(db_models.Post.id == post_id).first()
    if not db_post:
        raise HTTPException(status_code=404, detail="Publication non trouvée")
    if db_post.user_id != current_user.id and current_user.role != "admin":
        raise HTTPException(status_code=403, detail="Non autorisé")
    db.delete(db_post)
    db.commit()
    return {"message": "Publication supprimée"}


# ── Likes ─────────────────────────────────────────────────────────────────────

@router.post("/posts/{post_id}/like")
async def toggle_like(post_id: int, db: Session = Depends(get_db),
                      current_user: db_models.User = Depends(get_current_user)):
    user_id = current_user.id
    db_post = db.query(db_models.Post).filter(db_models.Post.id == post_id).first()
    if not db_post:
        raise HTTPException(status_code=404, detail="Post non trouvé")
    existing = db.query(db_models.Like).filter(
        db_models.Like.user_id == user_id, db_models.Like.post_id == post_id).first()
    if existing:
        db.delete(existing)
        db_post.likes_count = max(0, (db_post.likes_count or 0) - 1)
        db.commit()
        return {"liked": False, "count": db_post.likes_count}
    db.add(db_models.Like(user_id=user_id, post_id=post_id))
    db_post.likes_count = (db_post.likes_count or 0) + 1
    db.commit()
    if db_post.user_id != user_id:
        db.add(db_models.Notification(
            user_id=db_post.user_id, type="like", title="Nouveau j'aime",
            body=f"{current_user.full_name} a aimé votre publication",
            from_user_name=current_user.full_name, post_id=post_id))
        db.commit()
        # ── Push FCM ──────────────────────────────────────────────────────────
        try:
            from services.fcm_push_service import send_push_to_user
            send_push_to_user(
                db=db,
                user_id=db_post.user_id,
                title="❤️ Nouveau j'aime",
                body=f"{current_user.full_name} a aimé votre publication",
                data={"type": "like", "post_id": str(post_id)},
            )
        except Exception as _e:
            print(f"[FCM] Erreur push like : {_e}")
    return {"liked": True, "count": db_post.likes_count}


@router.get("/posts/{post_id}/likers", response_model=List[models.UserSmall])
async def get_likers(post_id: int, db: Session = Depends(get_db)):
    likes = db.query(db_models.Like).filter(db_models.Like.post_id == post_id).all()
    return db.query(db_models.User).filter(db_models.User.id.in_([l.user_id for l in likes])).all()


# ── Saves ─────────────────────────────────────────────────────────────────────

@router.post("/posts/{post_id}/save")
async def save_post(post_id: int, db: Session = Depends(get_db),
                    current_user: db_models.User = Depends(get_current_user)):
    user_id = current_user.id
    existing = db.query(db_models.SavedPost).filter(
        db_models.SavedPost.user_id == user_id,
        db_models.SavedPost.post_id == post_id).first()
    if existing:
        db.delete(existing)
        db.commit()
        return {"message": "Retiré des favoris", "saved": False}
    db.add(db_models.SavedPost(user_id=user_id, post_id=post_id))
    db.commit()
    db_post = db.query(db_models.Post).filter(db_models.Post.id == post_id).first()
    if db_post and db_post.user_id != user_id:
        db.add(db_models.Notification(
            user_id=db_post.user_id, type="save", title="Publication sauvegardée",
            body=f"{current_user.full_name} a sauvegardé votre publication",
            from_user_name=current_user.full_name, post_id=post_id))
        db.commit()
        # ── Push FCM ──────────────────────────────────────────────────────────
        try:
            from services.fcm_push_service import send_push_to_user
            send_push_to_user(
                db=db,
                user_id=db_post.user_id,
                title="🔖 Publication sauvegardée",
                body=f"{current_user.full_name} a sauvegardé votre publication",
                data={"type": "save", "post_id": str(post_id)},
            )
        except Exception as _e:
            print(f"[FCM] Erreur push save : {_e}")
    return {"message": "Publication enregistrée", "saved": True}


@router.get("/users/me/saved-posts", response_model=List[models.Post])
async def get_saved_posts(db: Session = Depends(get_db),
                          current_user: db_models.User = Depends(get_current_user)):
    saved_refs = db.query(db_models.SavedPost).filter(
        db_models.SavedPost.user_id == current_user.id).all()
    post_ids = [ref.post_id for ref in saved_refs]
    return db.query(db_models.Post).options(joinedload(db_models.Post.comments)).filter(
        db_models.Post.id.in_(post_ids)).all()


# ── Comments ──────────────────────────────────────────────────────────────────

@router.post("/posts/{post_id}/comments", response_model=models.Comment)
async def create_comment(post_id: int, comment: models.CommentCreate,
                         db: Session = Depends(get_db),
                         current_user: db_models.User = Depends(get_current_user)):
    db_post = db.query(db_models.Post).filter(db_models.Post.id == post_id).first()
    if not db_post:
        raise HTTPException(status_code=404, detail="Publication non trouvée")
    new_comment = db_models.Comment(
        post_id=post_id, user_id=current_user.id,
        user_name=comment.user_name, user_avatar_url=comment.user_avatar_url,
        content=comment.content, parent_id=comment.parent_id,
    )
    db.add(new_comment)
    db.commit()
    db.refresh(new_comment)
    if db_post.user_id != current_user.id:
        db.add(db_models.Notification(
            user_id=db_post.user_id, type="comment", title="Nouveau commentaire",
            body=f"{current_user.full_name} a commenté votre publication",
            from_user_name=current_user.full_name,
            post_id=post_id, comment_id=new_comment.id))
        db.commit()
        # ── Push FCM ──────────────────────────────────────────────────────────
        try:
            from services.fcm_push_service import send_push_to_user
            send_push_to_user(
                db=db,
                user_id=db_post.user_id,
                title="💬 Nouveau commentaire",
                body=f"{current_user.full_name} a commenté votre publication",
                data={"type": "comment", "post_id": str(post_id), "comment_id": str(new_comment.id)},
            )
        except Exception as _e:
            print(f"[FCM] Erreur push comment : {_e}")
    if comment.parent_id:
        parent = db.query(db_models.Comment).filter(
            db_models.Comment.id == comment.parent_id).first()
        if parent and parent.user_id != current_user.id:
            db.add(db_models.Notification(
                user_id=parent.user_id, type="comment",
                title="Réponse à votre commentaire",
                body=f"{current_user.full_name} a répondu à votre commentaire",
                from_user_name=current_user.full_name,
                post_id=post_id, comment_id=new_comment.id))
            db.commit()
            # ── Push FCM (réponse) ─────────────────────────────────────────────
            try:
                from services.fcm_push_service import send_push_to_user
                send_push_to_user(
                    db=db,
                    user_id=parent.user_id,
                    title="↩️ Réponse à votre commentaire",
                    body=f"{current_user.full_name} a répondu à votre commentaire",
                    data={"type": "comment", "post_id": str(post_id), "comment_id": str(new_comment.id)},
                )
            except Exception as _e:
                print(f"[FCM] Erreur push reply : {_e}")
    return new_comment


@router.put("/comments/{comment_id}", response_model=models.Comment)
async def update_comment(comment_id: int, comment_update: models.CommentUpdate,
                         db: Session = Depends(get_db),
                         current_user: db_models.User = Depends(get_current_user)):
    db_comment = db.query(db_models.Comment).filter(db_models.Comment.id == comment_id).first()
    if not db_comment:
        raise HTTPException(status_code=404, detail="Commentaire non trouvé")
    if db_comment.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Non autorisé")
    db_comment.content = comment_update.content
    db.commit()
    db.refresh(db_comment)
    return db_comment


@router.delete("/comments/{comment_id}")
async def delete_comment(comment_id: int, db: Session = Depends(get_db),
                         current_user: db_models.User = Depends(get_current_user)):
    db_comment = db.query(db_models.Comment).filter(db_models.Comment.id == comment_id).first()
    if not db_comment:
        raise HTTPException(status_code=404, detail="Commentaire non trouvé")
    if db_comment.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Non autorisé")
    db.delete(db_comment)
    db.commit()
    return {"message": "Commentaire supprimé"}
