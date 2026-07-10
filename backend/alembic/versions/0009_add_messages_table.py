"""0009_add_messages_table.py — Migration : tables messages et message_group_recipients

Revision ID: 0009
Revises: 7c8aff89d580
Create Date: 2026-07-06
"""
from typing import Sequence, Union
from alembic import op
import sqlalchemy as sa

revision: str = "0009"
down_revision: Union[str, None] = "0008"
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── messages ──────────────────────────────────────────────────────────────
    op.create_table(
        "messages",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("sender_id", sa.Integer(), nullable=False),
        sa.Column("receiver_id", sa.Integer(), nullable=True),
        sa.Column("group_id", sa.Integer(), nullable=True),
        sa.Column("is_group_broadcast", sa.Boolean(), nullable=False, server_default="0"),
        sa.Column("collector_group_label", sa.String(), nullable=True),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("parent_id", sa.Integer(), nullable=True),
        sa.Column("is_read", sa.Boolean(), nullable=False, server_default="0"),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.ForeignKeyConstraint(["sender_id"],   ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["receiver_id"], ["users.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["group_id"],    ["citizen_groups.id"], ondelete="SET NULL"),
        sa.ForeignKeyConstraint(["parent_id"],   ["messages.id"], ondelete="SET NULL"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_messages_id",              "messages", ["id"],         unique=False)
    op.create_index("ix_messages_sender_id",       "messages", ["sender_id"],  unique=False)
    op.create_index("ix_messages_receiver_id",     "messages", ["receiver_id"], unique=False)
    op.create_index("ix_messages_created_at",      "messages", ["created_at"], unique=False)
    op.create_index("ix_messages_sender_receiver", "messages",
                    ["sender_id", "receiver_id"], unique=False)

    # ── message_group_recipients ───────────────────────────────────────────────
    op.create_table(
        "message_group_recipients",
        sa.Column("id",         sa.Integer(), nullable=False),
        sa.Column("message_id", sa.Integer(), nullable=False),
        sa.Column("user_id",    sa.Integer(), nullable=False),
        sa.Column("is_read",    sa.Boolean(), nullable=False, server_default="0"),
        sa.ForeignKeyConstraint(["message_id"], ["messages.id"], ondelete="CASCADE"),
        sa.ForeignKeyConstraint(["user_id"],    ["users.id"],    ondelete="CASCADE"),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index("ix_mgr_message_id", "message_group_recipients",
                    ["message_id"], unique=False)
    op.create_index("ix_mgr_user_id",    "message_group_recipients",
                    ["user_id"],    unique=False)


def downgrade() -> None:
    op.drop_table("message_group_recipients")
    op.drop_table("messages")
