import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""
Migration : Create educator_videos table
"""
import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sql_app.db")

def migrate():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Check if table already exists
    cursor.execute("SELECT name FROM sqlite_master WHERE type='table' AND name='educator_videos'")
    if cursor.fetchone():
        print("[SKIP] Table 'educator_videos' already exists.")
        conn.close()
        return

    cursor.execute("""
        CREATE TABLE educator_videos (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            educator_id INTEGER NOT NULL,
            educator_name VARCHAR NOT NULL,
            title VARCHAR NOT NULL,
            description TEXT,
            video_url VARCHAR NOT NULL,
            thumbnail_url VARCHAR,
            duration VARCHAR,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (educator_id) REFERENCES users(id)
        )
    """)
    cursor.execute("CREATE INDEX ix_educator_videos_educator_id ON educator_videos(educator_id)")
    cursor.execute("CREATE INDEX ix_educator_videos_id ON educator_videos(id)")

    conn.commit()
    conn.close()
    print("[OK] Table 'educator_videos' created successfully.")

if __name__ == "__main__":
    migrate()
