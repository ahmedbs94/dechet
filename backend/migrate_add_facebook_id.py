import sqlite3
import os

DB_NAME = 'sql_app.db'

def main():
    db_path = os.path.join(os.path.dirname(__file__), DB_NAME)
    if not os.path.exists(db_path):
        print(f"Base de données introuvable: {db_path}")
        return

    conn = sqlite3.connect(db_path)
    cur = conn.cursor()

    cur.execute("PRAGMA table_info(users)")
    cols = [r[1] for r in cur.fetchall()]
    print('Colonnes actuelles:', cols)

    if 'facebook_id' in cols:
        print('La colonne facebook_id existe déjà. Rien à faire.')
    else:
        print('Ajout de la colonne facebook_id à la table users...')
        try:
            cur.execute("ALTER TABLE users ADD COLUMN facebook_id TEXT")
            conn.commit()
            print('Colonne ajoutée avec succès.')
        except Exception as e:
            print('Erreur lors de l ajout de la colonne:', e)
    conn.close()

if __name__ == '__main__':
    main()
