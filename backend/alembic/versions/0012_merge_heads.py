"""
Migration 0012 — Merge des heads PostgreSQL
============================================
Merge de la branche 123fdff3491b (sync existante) et 0011 (types fixes)
pour avoir un seul head linéaire.
"""

from typing import Union, Sequence
from alembic import op
import sqlalchemy as sa

# revision identifiers, used by Alembic.
revision: str = '0012'
down_revision: Union[str, None] = ('123fdff3491b', '0011')
branch_labels = None
depends_on = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
