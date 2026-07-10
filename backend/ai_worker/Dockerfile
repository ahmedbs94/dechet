# ai_worker/Dockerfile — Image Docker pour le Worker IA EcoRewind
# ================================================================
# Ce Dockerfile est SÉPARÉ du Dockerfile principal de l'API FastAPI.
# Il installe uniquement les dépendances IA lourdes (torch, transformers…)
# sans alourdir l'image de l'API.
#
# Build :
#   docker build -f ai_worker/Dockerfile -t ecorewind-ai-worker .
#
# Run (avec fichier .env à la racine de backend/) :
#   docker run --env-file .env \
#     -v $(pwd)/uploads:/app/uploads \
#     ecorewind-ai-worker
#
# Via docker-compose (voir docker-compose.yml, bloc ai_worker) :
#   docker compose --profile ai up -d
# ================================================================

# Image de base Python slim — évite d'embarquer des outils inutiles
FROM python:3.11-slim

WORKDIR /app

# ── Dépendances système minimales ─────────────────────────────────────────────
# gcc / libpq-dev : requis pour psycopg2 (base de données)
# libgl1 / libglib2.0 : requis par OpenCV (utilisé par nudenet)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    libffi-dev \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

# ── Installation des dépendances en deux étapes (cache Docker optimal) ────────
# Étape 1 : dépendances core de l'API (changent rarement)
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Étape 2 : dépendances IA lourdes (changent rarement aussi)
COPY requirements-ai.txt .
RUN pip install --no-cache-dir -r requirements-ai.txt

# ── Copier le code source ──────────────────────────────────────────────────────
COPY . .

# ── Répertoires de travail ─────────────────────────────────────────────────────
# uploads/ : partagé avec l'API FastAPI via un volume Docker
# models/  : cache local des modèles HuggingFace (évite re-téléchargement)
RUN mkdir -p /app/uploads /app/models

# ── Variables d'environnement par défaut ──────────────────────────────────────
ENV AI_WORKER_POLL_INTERVAL=5
ENV AI_WORKER_BATCH_SIZE=10
ENV AI_WORKER_LOG_LEVEL=INFO
ENV PYTHONUNBUFFERED=1
# Cache HuggingFace dans le répertoire du conteneur
ENV TRANSFORMERS_CACHE=/app/models
ENV HF_HOME=/app/models

# ── Healthcheck : vérifie que le worker Python tourne ─────────────────────────
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD python -c "import os, sys; sys.exit(0)"

# ── Point d'entrée ────────────────────────────────────────────────────────────
CMD ["python", "-m", "ai_worker.worker"]
