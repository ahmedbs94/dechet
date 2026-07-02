"""
Migration 0008 — Création des tables F5 Pilotage Collecteurs
=============================================================
Tables créées :
  - collector_zones            : zones territoriales
  - collector_zone_assignments : affectations collecteur ↔ zone
"""

from typing import Union
import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = '0008'
down_revision: Union[str, None] = '7c8aff89d580'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── 1. collector_zones ────────────────────────────────────────────────
    op.create_table(
        'collector_zones',
        sa.Column('id',          sa.Integer(),     primary_key=True, autoincrement=True),
        sa.Column('name',        sa.String(),      nullable=False,   index=True),
        sa.Column('territory',   sa.String(),      nullable=False,   index=True),
        sa.Column('description', sa.Text(),        nullable=True),
        sa.Column('color_hex',   sa.String(),      nullable=False,   server_default='#4CAF50'),
        sa.Column('created_by',  sa.Integer(),     sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
        sa.Column('created_at',  sa.DateTime(),    nullable=False,   server_default=sa.func.now()),
        sa.Column('updated_at',  sa.DateTime(),    nullable=False,   server_default=sa.func.now(),
                  onupdate=sa.func.now()),
    )

    # ── 2. collector_zone_assignments ─────────────────────────────────────
    op.create_table(
        'collector_zone_assignments',
        sa.Column('id',              sa.Integer(), primary_key=True, autoincrement=True),
        sa.Column('zone_id',         sa.Integer(),
                  sa.ForeignKey('collector_zones.id', ondelete='CASCADE'),
                  nullable=False, index=True),
        sa.Column('collector_id',    sa.Integer(),
                  sa.ForeignKey('users.id', ondelete='CASCADE'),
                  nullable=False, index=True),
        sa.Column('assigned_by',     sa.Integer(),
                  sa.ForeignKey('users.id', ondelete='CASCADE'),
                  nullable=False),
        sa.Column('mission_message', sa.Text(),    nullable=True),
        sa.Column('priority',        sa.String(),  nullable=False, server_default='normal'),
        sa.Column('status',          sa.String(),  nullable=False, server_default='pending', index=True),
        sa.Column('due_date',        sa.DateTime(), nullable=True),
        sa.Column('assigned_at',     sa.DateTime(), nullable=False, server_default=sa.func.now(), index=True),
        sa.Column('completed_at',    sa.DateTime(), nullable=True),
        sa.Column('collector_notes', sa.Text(),    nullable=True),
    )


def downgrade() -> None:
    op.drop_table('collector_zone_assignments')
    op.drop_table('collector_zones')
