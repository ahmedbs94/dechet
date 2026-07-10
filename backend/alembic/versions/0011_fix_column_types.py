"""
Migration 0011 — Correction des types de colonnes PostgreSQL
=============================================================
Corrections :
  - collection_points.lat        : String → Double Precision (Float) — latitude WGS84
  - collection_points.lng        : String → Double Precision (Float) — longitude WGS84
  - collection_points.load_level : String → Double Precision (Float) — 0.0 à 100.0
  - collector_routes.total_weight_kg : String → Double Precision (Float)

Ces colonnes stockaient des valeurs numériques en VARCHAR, ce qui empêche
les calculs, les comparaisons et les index optimisés côté PostgreSQL.
"""

from typing import Union
import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = '0011'
down_revision: Union[str, None] = '0010'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # ── collection_points : lat, lng, load_level en Float ─────────────────
    with op.batch_alter_table('collection_points') as batch_op:
        batch_op.alter_column(
            'lat',
            type_=sa.Float(),
            existing_type=sa.String(),
            nullable=True,
            postgresql_using='lat::double precision',
        )
        batch_op.alter_column(
            'lng',
            type_=sa.Float(),
            existing_type=sa.String(),
            nullable=True,
            postgresql_using='lng::double precision',
        )
        batch_op.alter_column(
            'load_level',
            type_=sa.Float(),
            existing_type=sa.String(),
            nullable=True,
            server_default='0.0',
            postgresql_using="COALESCE(NULLIF(load_level, '')::double precision, 0.0)",
        )

    # ── collector_routes : total_weight_kg en Float ───────────────────────
    try:
        with op.batch_alter_table('collection_routes') as batch_op:
            batch_op.alter_column(
                'total_weight_kg',
                type_=sa.Float(),
                existing_type=sa.String(),
                nullable=True,
                postgresql_using="COALESCE(NULLIF(total_weight_kg, '')::double precision, NULL)",
            )
    except Exception:
        pass  # Table absente — skip


def downgrade() -> None:
    # Retour en String (perte de précision acceptable pour rollback)
    with op.batch_alter_table('collection_points') as batch_op:
        batch_op.alter_column(
            'lat',
            type_=sa.String(),
            existing_type=sa.Float(),
            nullable=True,
        )
        batch_op.alter_column(
            'lng',
            type_=sa.String(),
            existing_type=sa.Float(),
            nullable=True,
        )
        batch_op.alter_column(
            'load_level',
            type_=sa.String(),
            existing_type=sa.Float(),
            nullable=True,
            server_default='0.0',
        )

    try:
        with op.batch_alter_table('collection_routes') as batch_op:
            batch_op.alter_column(
                'total_weight_kg',
                type_=sa.String(),
                existing_type=sa.Float(),
                nullable=True,
            )
    except Exception:
        pass
