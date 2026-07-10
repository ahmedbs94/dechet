import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""
Migration : Create video_categories table + add category_id to educator_videos
"""
import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sql_app.db")

def migrate():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # 1. Create video_categories table
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='video_categories'")
    if not cursor.fetchone():
        cursor.execute("""
            CREATE TABLE video_categories (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title VARCHAR NOT NULL,
                description TEXT,
                cover_image_url VARCHAR,
                educator_id INTEGER NOT NULL,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (educator_id) REFERENCES users(id)
            )
        """)
        cursor.execute("CREATE INDEX ix_video_categories_id ON video_categories(id)")
        cursor.execute("CREATE INDEX ix_video_categories_educator_id ON video_categories(educator_id)")
        print("[OK] Table 'video_categories' created.")
    else:
        print("[SKIP] Table 'video_categories' already exists.")

    # 2. Add category_id column to educator_videos
    cursor.execute("PRAGMA table_info(educator_videos)")
    columns = [col[1] for col in cursor.fetchall()]
    if "category_id" not in columns:
        cursor.execute("ALTER TABLE educator_videos ADD COLUMN category_id INTEGER REFERENCES video_categories(id)")
        cursor.execute("CREATE INDEX ix_educator_videos_category_id ON educator_videos(category_id)")
        print("[OK] Column 'category_id' added to educator_videos.")
    else:
        print("[SKIP] Column 'category_id' already exists.")

    conn.commit()
    conn.close()

if __name__ == "__main__":
    migrate()
