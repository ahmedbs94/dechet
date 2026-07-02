import sqlite3
import os

db_path = "sql_app.db"
if os.path.exists(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    
    cursor.execute("PRAGMA table_info(users)")
    columns = [col[1] for col in cursor.fetchall()]
    
    if "mfa_enabled" not in columns:
        try:
            cursor.execute("ALTER TABLE users ADD COLUMN mfa_enabled BOOLEAN NOT NULL DEFAULT 0")
            print("Added 'mfa_enabled' to SQLite users table.")
        except Exception as e:
            print(f"Error adding mfa_enabled: {e}")
            
    if "created_at" not in columns:
        try:
            cursor.execute("ALTER TABLE users ADD COLUMN created_at DATETIME")
            cursor.execute("UPDATE users SET created_at = datetime('now') WHERE created_at IS NULL")
            print("Added and populated 'created_at' in SQLite users table.")
        except Exception as e:
            print(f"Error adding created_at: {e}")
            
    conn.commit()
    conn.close()
    print("SQLite fix completed.")
else:
    print("sql_app.db not found.")
