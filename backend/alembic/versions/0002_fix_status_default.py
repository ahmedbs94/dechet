"""
0002_fix_status_default.py — Correction du server_default du champ status

Révision : 0002
Dépend de : 0001_initial_schema

Contexte :
-----------
La migration initiale (0001) avait défini :
    server_default="pending_ai"

Mais le pipeline réel de modération (routers/posts.py) crée tous les posts
avec status='pending_review'. Le statut 'pending_ai' n'est jamais utilisé.

Cette migration corrige le server_default PostgreSQL vers 'pending_review'
et met à jour les éventuels posts orphelins en 'pending_ai' vers 'pending_review'.
"""

from alembic import op
import sqlalchemy as sa

# Identifiants de révision Alembic
revision = '0002'
down_revision = '0001'
branch_labels = None
depends_on = None


def upgrade():
    # 1. Corriger le server_default PostgreSQL
    op.alter_column(
        'posts',
        'status',
        server_default='pending_review',
        existing_type=sa.String(),
        existing_nullable=False,
    )

    # 2. Corriger les éventuels posts orphelins ayant encore status='pending_ai'
    #    (ne devraient pas exister, mais sécurité au cas où)
    op.execute("""
        UPDATE posts
        SET status = 'pending_review'
        WHERE status = 'pending_ai'
    """)


def downgrade():
    # Restaurer l'ancien server_default (rollback)
    op.alter_column(
        'posts',
        'status',
        server_default='pending_ai',
        existing_type=sa.String(),
        existing_nullable=False,
    )
