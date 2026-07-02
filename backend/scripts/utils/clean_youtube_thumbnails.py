"""
clean_youtube_thumbnails.py
============================
Nettoie la base de données en mettant à NULL toutes les thumbnail_url
qui pointent vers YouTube (img.youtube.com, youtube.com, youtu.be).

Les vidéos EcoRewind sont désormais 100% locales (uploadées par l'éducateur).
Lancez ce script une seule fois depuis le dossier backend/ :

    python clean_youtube_thumbnails.py
"""

import sys
import os
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

from database import SessionLocal
import db_models

YOUTUBE_MARKERS = ("youtube.com", "youtu.be", "img.youtube.com")

def is_youtube(url: str) -> bool:
    if not url:
        return False
    return any(m in url for m in YOUTUBE_MARKERS)

def main():
    db = SessionLocal()
    try:
        videos = db.query(db_models.EducatorVideo).filter(
            db_models.EducatorVideo.thumbnail_url.isnot(None)
        ).all()

        cleaned = 0
        for v in videos:
            if is_youtube(v.thumbnail_url or ""):
                print(f"  [CLEAN] id={v.id} title='{v.title}' thumbnail={v.thumbnail_url}")
                v.thumbnail_url = None
                cleaned += 1

        db.commit()
        print(f"\n[OK] {cleaned} thumbnail(s) YouTube supprimee(s) de la base de donnees.")
        if cleaned == 0:
            print("   (Aucune entree YouTube trouvee -- base deja propre.)")
    finally:
        db.close()

if __name__ == "__main__":
    main()
