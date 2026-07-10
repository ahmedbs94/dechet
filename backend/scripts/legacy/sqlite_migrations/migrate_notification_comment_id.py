import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""
Migration: Add comment_id column to notifications table.
Run this once to update the existing database.
"""
import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sql_app.db")

def migrate():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()
    
    # Check if column already exists
    cursor.execute("PRAGMA table_info(notifications)")
    columns = [col[1] for col in cursor.fetchall()]
    
    if "comment_id" not in columns:
        print("Adding 'comment_id' column to notifications table...")
        cursor.execute("ALTER TABLE notifications ADD COLUMN comment_id INTEGER")
        conn.commit()
        print("✅ Migration successful: comment_id column added.")
    else:
        print("ℹ️  Column 'comment_id' already exists. No migration needed.")
    
    conn.close()

if __name__ == "__main__":
    migrate()
