import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""Verifie exactement les passwords."""
import io, sys
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
from dotenv import load_dotenv; load_dotenv()
from sqlalchemy import create_engine, text
e = create_engine("postgresql://postgres@localhost:5432/ecorewind")
with e.connect() as c:
    rows = c.execute(text(
        "SELECT id, email, hashed_password, google_id, facebook_id FROM users ORDER BY id"
    )).fetchall()
    print(f"{'ID':>4} {'Email':<32} {'Hash OK':>8} {'Google':>8} {'FB':>8} {'Password':>20}")
    print(f"{'-'*4} {'-'*32} {'-'*8} {'-'*8} {'-'*8} {'-'*20}")
    for r in rows:
        pwd = r[2] or ""
        is_hashed = pwd.startswith("$2b$") or pwd.startswith("$2a$")
        has_google = "Yes" if r[3] else "-"
        has_fb = "Yes" if r[4] else "-"
        pwd_status = "bcrypt" if is_hashed else ("None(FB)" if r[4] else ("None(G)" if r[3] else "EMPTY!"))
        print(f"{r[0]:>4} {r[1][:32]:<32} {str(is_hashed):>8} {has_google:>8} {has_fb:>8} {pwd_status:>20}")
