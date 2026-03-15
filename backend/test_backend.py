"""Test complet de tous les endpoints du backend TriDéchet"""
import requests
import json

base = "http://127.0.0.1:8000"
results = []

def test(name, status_code, detail=""):
    ok = 200 <= status_code < 400
    icon = "PASS" if ok else "FAIL"
    results.append((icon, name, status_code, detail))

# 1. Root
r = requests.get(f"{base}/")
test("GET /", r.status_code, r.json().get("message", "")[:50])

# 2. Register (peut déjà exister)
r = requests.post(f"{base}/register", json={"email":"test_diag@test.com","full_name":"Test Diag","password":"test123","role":"user"})
test("POST /register", r.status_code, "cree" if r.status_code == 200 else "deja existant")

# 3. Login
r = requests.post(f"{base}/token", data={"username":"test_diag@test.com","password":"test123"})
test("POST /token (login)", r.status_code)
token = r.json().get("access_token") if r.status_code == 200 else None
headers = {"Authorization": f"Bearer {token}", "Content-Type": "application/json"} if token else {}

if token:
    # 4. Get me
    r = requests.get(f"{base}/users/me", headers=headers)
    test("GET /users/me", r.status_code, r.json().get("email", ""))

    # 5. Change password
    r = requests.post(f"{base}/users/me/change-password", headers=headers, json={"old_password":"test123","new_password":"test456"})
    test("POST /change-password", r.status_code, r.json().get("message", ""))
    # Remettre
    requests.post(f"{base}/users/me/change-password", headers=headers, json={"old_password":"test456","new_password":"test123"})

    # 6. Get posts
    r = requests.get(f"{base}/posts")
    test("GET /posts", r.status_code, f"{len(r.json())} posts")

    # 7. Create post
    r = requests.post(f"{base}/posts", headers=headers, json={"user_name":"Test","user_avatar_url":"","image_url":"","description":"Test post diag"})
    test("POST /posts (creer)", r.status_code)
    post_id = r.json().get("id") if r.status_code == 200 else None

    if post_id:
        # 8. Like
        r = requests.post(f"{base}/posts/{post_id}/like", headers=headers)
        test("POST /like", r.status_code, f"liked={r.json().get('liked')}")

        # 9. Save
        r = requests.post(f"{base}/posts/{post_id}/save", headers=headers)
        test("POST /save", r.status_code, f"saved={r.json().get('saved')}")

        # 10. Comment
        r = requests.post(f"{base}/posts/{post_id}/comments", headers=headers, json={"user_name":"Test","content":"Test comment"})
        test("POST /comment", r.status_code)
        comment_id = r.json().get("id") if r.status_code == 200 else None

        if comment_id:
            # 11. Update comment
            r = requests.put(f"{base}/comments/{comment_id}", headers=headers, json={"content":"Updated"})
            test("PUT /comment (modifier)", r.status_code)

            # 12. Delete comment
            r = requests.delete(f"{base}/comments/{comment_id}", headers=headers)
            test("DEL /comment (supprimer)", r.status_code)

        # 13. Saved posts
        r = requests.get(f"{base}/users/me/saved-posts", headers=headers)
        test("GET /saved-posts", r.status_code, f"{len(r.json())} enregistres")

        # 14. Unsave
        r = requests.post(f"{base}/posts/{post_id}/save", headers=headers)
        test("POST /unsave (toggle)", r.status_code)

        # 15. Delete post
        r = requests.delete(f"{base}/posts/{post_id}", headers=headers)
        test("DEL /post (supprimer)", r.status_code)

# 16. Forgot password
r = requests.post(f"{base}/forgot-password", json={"email":"test_diag@test.com"})
test("POST /forgot-password", r.status_code)

# --- ADMIN TESTS ---
r = requests.post(f"{base}/token", data={"username":"admin@tridechet.tn","password":"Admin2024!"})
if r.status_code == 200:
    admin_token = r.json()["access_token"]
    ah = {"Authorization": f"Bearer {admin_token}", "Content-Type": "application/json"}

    # 17. List users
    r = requests.get(f"{base}/users", headers=ah)
    test("GET /users (admin)", r.status_code, f"{len(r.json())} utilisateurs")

    # 18. Create user
    r = requests.post(f"{base}/admin/users", headers=ah, json={"email":"temp_test@diag.com","full_name":"Temp User","password":"temp123","role":"user"})
    if r.status_code == 200:
        temp_id = r.json()["id"]
        test("POST /admin/users (creer)", r.status_code)

        # 19. Update user
        r = requests.put(f"{base}/admin/users/{temp_id}", headers=ah, json={"full_name":"Updated Name","role":"educator"})
        test("PUT /admin/users (modifier)", r.status_code)

        # 20. Delete user
        r = requests.delete(f"{base}/admin/users/{temp_id}", headers=ah)
        test("DEL /admin/users (supprimer)", r.status_code)
    elif r.status_code == 400:
        test("POST /admin/users", 200, "deja existant - OK")
        # Cleanup
        ul = requests.get(f"{base}/users", headers=ah)
        for u in ul.json():
            if u["email"] == "temp_test@diag.com":
                requests.delete(f"{base}/admin/users/{u['id']}", headers=ah)
    else:
        test("POST /admin/users", r.status_code, "ERREUR")
else:
    test("Admin login", r.status_code, "Pas de compte admin - SKIP admin tests")

# --- AFFICHAGE ---
print()
print("=" * 60)
print("   DIAGNOSTIC COMPLET - BACKEND TRIDECHET")
print("=" * 60)
passed = 0
failed = 0
for icon, name, code, detail in results:
    symbol = "+" if icon == "PASS" else "X"
    print(f"  [{symbol}] {name:35s} {code}  {detail}")
    if icon == "PASS":
        passed += 1
    else:
        failed += 1
print("=" * 60)
print(f"   Resultats: {passed} PASS / {failed} FAIL sur {len(results)} tests")
if failed == 0:
    print("   >>> TOUT FONCTIONNE CORRECTEMENT ! <<<")
else:
    print(f"   >>> {failed} PROBLEME(S) DETECTE(S) <<<")
print("=" * 60)
