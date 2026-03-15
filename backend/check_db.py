import sqlite3

# Connexion à la base de données
conn = sqlite3.connect('sql_app.db')
cursor = conn.cursor()

# Récupérer tous les utilisateurs
cursor.execute("SELECT id, email, full_name, role, is_active FROM users")
users = cursor.fetchall()

print(f"\n=== Utilisateurs dans la base de données ({len(users)} total) ===\n")

if not users:
    print("Aucun utilisateur trouvé dans la base de données.\n")
else:
    for user in users:
        print(f"ID: {user[0]}")
        print(f"Email: {user[1]}")
        print(f"Nom: {user[2]}")
        print(f"Rôle: {user[3]}")
        print(f"Actif: {user[4]}")
        print("-" * 50)

conn.close()
