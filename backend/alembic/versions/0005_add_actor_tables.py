"""
0005_add_actor_tables — Tables pour les 3 acteurs métier EcoRewind
===================================================================
Ajoute :
  - local_instructions  : Consignes locales de tri (Intercommunalité)
  - citizen_reports     : Signalements citoyens (PointManager)
  - collection_routes   : Tournées de collecte (Collector)

Revision ID: 0005
Revises: 0004
Create Date: 2026-06-18
"""
from alembic import op
import sqlalchemy as sa

# ── Identifiants Alembic ──────────────────────────────────────────────────────
revision: str = '0005'
down_revision = '0004'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── 1. local_instructions ─────────────────────────────────────────────────
    op.create_table(
        'local_instructions',
        sa.Column('id',          sa.Integer(),  primary_key=True,  nullable=False),
        sa.Column('territory',   sa.String(),   nullable=False),
        sa.Column('city',        sa.String(),   nullable=True),
        sa.Column('waste_type',  sa.String(),   nullable=False),
        sa.Column('title',       sa.String(),   nullable=False),
        sa.Column('instruction', sa.Text(),     nullable=False),
        sa.Column('is_active',   sa.Boolean(),  nullable=False, server_default='1'),
        sa.Column('created_by',  sa.Integer(),  sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
        sa.Column('created_at',  sa.DateTime(), nullable=True),
        sa.Column('updated_at',  sa.DateTime(), nullable=True),
    )
    op.create_index('ix_local_instructions_territory', 'local_instructions', ['territory'])
    op.create_index('ix_local_instructions_city',      'local_instructions', ['city'])
    op.create_index('ix_local_instructions_is_active', 'local_instructions', ['is_active'])

    # ── 2. citizen_reports ────────────────────────────────────────────────────
    op.create_table(
        'citizen_reports',
        sa.Column('id',                  sa.Integer(),  primary_key=True, nullable=False),
        sa.Column('collection_point_id', sa.Integer(),  sa.ForeignKey('collection_points.id', ondelete='CASCADE'), nullable=False),
        sa.Column('user_id',             sa.Integer(),  sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('report_type',         sa.String(),   nullable=False, server_default='other'),
        sa.Column('description',         sa.Text(),     nullable=True),
        sa.Column('photo_url',           sa.String(),   nullable=True),
        sa.Column('status',              sa.String(),   nullable=False, server_default='pending'),
        sa.Column('assigned_to',         sa.Integer(),  sa.ForeignKey('users.id', ondelete='SET NULL'), nullable=True),
        sa.Column('resolution_note',     sa.Text(),     nullable=True),
        sa.Column('resolved_at',         sa.DateTime(), nullable=True),
        sa.Column('created_at',          sa.DateTime(), nullable=True),
        sa.Column('updated_at',          sa.DateTime(), nullable=True),
    )
    op.create_index('ix_citizen_reports_collection_point_id', 'citizen_reports', ['collection_point_id'])
    op.create_index('ix_citizen_reports_user_id',             'citizen_reports', ['user_id'])
    op.create_index('ix_citizen_reports_status',              'citizen_reports', ['status'])
    op.create_index('ix_citizen_reports_assigned_to',         'citizen_reports', ['assigned_to'])
    op.create_index('ix_citizen_reports_created_at',          'citizen_reports', ['created_at'])

    # ── 3. collection_routes ──────────────────────────────────────────────────
    op.create_table(
        'collection_routes',
        sa.Column('id',              sa.Integer(),  primary_key=True, nullable=False),
        sa.Column('collector_id',    sa.Integer(),  sa.ForeignKey('users.id', ondelete='CASCADE'), nullable=False),
        sa.Column('date_planned',    sa.DateTime(), nullable=False),
        sa.Column('status',          sa.String(),   nullable=False, server_default='planned'),
        sa.Column('point_ids',       sa.Text(),     nullable=True),   # JSON list of collection_point IDs
        sa.Column('notes',           sa.Text(),     nullable=True),
        sa.Column('total_weight_kg', sa.String(),   nullable=True),
        sa.Column('completed_at',    sa.DateTime(), nullable=True),
        sa.Column('created_at',      sa.DateTime(), nullable=True),
        sa.Column('updated_at',      sa.DateTime(), nullable=True),
    )
    op.create_index('ix_collection_routes_collector_id', 'collection_routes', ['collector_id'])
    op.create_index('ix_collection_routes_date_planned', 'collection_routes', ['date_planned'])
    op.create_index('ix_collection_routes_status',       'collection_routes', ['status'])


def downgrade() -> None:
    op.drop_table('collection_routes')
    op.drop_table('citizen_reports')
    op.drop_table('local_instructions')
