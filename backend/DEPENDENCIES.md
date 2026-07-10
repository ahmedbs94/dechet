# 📦 Gestion des dépendances — EcoRewind Backend

## Vue d'ensemble

Les dépendances sont **séparées en deux fichiers** pour permettre un déploiement
léger de l'API sans embarquer les modèles IA volumineux.

```
backend/
├── requirements.txt        ← API FastAPI (core, léger)
├── requirements-ai.txt     ← Worker IA (optionnel, lourd)
└── ai_worker/
    ├── Dockerfile          ← Image Docker du worker IA
    └── worker.py           ← Processus de modération autonome
```

---

## Scénarios d'installation

### 🟢 Scénario 1 — API seule (développement / machine de jury)

```bash
cd backend
pip install -r requirements.txt
uvicorn main:app --reload
```

**Caractéristiques :**
- Installation rapide (~2 min)
- RAM : ~200 Mo
- Pas de modèles IA téléchargés
- La modération des posts fonctionne en **mode règles basiques** (fallback)
  - Filtrage par mots-clés interdits
  - Les posts valides sont publiés, les posts avec mots interdits sont rejetés

---

### 🟡 Scénario 2 — API + Worker IA (machine locale avec ressources)

```bash
cd backend

# 1. Installer l'API core
pip install -r requirements.txt

# 2. Installer les dépendances IA (+ téléchargement des modèles au 1er run)
pip install -r requirements-ai.txt

# 3. Démarrer l'API
uvicorn main:app --reload

# 4. Dans un terminal séparé, démarrer le worker IA
python -m ai_worker.worker
```

**Caractéristiques :**
- Installation longue (~10–20 min selon la connexion)
- RAM : 4–6 Go (modèles en mémoire)
- Espace disque : ~3–5 Go (modèles HuggingFace)
- Modération IA complète : BERT + CNN + XLM-RoBERTa + CLIP

---

### 🔵 Scénario 3 — Déploiement Docker (production / démo robuste)

```bash
cd backend

# PostgreSQL uniquement (sans worker IA)
docker compose up -d

# PostgreSQL + Worker IA (démarrage lent au 1er build)
docker compose --profile ai up -d

# Voir les logs du worker
docker compose logs -f ai_worker
```

**Notes Docker :**
- Le worker IA est dans un **profil Docker séparé** (`--profile ai`)
  → Il ne démarre pas par défaut, seulement quand demandé explicitement
- Les modèles HuggingFace sont mis en cache dans un **volume persistant**
  → Le re-démarrage du conteneur ne re-télécharge pas les modèles
- Limite mémoire configurée à 6 Go dans `docker-compose.yml`

---

## Tableau récapitulatif des dépendances

### `requirements.txt` — Core API (obligatoire)

| Package | Version | Rôle |
|---------|---------|------|
| fastapi | latest | Framework web |
| uvicorn | latest | Serveur ASGI |
| sqlalchemy | latest | ORM base de données |
| alembic | ≥1.13.0 | Migrations DB |
| psycopg2-binary | latest | Connecteur PostgreSQL |
| python-jose | latest | JWT tokens |
| passlib[bcrypt] | latest | Hashage mots de passe |
| bcrypt | 4.0.1 | Contrainte de version stable |
| pyotp | latest | Authentification 2FA (TOTP) |
| firebase-admin | latest | Push notifications FCM |
| google-auth | latest | Auth Google OAuth2 |
| pydantic | latest | Validation des données |
| pydantic-settings | latest | Configuration .env |
| email-validator | latest | Validation emails |
| httpx | latest | Requêtes HTTP async |
| python-multipart | latest | Upload fichiers |
| Pillow | latest | Traitement images |
| fastapi-mail | latest | Envoi emails |
| python-dotenv | latest | Chargement .env |

**Taille estimée** : ~150 Mo | **Temps d'installation** : ~2–3 min

---

### `requirements-ai.txt` — Worker IA (optionnel)

| Package | Version | Rôle | Taille approx. |
|---------|---------|------|----------------|
| detoxify | ≥0.5.2 | Détection toxicité texte (BERT) | ~500 Mo |
| nudenet | ≥3.4.2 | Classification images NSFW (CNN) | ~50 Mo |
| transformers | ≥4.40.0 | HuggingFace NLP (XLM-RoBERTa, CLIP) | ~1 Go |
| torch | ≥2.1.0 | Framework Deep Learning | ~2 Go |
| torchvision | ≥0.16.0 | Vision par ordinateur (PyTorch) | ~200 Mo |
| sentencepiece | ≥0.1.99 | Tokenizer XLM-RoBERTa | ~5 Mo |
| protobuf | ≥4.0.0 | Sérialisation (requis par SentencePiece) | ~1 Mo |
| tiktoken | ≥0.5.0 | Fallback tokenizer BPE | ~5 Mo |
| pandas | ≥1.5.0 | Manipulation données (CNN custom) | ~30 Mo |
| scikit-learn | ≥1.3.0 | ML classique | ~30 Mo |
| gensim | ≥4.3.0 | FastText / Word2Vec embeddings | ~200 Mo |

**Taille estimée** : ~3–5 Go | **Temps d'installation** : ~10–20 min

> ⚠️ `icrawler` (Bing Image Crawler) est commenté dans `requirements-ai.txt`.
> Il n'est utile **que pour ré-entraîner les modèles**, pas pour la production.

---

## Architecture de modération (flux unifié)

```
┌──────────────────────────────────────────────────────────────────────────
│  PIPELINE PRINCIPAL (toujours actif — routers/posts.py)               │
└─────────────────────────────────────────────────────────────────────────┘

Utilisateur
    ↓
  POST /posts
    ↓
  INSERT post (status='pending_review')  ←── L'utilisateur voit la confirmation
    ↓
  BackgroundTask: _run_ai_moderation()
    ↓
  Si modèles IA installés         Si modèles NON installés
  ├─ TextCNN + ResNet18             └─ Règles basiques (mots-clés)
  ├─ NudeNet (NSFW)
  └─ Detoxify (toxicité)
    ↓
  Décision :
  ├─ score < 0.30 → status = 'published'      (visible immédiatement)
  └─ score ≥ 0.30 → status = 'pending_review'  (admin valide manuellement)

  Notification envoyée à l'utilisateur selon résultat


┌──────────────────────────────────────────────────────────────────────────
│  WORKER DE RATTRAPAGE (optionnel — ai_worker/worker.py)                │
└─────────────────────────────────────────────────────────────────────────┘

Polling DB toutes les N secondes
    ↓
  SELECT posts WHERE status='pending_review'
                   AND moderated_at IS NULL    ←─ jamais traité
                   AND created_at < NOW()-10min ←─ BackgroundTask probablement échouée
    ↓
  Même pipeline de décision
    ↓
  UPDATE post (status, moderation_score, moderated_at...)
```

**Statuts valides dans ce projet :**

| Statut | Description |
|--------|-------------|
| `pending_review` | Statut initial à la création. Également utilisé pour les posts signalés par l'IA en attente de décision admin. |
| `published` | Post approuvé (par l'IA ou par l'admin). Visible dans le fil. |
| `rejected` | Post refusé par l'admin manuellement. Jamais attribué automatiquement. |

> ⚠️  Le statut `pending_ai` n'existe pas dans ce projet.

---

## FAQ

**Q : Est-ce que l'API fonctionne sans le worker IA ?**
> Oui. Sans le worker IA, les posts sont modérés par des règles basiques
> (filtrage par mots-clés). Aucune fonctionnalité métier n'est bloquée.

**Q : Est-ce que je dois démarrer le worker IA pour la démo du jury ?**
> Non. Si la machine du jury est limitée en RAM, n'installez pas
> `requirements-ai.txt`. La modération basique est suffisante pour démontrer
> le flux complet (post → modération → publication).

**Q : Comment savoir si le worker IA est actif ?**
> Le worker log dans la console : `✅ Modèles IA chargés avec succès`
> Si les modèles ne sont pas dispo : `⚠️ Modèles IA non disponibles — mode règles basiques actif`

**Q : Les modèles IA sont-ils téléchargés à chaque démarrage ?**
> Non. HuggingFace les cache dans `~/.cache/huggingface` (local) ou dans
> le volume Docker `ai_models` (Docker). Le 1er démarrage est lent, les
> suivants sont instantanés.
