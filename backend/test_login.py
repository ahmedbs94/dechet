import requests
import json

BASE_URL = "http://localhost:8000"

def test_login(email, password, expected_role):
    """Test de connexion pour un utilisateur"""
    print(f"\n{'='*60}")
    print(f"Test de connexion pour: {email}")
    print(f"Rôle attendu: {expected_role}")
    print(f"{'='*60}")
    
    # Préparer les données de connexion (OAuth2 format)
    data = {
        "username": email,  # OAuth2 utilise "username" même pour l'email
        "password": password
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/token",
            data=data,
            headers={"Content-Type": "application/x-www-form-urlencoded"}
        )
        
        if response.status_code == 200:
            result = response.json()
            print(f"✓ SUCCÈS - Connexion réussie!")
            print(f"  - Token: {result['access_token'][:50]}...")
            print(f"  - Type: {result['token_type']}")
            print(f"  - Rôle: {result['role']}")
            
            if result['role'] == expected_role:
                print(f"  ✓ Le rôle correspond!")
            else:
                print(f"  ✗ ERREUR: Rôle attendu '{expected_role}', reçu '{result['role']}'")
            
            return True, result
        else:
            print(f"✗ ÉCHEC - Code: {response.status_code}")
            print(f"  Erreur: {response.json()}")
            return False, None
            
    except Exception as e:
        print(f"✗ ERREUR - Exception: {e}")
        return False, None

def test_register_normal_user():
    """Test de création de compte pour utilisateur normal"""
    print(f"\n{'='*60}")
    print(f"Test de création de compte utilisateur normal")
    print(f"{'='*60}")
    
    import random
    random_num = random.randint(1000, 9999)
    
    user_data = {
        "email": f"user_test_{random_num}@tridechet.tn",
        "full_name": "Utilisateur Normal Test",
        "role": "user",
        "password": "User123!"
    }
    
    try:
        response = requests.post(
            f"{BASE_URL}/register",
            json=user_data
        )
        
        if response.status_code == 200:
            result = response.json()
            print(f"✓ SUCCÈS - Compte créé!")
            print(f"  - ID: {result['id']}")
            print(f"  - Email: {result['email']}")
            print(f"  - Nom: {result['full_name']}")
            print(f"  - Rôle: {result['role']}")
            print(f"  - Actif: {result['is_active']}")
            
            # Test de connexion immédiate
            print(f"\n  >> Test de connexion automatique...")
            success, token_data = test_login(
                user_data['email'],
                user_data['password'],
                user_data['role']
            )
            
            return True, result
        else:
            print(f"✗ ÉCHEC - Code: {response.status_code}")
            print(f"  Erreur: {response.json()}")
            return False, None
            
    except Exception as e:
        print(f"✗ ERREUR - Exception: {e}")
        return False, None

if __name__ == "__main__":
    print(f"\n{'#'*60}")
    print(f"# TEST COMPLET DU SYSTÈME D'AUTHENTIFICATION")
    print(f"{'#'*60}")
    
    # Liste des utilisateurs créés via la commande admin
    admin_users = [
        ("admin@tridechet.tn", "Admin123!", "admin"),
        ("educateur@tridechet.tn", "Educ123!", "educator"),
        ("pointmanager@tridechet.tn", "Point123!", "pointManager"),
        ("collecteur@tridechet.tn", "Collect123!", "collector"),
        ("intercommunalite@tridechet.tn", "Mairie123!", "intercommunality")
    ]
    
    # Test de connexion pour chaque utilisateur créé par l'admin
    print(f"\n{'#'*60}")
    print(f"# PARTIE 1: Test des comptes créés par l'admin")
    print(f"{'#'*60}")
    
    results = []
    for email, password, role in admin_users:
        success, data = test_login(email, password, role)
        results.append((email, role, success))
    
    # Test de création et connexion pour utilisateur normal
    print(f"\n{'#'*60}")
    print(f"# PARTIE 2: Test création compte utilisateur normal")
    print(f"{'#'*60}")
    
    normal_user_success, normal_user_data = test_register_normal_user()
    
    # Résumé final
    print(f"\n\n{'#'*60}")
    print(f"# RÉSUMÉ DES TESTS")
    print(f"{'#'*60}\n")
    
    print("Comptes créés par l'admin:")
    for email, role, success in results:
        status = "✓ SUCCÈS" if success else "✗ ÉCHEC"
        print(f"  {status} - {role:20s} ({email})")
    
    print(f"\nCréation compte utilisateur normal:")
    status = "✓ SUCCÈS" if normal_user_success else "✗ ÉCHEC"
    print(f"  {status} - Inscription et connexion directe")
    
    # Vérification finale
    all_success = all(r[2] for r in results) and normal_user_success
    
    print(f"\n{'='*60}")
    if all_success:
        print("✓ TOUS LES TESTS ONT RÉUSSI!")
    else:
        print("✗ CERTAINS TESTS ONT ÉCHOUÉ")
    print(f"{'='*60}\n")
