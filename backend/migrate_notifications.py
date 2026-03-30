"""Migration: Create notifications table"""
import sqlite3

DB_PATH = "sql_app.db"

def migrate():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    try:
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS notifications (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                user_id INTEGER NOT NULL,
                type VARCHAR NOT NULL,
                title VARCHAR,
                body VARCHAR,
                from_user_name VARCHAR,
                post_id INTEGER,
                is_read BOOLEAN DEFAULT 0,
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id)
            )
        """)
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_notif_user ON notifications(user_id)")
        print("✅ Created 'notifications' table")
    except sqlite3.OperationalError as e:
        print(f"⚠️  {e}")
    conn.commit()
    conn.close()
    print("🎉 Migration complete!")

if __name__ == "__main__":
    migrate()
