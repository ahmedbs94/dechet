"""
EcoRewind Educator Videos Router
==================================
- Catégories (dossiers) : titre + image de couverture + description
- Vidéos : uploadées depuis le PC, rangées dans une catégorie
"""

import os
import uuid
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, File, UploadFile, Form
from sqlalchemy.orm import Session
from sqlalchemy import desc

import db_models as db_models
from database import get_db
from core.deps import get_current_user, _utc_iso

router = APIRouter(prefix="/educator-videos", tags=["educator-videos"])

UPLOADS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "uploads")
VIDEOS_DIR = os.path.join(UPLOADS_DIR, "videos")
COVERS_DIR = os.path.join(UPLOADS_DIR, "covers")
os.makedirs(VIDEOS_DIR, exist_ok=True)
os.makedirs(COVERS_DIR, exist_ok=True)

ALLOWED_VIDEO_EXT = {".mp4", ".webm", ".mov", ".avi", ".mkv"}
ALLOWED_IMAGE_EXT = {".jpg", ".jpeg", ".png", ".webp"}


# ── Formatters ────────────────────────────────────────────────────────────────

def _is_youtube_url(url: str) -> bool:
    """Retourne True si l'URL est une miniature ou lien YouTube."""
    if not url:
        return False
    return any(h in url for h in ("youtube.com", "youtu.be", "img.youtube.com"))


def _fmt_video(v: db_models.EducatorVideo) -> dict:
    # On ne renvoie jamais une URL YouTube comme thumbnail :
    # les vidéos doivent être locales uniquement.
    safe_thumbnail = v.thumbnail_url
    if safe_thumbnail and _is_youtube_url(safe_thumbnail):
        safe_thumbnail = None

    return {
        "id": v.id,
        "educator_id": v.educator_id,
        "educator_name": v.educator_name,
        "title": v.title,
        "description": v.description or "",
        "video_url": v.video_url,
        "thumbnail_url": safe_thumbnail,
        "duration": v.duration,
        "category_id": v.category_id,
        "created_at": _utc_iso(v.created_at),
    }



def _fmt_category(c: db_models.VideoCategory, include_videos: bool = False) -> dict:
    data = {
        "id": c.id,
        "title": c.title,
        "description": c.description or "",
        "cover_image_url": c.cover_image_url,
        "educator_id": c.educator_id,
        "video_count": len(c.videos) if c.videos else 0,
        "created_at": _utc_iso(c.created_at),
    }
    if include_videos:
        data["videos"] = [_fmt_video(v) for v in sorted(c.videos, key=lambda x: x.created_at or datetime.min, reverse=True)]
    return data


# ═══════════════════════════════════════════════════════════════════════════════
#  CATÉGORIES : CRUD
# ═══════════════════════════════════════════════════════════════════════════════

@router.post("/categories")
async def create_category(
    title: str = Form(...),
    description: Optional[str] = Form(None),
    cover_image: Optional[UploadFile] = File(None),
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """Crée une catégorie (dossier) avec titre et image de couverture."""
    if current_user.role not in ("educator", "admin"):
        raise HTTPException(status_code=403, detail="Réservé aux éducateurs.")

    cover_url = None
    if cover_image and cover_image.filename:
        ext = os.path.splitext(cover_image.filename)[1].lower()
        if ext not in ALLOWED_IMAGE_EXT:
            raise HTTPException(status_code=400, detail=f"Image: {', '.join(ALLOWED_IMAGE_EXT)} uniquement.")
        img_bytes = await cover_image.read()
        fname = f"cover_{uuid.uuid4().hex}{ext}"
        with open(os.path.join(COVERS_DIR, fname), "wb") as f:
            f.write(img_bytes)
        cover_url = f"/uploads/covers/{fname}"

    cat = db_models.VideoCategory(
        title=title,
        description=description,
        cover_image_url=cover_url,
        educator_id=current_user.id,
    )
    db.add(cat)
    db.commit()
    db.refresh(cat)
    return {"message": "Catégorie créée !", "category": _fmt_category(cat)}


@router.get("/categories")
async def list_categories(db: Session = Depends(get_db)):
    """Liste toutes les catégories avec le nombre de vidéos (public)."""
    cats = db.query(db_models.VideoCategory).order_by(desc(db_models.VideoCategory.created_at)).all()
    return {"categories": [_fmt_category(c) for c in cats]}


@router.get("/categories/{cat_id}")
async def get_category(cat_id: int, db: Session = Depends(get_db)):
    """Détail d'une catégorie avec toutes ses vidéos."""
    cat = db.query(db_models.VideoCategory).filter(db_models.VideoCategory.id == cat_id).first()
    if not cat:
        raise HTTPException(status_code=404, detail="Catégorie non trouvée")
    return _fmt_category(cat, include_videos=True)


@router.delete("/categories/{cat_id}")
async def delete_category(
    cat_id: int,
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """Supprime une catégorie (les vidéos restent, category_id → null)."""
    cat = db.query(db_models.VideoCategory).filter(db_models.VideoCategory.id == cat_id).first()
    if not cat:
        raise HTTPException(status_code=404, detail="Catégorie non trouvée")
    if cat.educator_id != current_user.id and current_user.role not in ["admin", "superadmin"]:
        raise HTTPException(status_code=403, detail="Non autorisé")

    # Détacher les vidéos
    for v in cat.videos:
        v.category_id = None
    # Supprimer image de couverture
    if cat.cover_image_url and cat.cover_image_url.startswith("/uploads/covers/"):
        path = os.path.join(COVERS_DIR, os.path.basename(cat.cover_image_url))
        if os.path.exists(path):
            os.remove(path)

    db.delete(cat)
    db.commit()
    return {"message": "Catégorie supprimée"}


# ═══════════════════════════════════════════════════════════════════════════════
#  VIDÉOS : Upload dans une catégorie
# ═══════════════════════════════════════════════════════════════════════════════

@router.post("/upload")
async def upload_video(
    file: UploadFile = File(...),
    title: Optional[str] = Form(None),
    description: Optional[str] = Form(None),
    duration: Optional[str] = Form(None),
    category_id: Optional[int] = Form(None),
    db: Session = Depends(get_db),
    current_user: db_models.User = Depends(get_current_user),
):
    """Upload un fichier vidéo, optionnellement dans une catégorie."""
    if current_user.role not in ("educator", "admin", "superadmin"):
        raise HTTPException(status_code=403, detail="Réservé aux éducateurs.")

    if not file.filename:
        raise HTTPException(status_code=400, detail="Nom de fichier manquant.")

    ext = os.path.splitext(file.filename)[1].lower()
    if ext not in ALLOWED_VIDEO_EXT:
        raise HTTPException(status_code=400, detail=f"Format non supporté: {', '.join(ALLOWED_VIDEO_EXT)}")

    video_bytes = await file.read()
    if len(video_bytes) > 200 * 1024 * 1024:
        raise HTTPException(status_code=400, detail="Fichier trop volumineux (max 200 Mo).")

    # Vérifier catégorie si fournie
    if category_id:
        cat = db.query(db_models.VideoCategory).filter(db_models.VideoCategory.id == category_id).first()
        if not cat:
            raise HTTPException(status_code=404, detail="Catégorie non trouvée")

    video_filename = f"edu_video_{uuid.uuid4().hex}{ext}"
    with open(os.path.join(VIDEOS_DIR, video_filename), "wb") as f:
        f.write(video_bytes)

    new_video = db_models.EducatorVideo(
        educator_id=current_user.id,
        educator_name=current_user.full_name or current_user.email,
        title=title or file.filename.rsplit(".", 1)[0],
        description=description,
        video_url=f"/uploads/videos/{video_filename}",
        thumbnail_url=None,
        duration=duration,
        category_id=category_id,
    )
    db.add(new_video)
    db.commit()
    db.refresh(new_video)
    return {"message": "Vidéo publiée !", "video": _fmt_video(new_video)}


# ═══════════════════════════════════════════════════════════════════════════════
#  PUBLIC : Lister toutes les vidéos
# ═══════════════════════════════════════════════════════════════════════════════

@router.get("/")
async def list_all_videos(skip: int = 0, limit: int = 50, db: Session = Depends(get_db)):
    videos = db.query(db_models.EducatorVideo).order_by(desc(db_models.EducatorVideo.created_at)).offset(skip).limit(limit).all()
    return {"videos": [_fmt_video(v) for v in videos], "total": db.query(db_models.EducatorVideo).count()}


@router.get("/my-videos")
async def list_my_videos(db: Session = Depends(get_db), current_user: db_models.User = Depends(get_current_user)):
    videos = db.query(db_models.EducatorVideo).filter(db_models.EducatorVideo.educator_id == current_user.id).order_by(desc(db_models.EducatorVideo.created_at)).all()
    return {"videos": [_fmt_video(v) for v in videos]}


@router.delete("/{video_id}")
async def delete_video(video_id: int, db: Session = Depends(get_db), current_user: db_models.User = Depends(get_current_user)):
    video = db.query(db_models.EducatorVideo).filter(db_models.EducatorVideo.id == video_id).first()
    if not video:
        raise HTTPException(status_code=404, detail="Vidéo non trouvée")
    if video.educator_id != current_user.id and current_user.role not in ["admin", "superadmin"]:
        raise HTTPException(status_code=403, detail="Non autorisé")
    if video.video_url and video.video_url.startswith("/uploads/videos/"):
        path = os.path.join(VIDEOS_DIR, os.path.basename(video.video_url))
        if os.path.exists(path):
            os.remove(path)
    db.delete(video)
    db.commit()
    return {"message": "Vidéo supprimée"}
