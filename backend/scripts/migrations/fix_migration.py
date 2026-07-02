import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""
fix_migration.py — Migration directe SQLite -> PostgreSQL avec commit par ligne
"""
import sys, os, sqlite3, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

import psycopg2

PG_URL = "postgresql://postgres@localhost:5432/ecorewind"
SQLITE_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sql_app.db")

TABLES = [
    "users", "posts", "saved_posts", "likes", "comments",
    "otp_codes", "notifications", "collection_points",
    "testimonials", "center_proposals", "video_categories",
    "educator_videos", "quizzes", "quiz_submissions",
]

def migrate():
    pg = psycopg2.connect(PG_URL)
    sq = sqlite3.connect(SQLITE_PATH)
    sq.row_factory = sqlite3.Row
    pg_cur = pg.cursor()
    sq_cur = sq.cursor()

    grand_total = 0

    for table in TABLES:
        try:
            sq_cur.execute(f"SELECT * FROM {table}")
            rows = sq_cur.fetchall()
            if not rows:
                print(f"  VIDE : {table}")
                continue

            cols = [d[0] for d in sq_cur.description]
            col_str = ", ".join([f'"{c}"' for c in cols])
            placeholders = ", ".join(["%s"] * len(cols))
            sql = f'INSERT INTO {table} ({col_str}) VALUES ({placeholders}) ON CONFLICT DO NOTHING'

            inserted = 0
            skipped = 0
            for row in rows:
                try:
                    pg_cur.execute(sql, list(row))
                    pg.commit()
                    inserted += 1
                except Exception:
                    pg.rollback()
                    skipped += 1

            print(f"  OK : {table} -> {inserted} inserees, {skipped} ignorees (doublons)")
            grand_total += inserted

        except sqlite3.OperationalError:
            print(f"  SKIP : {table} (table inexistante dans SQLite)")
        except Exception as e:
            print(f"  ERR  : {table} -> {e}")

    # Reset sequences
    print("\nRemise a jour des sequences...")
    for table in TABLES:
        try:
            pg_cur.execute(f"""
                SELECT setval(
                    pg_get_serial_sequence('{table}', 'id'),
                    COALESCE((SELECT MAX(id) FROM {table}), 1)
                )
            """)
            pg.commit()
        except Exception:
            pg.rollback()

    print(f"\n[DONE] {grand_total} lignes migrees au total vers PostgreSQL.")
    pg.close()
    sq.close()

if __name__ == "__main__":
    migrate()
