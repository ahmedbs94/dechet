"""merge_all_heads

Revision ID: 123fdff3491b
Revises: 0002, 0007, 0009
Create Date: 2026-07-06 19:42:58.722069

"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = '123fdff3491b'
down_revision: Union[str, None] = ('0002', '0007', '0009')
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
