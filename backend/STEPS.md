# EcoRewind Backend — État & Documentation

## 🚀 Démarrage rapide

```bash
cd backend
.\venv\Scripts\activate
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

> Les modèles IA se chargent automatiquement au démarrage (~15s), de façon invisible pour les utilisateurs.

---

## Architecture générale

```
backend/
├── main.py                    ← FastAPI app + startup AI pre-load
├── routers/
│   ├── posts.py               ← Publications (modération IA intégrée)
│   ├── auth.py                ← Auth JWT + Google OAuth
│   ├── users.py               ← Profils utilisateurs
│   ├── notifications.py       ← Notifications push
│   ├── collection_points.py   ← Points de collecte
│   ├── community.py           ← Témoignages & propositions
│   └── moderation.py          ← Dashboard admin modération
├── services/
│   └── ai_moderator.py        ← Couche règles + Detoxify (BERT)
├── moderation_ai/
│   ├── eco_moderator.py       ← Pipeline CNN complet (Text CNN + ResNet18)
│   ├── text_cnn_model.py      ← Architecture EcoTextCNN + inférence
│   ├── image_resnet_model.py  ← ResNet18 fine-tuné + inférence
│   ├── train_text_cnn.py      ← Script d'entraînement Text CNN
│   ├── train_image_resnet.py  ← Script d'entraînement ResNet18
│   ├── build_text_dataset.py  ← Générateur dataset texte (FR/AR/EN)
│   ├── test_cnn.py            ← Tests Text CNN
│   └── models/
│       ├── eco_text_cnn.pth   ← Modèle Text CNN entraîné (1.2 MB)
│       ├── eco_image_resnet.pth ← ResNet18 fine-tuné (43 MB)
│       └── vocab.pkl          ← Vocabulaire Text CNN
└── requirements.txt
```

---

## Pipeline de modération IA

### Flux de décision pour chaque publication

```
POST /posts
    │
    ▼
┌─────────────────────────────────────────────────────────┐
│  COUCHE 0 : Règles FR/AR/EN                 < 1ms       │
│  Mots toxiques, anti-env, hors-sujet, vide              │
└─────────────┬───────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────┐
│  COUCHE 1 : Detoxify (BERT multilingual)    ~50ms       │
│  Détection toxicité (score 0–1)                         │
└─────────────┬───────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────┐
│  COUCHE 2 : EcoTextCNN (custom)             ~5ms        │
│  eco | off_topic | toxic  — FR/AR/EN                    │
│  Confiance : 68–99%                                      │
└─────────────┬───────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────┐
│  COUCHE 3 : ResNet18 fine-tuné (custom)     ~20ms       │
│  eco | off_topic | nsfw  — analyse image                │
└─────────────┬───────────────────────────────────────────┘
              │
              ▼
┌─────────────────────────────────────────────────────────┐
│  DÉCISION DU MODÈLE IA (eco_moderator.py)               │
│  score < 0.30  → published       (approuvé)             │
│  score ≥ 0.30  → pending_review  (signalé)               │
│  score ≥ 0.65  → rejected        (verdict IA interne)    │
└─────────────────────────────────────────────────────────┘
               │
               ▾  posts.py (_run_ai_moderation)
┌─────────────────────────────────────────────────────────┐
│  DÉCISION FINALE (politique prudente)                   │
│  published      → published   (visible dans le feed)    │
│  pending_review → pending_review (file admin)           │
│  rejected       → pending_review (jamais auto-rejeté)  │
│                                                         │
│  L'admin est seul à pouvoir rejeter définitivement.    │
└─────────────────────────────────────────────────────────┘
```

### Pourquoi CLIP et XLM-RoBERTa sont désactivés

| Modèle | Taille | Chargement | Décision |
|--------|--------|------------|----------|
| CLIP ViT-B/32 | **2.4 GB** | **2–3 min** | ❌ Désactivé — remplacé par ResNet18 (43 MB) |
| XLM-RoBERTa | **1.1 GB** | **30–60s** | ❌ Désactivé — remplacé par EcoTextCNN (1.2 MB) |
| EcoTextCNN | **1.2 MB** | **< 1s** | ✅ Actif |
| ResNet18 custom | **43 MB** | **< 1s** | ✅ Actif |
| Detoxify (BERT) | **200 MB** | **~10s** | ✅ Actif |

---

## Résultats des tests

| Suite de tests | Résultat |
|---|---|
| `tests/manual_test_rules_only.py` (couche règles) | **22/22 PASS** ✅ |
| `moderation_ai/test_cnn.py` (Text CNN) | **16/16 PASS** ✅ |
| Pipeline complet `EcoCNNModerator` | **8/8 PASS** ✅ |

### Lancer les tests
```bash
# Couche règles uniquement (< 5s)
python -X utf8 tests/manual_test_rules_only.py

# Text CNN (modèle entraîné)
python -X utf8 moderation_ai/test_cnn.py
```

---

## Ré-entraîner les modèles CNN

```bash
# 1. Régénérer le dataset texte (2100 exemples FR/AR/EN)
python -X utf8 moderation_ai/build_text_dataset.py

# 2. Entraîner le Text CNN (15 epochs, ~2 min CPU)
python -X utf8 moderation_ai/train_text_cnn.py

# 3. Préparer les images et entraîner ResNet18
#    Structure attendue : moderation_ai/data/image_dataset/{train,val}/{eco,off_topic,nsfw}/
python moderation_ai/train_image_resnet.py
```

---

## Infrastructure

- **Base de données** : SQLite (`sql_app.db`)
- **Authentification** : JWT (python-jose) + Google OAuth
- **Fichiers uploadés** : `uploads/` (max 10 Mo, redimensionnés à 1200px)
- **Notifications** : Système interne (like, commentaire, modération)
- **Admin** : Dashboard de modération avec approbation/rejet manuel

---

## Dépendances clés

```
fastapi, uvicorn, sqlalchemy, pydantic
python-jose, passlib, bcrypt
torch>=2.1.0, torchvision>=0.16.0
transformers>=4.40.0
detoxify>=0.5.2
sentencepiece, protobuf, tiktoken
pandas, Pillow
```
