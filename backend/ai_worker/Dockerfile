# ai_worker/Dockerfile — Image Docker pour le worker IA EcoRewind
# ================================================================
# Build : docker build -f ai_worker/Dockerfile -t ecorewind-ai-worker .
# Run   : docker run --env-file .env ecorewind-ai-worker

FROM python:3.11-slim

WORKDIR /app

# Dépendances système (pour Pillow, psycopg2, torch)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libpq-dev \
    libffi-dev \
    && rm -rf /var/lib/apt/lists/*

# Copier et installer les requirements
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copier le code source
COPY . .

# Répertoire des uploads (partagé avec FastAPI via volume)
RUN mkdir -p /app/uploads

# Variables d'environnement par défaut
ENV AI_WORKER_POLL_INTERVAL=5
ENV AI_WORKER_BATCH_SIZE=10
ENV AI_WORKER_LOG_LEVEL=INFO
ENV PYTHONUNBUFFERED=1

# Lancement du worker
CMD ["python", "-m", "ai_worker.worker"]
