import sys
import getpass
from sqlalchemy.orm import Session
from database import SessionLocal, engine
import db_models
from auth import get_password_hash

def create_user():
    print("--- Création d'un utilisateur (Admin/Staff) ---")
    email = input("Email : ").strip()
    full_name = input("Nom complet : ").strip()
    print("Rôles disponibles: user, admin, educator, intercommunality, pointManager, collector")
    role = input("Rôle (par défaut 'admin') : ").strip() or "admin"
    password = getpass.getpass("Mot de passe : ")
    confirm_password = getpass.getpass("Confirmez le mot de passe : ")

    if password != confirm_password:
        print("Erreur : Les mots de passe ne correspondent pas.")
        return

    db = SessionLocal()
    try:
        # Vérifier si l'utilisateur existe déjà
        db_user = db.query(db_models.User).filter(db_models.User.email == email).first()
        if db_user:
            print(f"Erreur : L'utilisateur avec l'email {email} existe déjà.")
            return

        # Créer l'utilisateur
        hashed_password = get_password_hash(password)
        new_user = db_models.User(
            email=email,
            full_name=full_name,
            hashed_password=hashed_password,
            role=role,
            is_active=True
        )
        
        db.add(new_user)
        db.commit()
        db.refresh(new_user)
        
        print(f"\nSuccès ! L'utilisateur {full_name} ({email}) a été créé.")
        print("Vous pouvez maintenant vous connecter sur l'interface Admin avec ces identifiants.")

    except Exception as e:
        print(f"Une erreur est survenue : {e}")
        db.rollback()
    finally:
        db.close()

if __name__ == "__main__":
    create_user()
