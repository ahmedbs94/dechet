"""
Migration: Add is_verified column to users table and create otp_codes table
"""
import sqlite3

DB_PATH = "sql_app.db"

def migrate():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # 1. Add is_verified column to users table
    try:
        cursor.execute("ALTER TABLE users ADD COLUMN is_verified BOOLEAN DEFAULT 1")
        print("✅ Added 'is_verified' column to users table (existing users set as verified)")
    except sqlite3.OperationalError as e:
        if "duplicate column" in str(e).lower():
            print("ℹ️  Column 'is_verified' already exists")
        else:
            print(f"⚠️  Error adding is_verified: {e}")

    # 2. Create otp_codes table
    try:
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS otp_codes (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                identifier VARCHAR NOT NULL,
                code VARCHAR NOT NULL,
                purpose VARCHAR DEFAULT 'register',
                created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
                expires_at DATETIME NOT NULL,
                is_used BOOLEAN DEFAULT 0
            )
        """)
        cursor.execute("CREATE INDEX IF NOT EXISTS idx_otp_identifier ON otp_codes(identifier)")
        print("✅ Created 'otp_codes' table")
    except sqlite3.OperationalError as e:
        print(f"⚠️  Error creating otp_codes table: {e}")

    conn.commit()
    conn.close()
    print("\n🎉 Migration complete!")

if __name__ == "__main__":
    migrate()
