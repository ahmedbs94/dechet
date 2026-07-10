import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""
Migration: Add unique qr_code column to users table.
Each existing user gets a unique UUID-based QR token.
Run this once: python migrate_qr_code.py
"""
import sqlite3
import uuid
import os

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "sql_app.db")

def generate_unique_qr_token():
    return f"TRIDECHET-{uuid.uuid4()}"

def migrate():
    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Check if column already exists
    cursor.execute("PRAGMA table_info(users)")
    columns = [col[1] for col in cursor.fetchall()]

    if "qr_code" in columns:
        print("✅ La colonne qr_code existe déjà.")
        # Check for any NULL or duplicate values and fix them
        cursor.execute("SELECT id FROM users WHERE qr_code IS NULL OR qr_code = ''")
        null_users = cursor.fetchall()
        if null_users:
            print(f"⚠️  {len(null_users)} utilisateur(s) sans QR code. Attribution en cours...")
            for (user_id,) in null_users:
                qr = generate_unique_qr_token()
                cursor.execute("UPDATE users SET qr_code = ? WHERE id = ?", (qr, user_id))
                print(f"   → User #{user_id}: {qr}")
            conn.commit()
            print("✅ Tous les utilisateurs ont maintenant un QR code unique.")
        else:
            print("✅ Tous les utilisateurs ont déjà un QR code.")
    else:
        print("📝 Ajout de la colonne qr_code à la table users...")
        # Add column (SQLite doesn't support NOT NULL + UNIQUE in ALTER TABLE easily)
        cursor.execute("ALTER TABLE users ADD COLUMN qr_code TEXT")
        conn.commit()

        # Generate unique QR codes for all existing users
        cursor.execute("SELECT id FROM users")
        users = cursor.fetchall()
        print(f"🔑 Génération de QR codes uniques pour {len(users)} utilisateur(s)...")

        for (user_id,) in users:
            qr = generate_unique_qr_token()
            cursor.execute("UPDATE users SET qr_code = ? WHERE id = ?", (qr, user_id))
            print(f"   → User #{user_id}: {qr}")

        conn.commit()
        print("✅ Migration terminée avec succès!")

    # Display summary
    print("\n📊 Résumé des QR codes:")
    print("-" * 70)
    cursor.execute("SELECT id, full_name, email, qr_code FROM users ORDER BY id")
    for row in cursor.fetchall():
        user_id, name, email, qr = row
        print(f"   #{user_id:3d} | {(name or 'N/A'):20s} | {email:30s} | {qr}")

    # Verify uniqueness
    cursor.execute("SELECT qr_code, COUNT(*) as cnt FROM users GROUP BY qr_code HAVING cnt > 1")
    duplicates = cursor.fetchall()
    if duplicates:
        print(f"\n❌ ATTENTION: {len(duplicates)} QR code(s) en double détecté(s)!")
        for qr, cnt in duplicates:
            print(f"   → {qr} (x{cnt})")
    else:
        print(f"\n✅ Vérification d'unicité: tous les QR codes sont uniques.")

    conn.close()

if __name__ == "__main__":
    migrate()
