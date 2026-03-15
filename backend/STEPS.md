# Description des Étapes de Mise en Place du Backend (FastAPI + Google Auth)

Ce document décrit les étapes suivies pour mettre en place le backend de l'application TriDéchet.

## 1. Initialisation de l'environnement
Nous avons créé un répertoire `backend/` dédié pour isoler la logique serveur du code Flutter.

## 2. Définition des dépendances (`requirements.txt`)
Nous avons listé les bibliothèques nécessaires :
- **FastAPI** : Le framework web.
- **Uvicorn** : Le serveur ASGI pour exécuter FastAPI.
- **Python-jose** : Pour la gestion des JSON Web Tokens (JWT).
- **Passlib** : Pour le hachage sécurisé des mots de passe (BCrypt).
- **Google-auth** : Pour vérifier les jetons d'authentification Google.
- **Pydantic** : Pour la validation des données.

## 3. Création des Modèles de Données (`models.py` et `db_models.py`)
- `models.py` : Schémas Pydantic pour la validation des données API.
- `db_models.py` : Modèles SQLAlchemy pour la structure des tables dans la base de données.

## 4. Configuration de la Base de Données (`database.py`)
Mise en place de **SQLite** :
- Création de l'engine SQLAlchemy.
- Configuration de la session locale.
- Définition de la dépendance `get_db` pour injecter la base de données dans les routes.

## 4. Logique d'Authentification (`auth.py`)
Mise en place des utilitaires de sécurité :
- Hachage des mots de passe.
- Vérification des mots de passe fournis lors du login.
- Création de jetons JWT avec une date d'expiration.

## 5. Développement des Endpoints (`main.py`)
Implémentation des routes API :
- **`POST /register`** : Création d'un nouveau compte utilisateur.
- **`POST /token`** : Connexion classique (email/password) retournant un JWT.
- **`POST /auth/google`** : Réception d'un jeton d'id Google, vérification auprès des serveurs Google, et retour d'un JWT propre à notre application.

## Prochaines Étapes suggérées :
1. **Lancement du serveur** :
   ```bash
   cd backend
   .\venv\Scripts\activate
   uvicorn main:app --reload
   ```
2. **Intégration d'une base de données** : Remplacer `users_db` (mémoire vive) par PostgreSQL ou MongoDB.
3. **Configuration Google Cloud** : Créer un projet sur [Google Cloud Console](https://console.cloud.google.com/) pour obtenir un `CLIENT_ID`.
4. **Tests de connexion** : Utiliser l'interface Swagger automatique de FastAPI à l'adresse `http://localhost:8000/docs`.
