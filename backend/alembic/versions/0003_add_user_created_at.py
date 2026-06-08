"""Add users.created_at

Revision ID: 0003_add_user_created_at
Revises: 7c8aff89d580
Create Date: 2026-06-08
"""
from alembic import op
import sqlalchemy as sa
from sqlalchemy.engine.reflection import Inspector

revision = "0003_add_user_created_at"
down_revision = "7c8aff89d580"
branch_labels = None
depends_on = None


def upgrade() -> None:
    # Détecter le dialecte pour le backfill
    bind = op.get_bind()
    dialect = bind.dialect.name  # "sqlite" ou "postgresql"

    with op.batch_alter_table("users") as batch_op:
        batch_op.add_column(
            sa.Column("created_at", sa.DateTime(), nullable=True)
        )

    # Backfill : syntaxe selon le dialecte
    if dialect == "postgresql":
        op.execute("UPDATE users SET created_at = NOW() WHERE created_at IS NULL")
    else:
        op.execute("UPDATE users SET created_at = CURRENT_TIMESTAMP WHERE created_at IS NULL")


def downgrade() -> None:
    with op.batch_alter_table("users") as batch_op:
        batch_op.drop_column("created_at")

