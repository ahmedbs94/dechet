"""merge_0012_and_0013

Revision ID: 0014_merge_levels
Revises: 0012, 0013
"""

from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "0014_merge_levels"
down_revision: Union[str, None] = ("0012", "0013")
branch_labels = None
depends_on = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
