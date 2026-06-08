"""analytics_indexes — Index SQL pour les requêtes analytics admin
================================================================
Ajoute des index sur toutes les colonnes utilisées dans les agrégations
analytics : COUNT, SUM, AVG, GROUP BY, WHERE sur role, created_at, etc.

Sans ces index, chaque requête analytics fait un full-table scan.
Avec 10 000+ scans, le dashboard devient lent.

Revision ID: 0004
Revises: 7c8aff89d580
Create Date: 2026-06-08
"""
from alembic import op

# ── Identifiants Alembic ──────────────────────────────────────────────────────
revision: str = '0004'
down_revision = '0003_add_user_created_at'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── users ─────────────────────────────────────────────────────────────────
    # Utilisées par : COUNT(users) GROUP BY role, ORDER BY global_score DESC,
    #                 WHERE created_at >= :since
    op.create_index('ix_users_role',         'users', ['role'],         unique=False)
    op.create_index('ix_users_created_at',   'users', ['created_at'],   unique=False)
    op.create_index('ix_users_global_score', 'users', ['global_score'], unique=False)
    op.create_index('ix_users_is_active',    'users', ['is_active'],    unique=False)

    # ── bin_scans ─────────────────────────────────────────────────────────────
    # Utilisées par : COUNT(*) WHERE scanned_at >= :since,
    #                 GROUP BY waste_type, WHERE firebase_synced = false
    op.create_index('ix_bin_scans_scanned_at',      'bin_scans', ['scanned_at'],      unique=False)
    op.create_index('ix_bin_scans_waste_type',       'bin_scans', ['waste_type'],       unique=False)
    op.create_index('ix_bin_scans_firebase_synced',  'bin_scans', ['firebase_synced'],  unique=False)
    op.create_index('ix_bin_scans_points_earned',    'bin_scans', ['points_earned'],    unique=False)

    # ── posts ─────────────────────────────────────────────────────────────────
    # Utilisées par : COUNT(*) GROUP BY status, WHERE status = 'pending_review'
    op.create_index('ix_posts_status',       'posts', ['status'],       unique=False)
    op.create_index('ix_posts_created_at',   'posts', ['created_at'],   unique=False)

    # ── quiz_submissions ──────────────────────────────────────────────────────
    # Utilisées par : COUNT(*) WHERE submitted_at >= :since, AVG(score)
    op.create_index('ix_quiz_submissions_submitted_at', 'quiz_submissions', ['submitted_at'], unique=False)
    op.create_index('ix_quiz_submissions_score',        'quiz_submissions', ['score'],        unique=False)

    # ── collection_points ─────────────────────────────────────────────────────
    # Utilisées par : COUNT(*) GROUP BY status
    op.create_index('ix_collection_points_status', 'collection_points', ['status'], unique=False)

    # ── testimonials ──────────────────────────────────────────────────────────
    # Utilisées par : COUNT(*) WHERE is_approved = false
    op.create_index('ix_testimonials_is_approved', 'testimonials', ['is_approved'], unique=False)

    # ── center_proposals ──────────────────────────────────────────────────────
    # Utilisées par : COUNT(*) WHERE status = 'pending'
    op.create_index('ix_center_proposals_status', 'center_proposals', ['status'], unique=False)


def downgrade() -> None:
    # Suppression dans l'ordre inverse
    op.drop_index('ix_center_proposals_status',        table_name='center_proposals')
    op.drop_index('ix_testimonials_is_approved',       table_name='testimonials')
    op.drop_index('ix_collection_points_status',       table_name='collection_points')
    op.drop_index('ix_quiz_submissions_score',         table_name='quiz_submissions')
    op.drop_index('ix_quiz_submissions_submitted_at',  table_name='quiz_submissions')
    op.drop_index('ix_posts_created_at',               table_name='posts')
    op.drop_index('ix_posts_status',                   table_name='posts')
    op.drop_index('ix_bin_scans_points_earned',        table_name='bin_scans')
    op.drop_index('ix_bin_scans_firebase_synced',      table_name='bin_scans')
    op.drop_index('ix_bin_scans_waste_type',           table_name='bin_scans')
    op.drop_index('ix_bin_scans_scanned_at',           table_name='bin_scans')
    op.drop_index('ix_users_is_active',                table_name='users')
    op.drop_index('ix_users_global_score',             table_name='users')
    op.drop_index('ix_users_created_at',               table_name='users')
    op.drop_index('ix_users_role',                     table_name='users')
