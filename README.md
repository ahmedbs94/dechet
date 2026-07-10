# EcoRewind ♻️

**Application mobile & web de gestion du tri des déchets en Tunisie**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter)](https://flutter.dev)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-green?logo=fastapi)](https://fastapi.tiangolo.com)
[![Python](https://img.shields.io/badge/Python-3.11-yellow?logo=python)](https://python.org)
[![SQLite](https://img.shields.io/badge/SQLite-3-lightblue?logo=sqlite)](https://sqlite.org)
[![PyTorch](https://img.shields.io/badge/PyTorch-2.x-red?logo=pytorch)](https://pytorch.org)

---

## 📱 Présentation

EcoRewind est une plateforme citoyenne qui encourage le tri sélectif des déchets à travers :

- 🗺️ **Carte interactive** des points de collecte vérifiés (plastique, verre, batteries, compost…)
- 📸 **Feed social** pour partager ses actions de tri avec la communauté
- 🤖 **Modération IA** automatique multicouche (Text CNN + ResNet18 + NudeNet)
- 🔔 **Notifications** en temps réel (likes, commentaires, saves, résultat modération)
- 🏆 **Récompenses & badges** pour motiver l'engagement citoyen
- 💬 **Témoignages** citoyens modérés par les administrateurs
- 📊 **Impact personnel** (CO₂ évité, déchets triés, équivalences arbres)
- 🔐 **Authentification sécurisée** (Email/OTP, Google, Facebook)

---

## 🏗️ Architecture

```
EcoRewind/
├── lib/                        # Application Flutter (frontend)
│   ├── screens/
│   │   ├── client/             # Interface citoyen (feed, carte, profil…)
│   │   └── admin/              # Interface administrateur
│   ├── services/
│   │   └── auth_service.dart   # API calls + gestion tokens JWT
│   ├── models/                 # Modèles de données Dart
│   ├── widgets/                # Composants réutilisables
│   └── theme/                  # Thème global (couleurs, typographie)
│
└── backend/                    # API REST Python (FastAPI)
    ├── main.py                 # Endpoints principaux
    ├── auth.py                 # JWT access + refresh tokens
    ├── db_models.py            # Modèles SQLAlchemy (ORM)
    ├── models.py               # Schémas Pydantic (validation)
    ├── database.py             # Connexion SQLite
    ├── requirements.txt        # Dépendances Python
    └── moderation_ai/          # Pipeline de modération IA
        ├── eco_moderator.py        # Orchestrateur CNN (Text + Image)
        ├── text_cnn_model.py       # Chargeur & inférence Text CNN
        ├── image_resnet_model.py   # Chargeur & inférence ResNet18
        ├── train_text_cnn.py       # Script d'entraînement Text CNN
        ├── train_image_resnet.py   # Script d'entraînement ResNet18
        ├── build_text_dataset.py   # Générateur dataset texte (9 000 ex.)
        ├── offtopic_data.py        # Données off_topic 10 catégories
        └── models/                 # Poids des modèles entraînés (.pth)
```

---

## 🤖 Pipeline de Modération IA

### Architecture multicouche

| Couche | Modèle | Rôle | Latence |
|--------|--------|------|---------|
| 0 | Règles métier (mots-clés FR/AR/EN) | Filtre rapide | < 1ms |
| 1 | **Text CNN** (EcoTextCNN custom) | Classification eco / off_topic / toxic | ~5ms |
| 2 | **ResNet18** (fine-tuné ImageNet) | Classification éco / hors-sujet / NSFW | ~20ms |
| 3 | NudeNet (CNN NSFW) | Détection contenu adulte | ~100ms |

### Décisions de modération

| Résultat | Score IA | Action |
|----------|----------|--------|
| ✅ **Publié automatiquement** | < 0.30 | Visible immédiatement dans le feed |
| ⌛ **Envoyé à l'admin** | ≥ 0.30 | File de validation — l'admin approuve ou rejette |

> **Politique prudente** : L'IA ne rejette **jamais** automatiquement une publication.
> Même un contenu NSFW ou toxique est envoyé en file d'attente admin.
> Cette approche évite les faux positifs qui supprimeraient du contenu citoyen légitime.
> Le rejet définitif est toujours une décision humaine.

### Politique de modération par catégorie

| Type de contenu | Décision IA | Décision finale |
|-----------------|-------------|------------------|
| 🌿 **Éco-pertinent** (nettoyage, recyclage, jardinage…) | `published` auto | Visible immédiatement |
| ⚽ **Hors-sujet** (sport, mode, cuisine, politique…) | `pending_review` | Admin arbitre |
| 🔔 **Toxique** (insultes, discours haineux) | `pending_review` | Admin arbitre |
| 🚫 **NSFW** (nudité, violence explicite) | `pending_review` | Admin arbitre |

### Alertes utilisateur catégorisées (10 catégories)

Chaque mise en attente affiche un message précis selon la catégorie détectée :
`Mode & Beauté`, `Sport`, `Politique`, `Finance`, `Santé`, `Éducation`,
`Divertissement`, `Cuisine`, `Voyage`, `Technologie`

### Dataset d'entraînement

- **Text CNN** : 9 000 exemples (3 000/classe) en FR/AR/EN, 2 620 mots de vocabulaire
- **ResNet18** : ~1 400 images (eco / off_topic / nsfw)
- **Accuracy** : Text CNN ~100% (val, 3 classes) | ResNet18 ~92.2%

---

## 🚀 Installation & Lancement

### Prérequis

- [Flutter SDK](https://flutter.dev/docs/get-started/install) ≥ 3.0
- [Python](https://python.org) ≥ 3.11
- Git

---

### 1. Backend (FastAPI)

```bash
cd backend

# Créer et activer l'environnement virtuel
python -m venv venv
venv\Scripts\activate          # Windows
# source venv/bin/activate     # Linux/macOS

# Installer les dépendances
pip install -r requirements.txt

# Configurer les variables d'environnement
cp .env.example .env
# Éditer .env : SECRET_KEY, REFRESH_SECRET_KEY, etc.

# (Optionnel) Ré-entraîner les modèles IA
python -X utf8 moderation_ai/build_text_dataset.py
python -X utf8 moderation_ai/train_text_cnn.py
python -X utf8 moderation_ai/train_image_resnet.py

# Lancer le serveur de développement
python -m uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

L'API sera disponible sur : `http://localhost:8000`  
Documentation interactive : `http://localhost:8000/docs`

---

### 2. Frontend (Flutter)

```bash
# Installer les dépendances Flutter
flutter pub get

# Configurer l'URL du backend
# lib/constants.dart → ApiConstants.baseUrl

# Lancer sur navigateur web
flutter run -d chrome

# Construire pour le web
flutter build web
```

---

## 🔑 Variables d'environnement

Créer `backend/.env` à partir de `backend/.env.example` :

```env
SECRET_KEY=your_super_secret_jwt_key_here
REFRESH_SECRET_KEY=your_refresh_secret_key_here
GOOGLE_CLIENT_ID=your_google_client_id
```

> ⚠️ Ne jamais committer le fichier `.env` ni la base de données `sql_app.db`

---

## 📡 API — Endpoints principaux

| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `POST` | `/token` | Connexion (retourne access + refresh token) |
| `POST` | `/token/refresh` | Renouvellement du token d'accès |
| `POST` | `/register` | Inscription citizen |
| `GET` | `/posts/feed` | Feed social paginé |
| `POST` | `/posts` | Créer une publication (modération IA auto) |
| `POST` | `/upload` | Upload image (compression auto) |
| `GET` | `/collection-points` | Points de collecte (filtrable) |
| `GET` | `/notifications` | Notifications de l'utilisateur |
| `GET` | `/testimonials` | Témoignages approuvés |
| `GET` | `/stats` | Statistiques globales plateforme |
| `GET` | `/docs` | Documentation Swagger complète |

### Endpoints Admin
| Méthode | Endpoint | Description |
|---------|----------|-------------|
| `POST` | `/admin/collection-points` | Créer un point de collecte |
| `PUT` | `/admin/collection-points/{id}` | Modifier un point |
| `DELETE` | `/admin/collection-points/{id}` | Supprimer un point |
| `GET` | `/admin/moderation/pending` | File de publications en attente |
| `PUT` | `/admin/moderation/{id}/approve` | Approuver une publication |
| `PUT` | `/admin/moderation/{id}/reject` | Rejeter une publication |
| `PUT` | `/admin/testimonials/{id}/approve` | Approuver un témoignage |
| `PUT` | `/admin/testimonials/{id}/reject` | Rejeter un témoignage |

---

## 🔒 Sécurité

- **Access Token** JWT — durée de vie : **1 heure**
- **Refresh Token** JWT — durée de vie : **30 jours** (rotation automatique)
- Authentification sociale : Google OAuth2 + Facebook Auth
- Hachage des mots de passe : `bcrypt`
- Variables sensibles isolées dans `.env` (jamais committées)

---

## 🌍 Fonctionnalités avancées

- **Modération IA multicouche** : Text CNN + ResNet18 + NudeNet en < 30ms
- **Alertes catégorisées** : message précis selon la catégorie détectée (10 catégories)
- **File admin** : publications hors-sujet envoyées en validation humaine
- **Compression d'images** automatique (Pillow) : resize 1200px + JPEG qualité 80
- **Cache HTTP** : `Cache-Control` + `ETag` sur les endpoints feed
- **Pagination** : scroll infini (15 posts/page) côté client
- **Notifications** : générées automatiquement pour likes, commentaires, saves, modération
- **QR Code** : identifiant unique généré à l'inscription (UUID4)
- **Auto-refresh token** : renouvellement transparent en cas de 401

---

## 🧑‍💻 Rôles utilisateurs

| Rôle | Accès |
|------|-------|
| `user` | Feed, carte, profil, témoignages |
| `admin` | Tableau de bord complet, file de modération, gestion utilisateurs, points de collecte |
| `educator` | Contenu éducatif |
| `collector` | Gestion des collectes |

---

## 📦 Stack technique

| Composant | Technologie |
|-----------|-------------|
| Frontend | Flutter 3.x (Web + Mobile) |
| Backend | FastAPI (Python 3.11) |
| Base de données | SQLite (dev) |
| ORM | SQLAlchemy |
| Auth | JWT (python-jose) + bcrypt |
| Maps | flutter_map + OpenStreetMap |
| Auth sociale | Google Sign-In + Facebook Auth |
| Images | Pillow (compression serveur) |
| IA Texte | Text CNN custom (PyTorch) — 731K paramètres |
| IA Images | ResNet18 fine-tuné (PyTorch) |
| IA NSFW | NudeNet (CNN) |
| IA Toxic | Detoxify (BERT multilingue) |

---

## 🤝 Contribution

1. Fork le projet
2. Créer une branche : `git checkout -b feature/ma-fonctionnalite`
3. Committer : `git commit -m "feat: description"`
4. Push : `git push origin feature/ma-fonctionnalite`
5. Ouvrir une Pull Request

---

## 📄 Licence

Ce projet est développé dans le cadre d'un projet académique.

---

*Développé avec ❤️ pour une Tunisie plus verte* 🌱
