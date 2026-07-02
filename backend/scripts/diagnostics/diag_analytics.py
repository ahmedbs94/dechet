import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

import requests, json, sys
sys.stdout.reconfigure(encoding='utf-8', errors='replace')

# Login
r = requests.post("http://127.0.0.1:8000/token",
    data={"username": "admin@tridechet.tn", "password": "admin123"})
if r.status_code != 200:
    print("Login failed:", r.text[:200])
    exit()
token = r.json()["access_token"]
H = {"Authorization": f"Bearer {token}"}

# By-status for Nabeul
r2 = requests.get("http://127.0.0.1:8000/admin/analytics/centers/by-status?city=Nabeul", headers=H)
print("=== by-status?city=Nabeul ===")
print(json.dumps(r2.json(), ensure_ascii=False, indent=2))

# By-city
r3 = requests.get("http://127.0.0.1:8000/admin/analytics/centers/by-city", headers=H)
print("\n=== by-city (Nabeul) ===")
for d in r3.json():
    if "Nabeul" in str(d.get("city", "")):
        print(json.dumps(d, ensure_ascii=False))

# All collection points in Nabeul
r4 = requests.get("http://127.0.0.1:8000/collection-points")
print("\n=== collection-points Nabeul ===")
for p in r4.json():
    addr = str(p.get("address","")).lower()
    if "nabeul" in addr or "marbella" in addr or p.get("name","").lower().find("nabeul") >= 0:
        print(f"  id={p['id']} name={p['name']} status={p['status']} addr={p['address']}")
