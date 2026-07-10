"""
Migration 0010 — Affectations directes à des centres de tri
=============================================================
Modifications sur collector_zone_assignments :
  - Ajout : collection_point_ids TEXT    (liste JSON de IDs centres)
  - Ajout : target_label VARCHAR(200)    (label auto-généré)
  - Ajout : collection_point_id FK       (rétrocompat — centre unique)
  - Ajout : group_id FK                  (affectation à un groupe)
  - zone_id         → NULLABLE           (mode centres directs sans zone)
  - collector_id    → NULLABLE           (affectation possible à un groupe)
"""

from typing import Union
import sqlalchemy as sa
from alembic import op

# revision identifiers, used by Alembic.
revision: str = '0010'
down_revision: Union[str, None] = '0008'
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Utilisation de SQL brut avec IF NOT EXISTS pour idempotence
    # (les colonnes ont pu être ajoutées manuellement sur une DB existante)
    from alembic import op as _op
    from sqlalchemy import text

    conn = _op.get_bind()

    # ── 1. Rendre zone_id nullable ─────────────────────────────────────────
    conn.execute(text(
        "ALTER TABLE collector_zone_assignments "
        "ALTER COLUMN zone_id DROP NOT NULL"
    ))

    # ── 2. Rendre collector_id nullable ────────────────────────────────────
    try:
        conn.execute(text(
            "ALTER TABLE collector_zone_assignments "
            "ALTER COLUMN collector_id DROP NOT NULL"
        ))
    except Exception:
        pass  # Déjà nullable

    # ── 3. Nouvelles colonnes (IF NOT EXISTS — PostgreSQL 9.6+) ───────────
    for col_sql in [
        "ALTER TABLE collector_zone_assignments ADD COLUMN IF NOT EXISTS "
        "collection_point_ids TEXT",

        "ALTER TABLE collector_zone_assignments ADD COLUMN IF NOT EXISTS "
        "target_label VARCHAR(200)",

        "ALTER TABLE collector_zone_assignments ADD COLUMN IF NOT EXISTS "
        "collection_point_id INTEGER REFERENCES collection_points(id) ON DELETE SET NULL",

        "ALTER TABLE collector_zone_assignments ADD COLUMN IF NOT EXISTS "
        "group_id INTEGER REFERENCES custom_actor_groups(id) ON DELETE SET NULL",
    ]:
        try:
            conn.execute(text(col_sql))
        except Exception:
            pass  # Colonne déjà existante — idempotent


def downgrade() -> None:
    op.drop_column('collector_zone_assignments', 'group_id')
    op.drop_column('collector_zone_assignments', 'collection_point_id')
    op.drop_column('collector_zone_assignments', 'target_label')
    op.drop_column('collector_zone_assignments', 'collection_point_ids')

    # Remettre les contraintes NOT NULL
    op.alter_column(
        'collector_zone_assignments', 'collector_id',
        existing_type=sa.Integer(),
        nullable=False,
    )
    op.alter_column(
        'collector_zone_assignments', 'zone_id',
        existing_type=sa.Integer(),
        nullable=False,
    )
