import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""
Migration: Add avatar_url column to users table.
Run this once to update the existing database.
"""
import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sql_app.db")

def migrate():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    cursor.execute("PRAGMA table_info(users)")
    columns = [col[1] for col in cursor.fetchall()]
    
    if "avatar_url" not in columns:
        print("Adding 'avatar_url' column to users table...")
        cursor.execute("ALTER TABLE users ADD COLUMN avatar_url TEXT")
        conn.commit()
        print("✅ Migration successful: avatar_url column added.")
    else:
        print("ℹ️  Column 'avatar_url' already exists. No migration needed.")
    
    conn.close()

if __name__ == "__main__":
    migrate()
