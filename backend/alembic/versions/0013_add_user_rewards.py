"""
alembic/versions/0013_add_user_rewards.py
══════════════════════════════════════════
Migration : création de la table PostgreSQL `user_rewards`.

  - Clé étrangère vers users.id (CASCADE DELETE)
  - Contrainte UNIQUE (user_id, reward_key) — idempotence garantie
  - Index sur user_id, reward_key, unlocked_at

Revision ID : 0013
Revises     : 123fdff3491b  (merge_all_heads — dernier head actuel)
"""

from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

# ── Identifiants de révision ──────────────────────────────────────────────────
revision: str                       = "0013"
down_revision: Union[str, None]     = "123fdff3491b"
branch_labels: Union[str, None]     = None
depends_on: Union[str, None]        = None


def upgrade() -> None:
    op.create_table(
        "user_rewards",
        sa.Column("id",          sa.Integer(),  primary_key=True, autoincrement=True),
        sa.Column("user_id",     sa.Integer(),  nullable=False),
        sa.Column("reward_key",  sa.String(),   nullable=False),
        sa.Column("reward_type", sa.String(),   nullable=False, server_default="badge"),
        sa.Column("label",       sa.String(),   nullable=False),
        sa.Column("description", sa.String(),   nullable=True),
        sa.Column("icon",        sa.String(),   nullable=True),
        sa.Column(
            "unlocked_at",
            sa.DateTime(),
            nullable=False,
            server_default=sa.func.now(),
        ),
        sa.Column(
            "notified",
            sa.Boolean(),
            nullable=False,
            server_default=sa.false(),
        ),
        # ── Contraintes ─────────────────────────────────────────────────────
        sa.ForeignKeyConstraint(
            ["user_id"],
            ["users.id"],
            name="fk_user_rewards_user_id",
            ondelete="CASCADE",
        ),
        sa.UniqueConstraint(
            "user_id", "reward_key",
            name="uq_user_rewards_user_reward",
        ),
    )

    # ── Index de performance ─────────────────────────────────────────────────
    op.create_index(
        "ix_user_rewards_id",
        "user_rewards",
        ["id"],
        unique=True,
    )
    op.create_index(
        "ix_user_rewards_user_id",
        "user_rewards",
        ["user_id"],
        unique=False,
    )
    op.create_index(
        "ix_user_rewards_reward_key",
        "user_rewards",
        ["reward_key"],
        unique=False,
    )
    op.create_index(
        "ix_user_rewards_unlocked_at",
        "user_rewards",
        ["unlocked_at"],
        unique=False,
    )


def downgrade() -> None:
    op.drop_index("ix_user_rewards_unlocked_at", table_name="user_rewards")
    op.drop_index("ix_user_rewards_reward_key",  table_name="user_rewards")
    op.drop_index("ix_user_rewards_user_id",     table_name="user_rewards")
    op.drop_index("ix_user_rewards_id",          table_name="user_rewards")
    op.drop_table("user_rewards")
