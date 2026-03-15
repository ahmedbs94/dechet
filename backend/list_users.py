from sqlalchemy.orm import Session
from database import SessionLocal
import db_models

def list_users():
    db = SessionLocal()
    try:
        users = db.query(db_models.User).all()
        print(f"\n=== Utilisateurs dans la base de données ({len(users)} total) ===\n")
        
        if not users:
            print("Aucun utilisateur trouvé dans la base de données.\n")
            return
        
        for user in users:
            print(f"ID: {user.id}")
            print(f"Email: {user.email}")
            print(f"Nom: {user.full_name}")
            print(f"Rôle: {user.role}")
            print(f"Actif: {user.is_active}")
            print(f"Google ID: {user.google_id or 'N/A'}")
            print("-" * 50)
    
    except Exception as e:
        print(f"Erreur lors de la récupération des utilisateurs : {e}")
    finally:
        db.close()

if __name__ == "__main__":
    list_users()
