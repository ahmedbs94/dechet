#!/usr/bin/env bash
# migrate.sh — Scripts Alembic pour EcoRewind (Linux / macOS)
# =============================================================
# Usage : ./migrate.sh [commande]
#
#   ./migrate.sh up          → Appliquer toutes les migrations
#   ./migrate.sh down        → Revenir d'une migration en arrière
#   ./migrate.sh new "msg"   → Créer une nouvelle migration (autogenerate)
#   ./migrate.sh status      → Voir l'état des migrations
#   ./migrate.sh history     → Historique complet
#   ./migrate.sh reset       → ⚠️  Revenir à zéro (SUPPRIME TOUTES LES TABLES)

set -e

# Se placer dans le dossier backend/ (là où se trouve alembic.ini)
cd "$(dirname "$0")"

CMD="${1:-help}"

case "$CMD" in
  up)
    echo "🚀 [Alembic] Application de toutes les migrations..."
    alembic upgrade head
    ;;
  down)
    echo "⬇️  [Alembic] Retour d'une migration en arrière..."
    alembic downgrade -1
    ;;
  new)
    MSG="${2:-}"
    if [ -z "$MSG" ]; then
      echo "Usage: ./migrate.sh new \"description de la migration\""
      exit 1
    fi
    echo "✏️  [Alembic] Création d'une nouvelle migration : $MSG"
    alembic revision --autogenerate -m "$MSG"
    ;;
  status)
    echo "📍 [Alembic] État actuel des migrations :"
    alembic current
    ;;
  history)
    echo "📜 [Alembic] Historique des migrations :"
    alembic history --verbose
    ;;
  reset)
    echo ""
    echo "⚠️  ATTENTION : Cette opération va supprimer TOUTES les tables !"
    read -r -p "Tapez 'oui' pour confirmer : " CONFIRM
    if [ "$CONFIRM" = "oui" ]; then
      alembic downgrade base
      echo "✅ Base de données réinitialisée. Relancez './migrate.sh up' pour recréer."
    else
      echo "❌ Annulé."
    fi
    ;;
  help|*)
    echo ""
    echo "  EcoRewind — Gestionnaire de migrations Alembic"
    echo "  ================================================"
    echo "  Usage: ./migrate.sh [commande]"
    echo ""
    echo "  Commandes disponibles :"
    echo "    up          Appliquer toutes les migrations (alembic upgrade head)"
    echo "    down        Revenir d'une migration en arrière (alembic downgrade -1)"
    echo "    new 'msg'   Créer une nouvelle migration autogénérée"
    echo "    status      Voir la migration courante (alembic current)"
    echo "    history     Historique complet des migrations"
    echo "    reset       Revenir à zéro (SUPPRIME toutes les tables !)"
    echo ""
    echo "  Exemples :"
    echo "    ./migrate.sh up"
    echo "    ./migrate.sh new 'add_user_phone_column'"
    echo "    ./migrate.sh status"
    echo ""
    ;;
esac
