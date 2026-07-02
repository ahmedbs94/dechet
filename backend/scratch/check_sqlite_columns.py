import sqlite3
import os

db_path = "sql_app.db"
if os.path.exists(db_path):
    conn = sqlite3.connect(db_path)
    cursor = conn.cursor()
    cursor.execute("PRAGMA table_info(users)")
    cols = cursor.fetchall()
    print("SQLite columns in 'users':")
    for col in cols:
        print(f" - {col[1]} ({col[2]})")
    conn.close()
else:
    print("sql_app.db does not exist.")
