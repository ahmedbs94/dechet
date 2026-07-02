"""
0007_add_notification_reply_fields — Champs pour le système de réponse acteur→intercommunalité
================================================================================================
Ajoute :
  - sender_id             : ID de l'expéditeur du message (pour les réponses)
  - source_notification_id: ID de la notification d'origine (threading)

Revision ID: 0007
Revises: 0006
Create Date: 2026-06-19
"""
from alembic import op
import sqlalchemy as sa

# ── Identifiants Alembic ──────────────────────────────────────────────────────
revision: str = '0007'
down_revision = '0006'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Ajoute sender_id (expéditeur du message)
    op.add_column('notifications',
        sa.Column('sender_id', sa.Integer(),
                  sa.ForeignKey('users.id', ondelete='SET NULL'),
                  nullable=True))
    op.create_index('ix_notifications_sender_id', 'notifications', ['sender_id'])

    # Ajoute source_notification_id (ID de la notification parente = fil de discussion)
    op.add_column('notifications',
        sa.Column('source_notification_id', sa.Integer(),
                  sa.ForeignKey('notifications.id', ondelete='SET NULL'),
                  nullable=True))
    op.create_index('ix_notifications_source_id', 'notifications', ['source_notification_id'])

    # Étend le type de la colonne body de VARCHAR à TEXT (si PostgreSQL)
    try:
        op.alter_column('notifications', 'body', type_=sa.Text())
    except Exception:
        pass  # SQLite ignore silencieusement


def downgrade() -> None:
    op.drop_index('ix_notifications_source_id',  'notifications')
    op.drop_index('ix_notifications_sender_id',   'notifications')
    op.drop_column('notifications', 'source_notification_id')
    op.drop_column('notifications', 'sender_id')
