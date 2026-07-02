import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""Verifie les routes API principales."""
import urllib.request
import urllib.error

base = "http://127.0.0.1:8000"
paths = [
    "/",
    "/docs",
    "/users/me",
    "/collection-points/",
    "/collection-points",
    "/posts/",
    "/posts",
    "/notifications/",
    "/notifications",
    "/qr/scan",
    "/quiz/",
    "/educator-videos/",
    "/testimonials/",
    "/stats",
]

print("Routes API EcoRewind :")
print("-" * 50)
for p in paths:
    try:
        r = urllib.request.urlopen(base + p)
        print(f"  {r.status} {p}")
    except urllib.error.HTTPError as e:
        print(f"  {e.code} {p}")
    except Exception as e:
        print(f"  ERR {p} : {e}")
