import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

import sqlite3

conn = sqlite3.connect('sql_app.db')
tables = conn.execute("SELECT name FROM sqlite_master WHERE type='table'").fetchall()
print('Tables:', [t[0] for t in tables])

for t in tables:
    name = t[0]
    if 'collect' in name.lower() or 'point' in name.lower():
        rows = conn.execute(f'SELECT id, name, address FROM "{name}" ORDER BY id').fetchall()
        print(f'\nTable [{name}] — {len(rows)} lignes:')
        for r in rows:
            addr = (r[2] or 'NULL')[:70]
            print(f'  [{r[0]}] {r[1]} | {addr}')

conn.close()
