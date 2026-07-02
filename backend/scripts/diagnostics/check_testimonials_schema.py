import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

import sqlite3
db = sqlite3.connect('sql_app.db')
cur = db.cursor()
cur.execute("SELECT name FROM sqlite_master WHERE type='table'")
print("Tables:", [r[0] for r in cur.fetchall()])
cur.execute("PRAGMA table_info(testimonials)")
cols = cur.fetchall()
print("Testimonials columns:", cols)
db.close()
