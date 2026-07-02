import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

import requests
r = requests.get('http://127.0.0.1:8000/collection-points')
data = r.json()
print(f'Total: {len(data)} centres')
for p in data:
    print(f"  id={p['id']} name={p['name']} types={p['types']}")
