import sqlite3

conn = sqlite3.connect('sql_app.db')
cursor = conn.cursor()
cursor.execute('SELECT id, email, full_name, role, is_active, is_verified, google_id, facebook_id FROM users')
rows = cursor.fetchall()

print(f"\n{'='*80}")
print(f"  UTILISATEURS DANS LA BASE DE DONNEES ({len(rows)} total)")
print(f"{'='*80}\n")

for r in rows:
    print(f"  ID:        {r[0]}")
    print(f"  Email:     {r[1]}")
    print(f"  Nom:       {r[2]}")
    print(f"  Role:      {r[3]}")
    print(f"  Actif:     {r[4]}")
    print(f"  Verifie:   {r[5]}")
    print(f"  Google ID: {r[6]}")
    print(f"  FB ID:     {r[7]}")
    print(f"  {'-'*40}")

conn.close()
