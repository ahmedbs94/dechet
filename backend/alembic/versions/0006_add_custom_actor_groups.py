"""
0006_add_custom_actor_groups — Table pour les groupes d'acteurs sur-mesure
==========================================================================
Ajoute :
  - custom_actor_groups : Groupes d'acteurs créés par l'intercommunalité

Revision ID: 0006
Revises: 0005
Create Date: 2026-06-19
"""
from alembic import op
import sqlalchemy as sa

# ── Identifiants Alembic ──────────────────────────────────────────────────────
revision: str = '0006'
down_revision = '0005'
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        'custom_actor_groups',
        sa.Column('id',          sa.Integer(),  primary_key=True,  nullable=False),
        sa.Column('name',        sa.String(),   nullable=False),
        sa.Column('description', sa.String(),   nullable=True),
        sa.Column('member_ids',  sa.JSON(),     nullable=False, server_default='[]'),
        sa.Column('created_by',  sa.Integer(),  sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('created_at',  sa.DateTime(), nullable=True),
    )
    op.create_index('ix_custom_actor_groups_name',       'custom_actor_groups', ['name'])
    op.create_index('ix_custom_actor_groups_created_by', 'custom_actor_groups', ['created_by'])


def downgrade() -> None:
    op.drop_index('ix_custom_actor_groups_created_by', 'custom_actor_groups')
    op.drop_index('ix_custom_actor_groups_name',       'custom_actor_groups')
    op.drop_table('custom_actor_groups')
