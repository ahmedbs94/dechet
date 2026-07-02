import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""Verifie le mot de passe non hache et les sequences."""
import os, io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

from dotenv import load_dotenv
load_dotenv()
from sqlalchemy import create_engine, text

e = create_engine("postgresql://postgres@localhost:5432/ecorewind")

print("=" * 60)
print("  1. MOT DE PASSE NON HACHE")
print("=" * 60)
with e.connect() as c:
    rows = c.execute(text(
        "SELECT id, email, LEFT(hashed_password, 30) as pwd_preview "
        "FROM users WHERE hashed_password IS NOT NULL "
        "AND hashed_password NOT LIKE '$2b$%' "
        "AND hashed_password NOT LIKE '$2a$%'"
    )).fetchall()
    if rows:
        for r in rows:
            print(f"  id={r[0]}, email={r[1]}, pwd={r[2]}...")
    else:
        print("  Aucun mot de passe non hache")

print()
print("=" * 60)
print("  2. SEQUENCES AUTO-INCREMENT")
print("=" * 60)

tables = [
    "users", "posts", "comments", "likes", "saved_posts",
    "otp_codes", "notifications", "collection_points",
    "testimonials", "center_proposals", "quizzes",
    "quiz_submissions", "video_categories", "educator_videos", "bin_scans"
]

issues = 0
with e.connect() as c:
    for t in tables:
        try:
            max_id = c.execute(text(f"SELECT MAX(id) FROM {t}")).scalar()
            seq = c.execute(text(f"SELECT last_value FROM {t}_id_seq")).scalar()
            ok = "OK" if (max_id is None or seq >= max_id) else "DESYNC!"
            if ok != "OK":
                issues += 1
            print(f"  {t:<25} MAX(id)={str(max_id):>5}  seq={str(seq):>5}  [{ok}]")
        except Exception as ex:
            print(f"  {t:<25} ERREUR: {str(ex)[:50]}")

if issues > 0:
    print(f"\n  {issues} sequence(s) desynchronisee(s) - correction...")
    with e.connect() as c:
        for t in tables:
            try:
                c.execute(text(f"SELECT setval('{t}_id_seq', COALESCE((SELECT MAX(id) FROM {t}), 1))"))
                c.commit()
            except Exception:
                pass
    print("  Sequences corrigees !")
else:
    print(f"\n  Toutes les sequences sont OK")
