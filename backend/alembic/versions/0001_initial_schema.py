"""Schéma initial EcoRewind — toutes les tables

Revision ID: 0001
Revises: 
Create Date: 2026-06-08 12:00:00.000000

Cette migration crée l'intégralité du schéma depuis zéro.
Elle remplace les anciens scripts migrate_*.py et le create_all() du main.py.

Tables créées :
  users, otp_codes,
  posts, saved_posts, likes, comments,
  notifications,
  collection_points,
  testimonials, center_proposals,
  quizzes, quiz_submissions,
  video_categories, educator_videos,
  citizen_groups, group_members,
  meetings, meeting_participants,
  smart_bins, bin_scans
"""
from typing import Sequence, Union

from alembic import op
import sqlalchemy as sa


# revision identifiers, used by Alembic.
revision: str = "0001"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    # ── users ─────────────────────────────────────────────────────────────────
    op.create_table(
        "users",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("email", sa.String(), nullable=True),
        sa.Column("full_name", sa.String(), nullable=True),
        sa.Column("hashed_password", sa.String(), nullable=True),
        sa.Column("is_active", sa.Boolean(), nullable=True),
        sa.Column("is_verified", sa.Boolean(), nullable=True),
        sa.Column("role", sa.String(), nullable=True),
        sa.Column("google_id", sa.String(), nullable=True),
        sa.Column("facebook_id", sa.String(), nullable=True),
        sa.Column("qr_code", sa.String(), nullable=False),
        sa.Column("reset_token", sa.String(), nullable=True),
        sa.Column("token_expires", sa.String(), nullable=True),
        sa.Column("avatar_url", sa.String(), nullable=True),
        sa.Column("global_score", sa.Float(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_users_id"), "users", ["id"], unique=False)
    op.create_index(op.f("ix_users_email"), "users", ["email"], unique=True)
    op.create_index(op.f("ix_users_google_id"), "users", ["google_id"], unique=True)
    op.create_index(op.f("ix_users_facebook_id"), "users", ["facebook_id"], unique=True)
    op.create_index(op.f("ix_users_qr_code"), "users", ["qr_code"], unique=True)
    op.create_index(op.f("ix_users_reset_token"), "users", ["reset_token"], unique=True)

    # ── otp_codes ────────────────────────────────────────────────────────────
    op.create_table(
        "otp_codes",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("identifier", sa.String(), nullable=True),
        sa.Column("code", sa.String(), nullable=True),
        sa.Column("purpose", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("expires_at", sa.DateTime(), nullable=True),
        sa.Column("is_used", sa.Boolean(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_otp_codes_id"), "otp_codes", ["id"], unique=False)
    op.create_index(op.f("ix_otp_codes_identifier"), "otp_codes", ["identifier"], unique=False)

    # ── posts ────────────────────────────────────────────────────────────────
    op.create_table(
        "posts",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("user_name", sa.String(), nullable=True),
        sa.Column("user_avatar_url", sa.String(), nullable=True),
        sa.Column("image_url", sa.String(), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.Column("likes_count", sa.Integer(), nullable=True),
        # ── Modération IA ─────────────────────────────────────────────────────────────
        # Flux réel : pending_review → published | pending_review (admin) | rejected
        # Note : le server_default ici est 'pending_ai' (valeur historique).
        # Corrigé vers 'pending_review' via migration 0002_fix_status_default.py
        sa.Column("status", sa.String(), nullable=False, server_default="pending_ai"),
        sa.Column("moderation_score", sa.Float(), nullable=False, server_default="0.0"),
        sa.Column("moderation_reason", sa.String(), nullable=True),
        sa.Column("moderation_details", sa.Text(), nullable=True),
        sa.Column("moderated_at", sa.DateTime(), nullable=True),
        sa.Column("moderation_model_version", sa.String(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_posts_id"), "posts", ["id"], unique=False)

    # ── saved_posts ──────────────────────────────────────────────────────────
    op.create_table(
        "saved_posts",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("post_id", sa.Integer(), sa.ForeignKey("posts.id"), nullable=True),
        sa.Column("saved_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_saved_posts_id"), "saved_posts", ["id"], unique=False)

    # ── likes ────────────────────────────────────────────────────────────────
    op.create_table(
        "likes",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("post_id", sa.Integer(), sa.ForeignKey("posts.id"), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_likes_id"), "likes", ["id"], unique=False)

    # ── comments ─────────────────────────────────────────────────────────────
    op.create_table(
        "comments",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("post_id", sa.Integer(), sa.ForeignKey("posts.id"), nullable=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("user_name", sa.String(), nullable=True),
        sa.Column("user_avatar_url", sa.String(), nullable=True),
        sa.Column("content", sa.Text(), nullable=True),
        sa.Column("parent_id", sa.Integer(), sa.ForeignKey("comments.id"), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_comments_id"), "comments", ["id"], unique=False)

    # ── notifications ─────────────────────────────────────────────────────────
    op.create_table(
        "notifications",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("type", sa.String(), nullable=True),
        sa.Column("title", sa.String(), nullable=True),
        sa.Column("body", sa.String(), nullable=True),
        sa.Column("from_user_name", sa.String(), nullable=True),
        sa.Column("post_id", sa.Integer(), nullable=True),
        sa.Column("comment_id", sa.Integer(), nullable=True),
        sa.Column("is_read", sa.Boolean(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_notifications_id"), "notifications", ["id"], unique=False)
    op.create_index(op.f("ix_notifications_user_id"), "notifications", ["user_id"], unique=False)

    # ── collection_points ────────────────────────────────────────────────────
    op.create_table(
        "collection_points",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("lat", sa.String(), nullable=False),
        sa.Column("lng", sa.String(), nullable=False),
        sa.Column("is_verified", sa.Boolean(), nullable=True),
        sa.Column("types", sa.String(), nullable=True),
        sa.Column("address", sa.String(), nullable=True),
        sa.Column("hours", sa.String(), nullable=True),
        sa.Column("status", sa.String(), nullable=True),
        sa.Column("load_level", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_collection_points_id"), "collection_points", ["id"], unique=False)

    # ── testimonials ─────────────────────────────────────────────────────────
    op.create_table(
        "testimonials",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("user_name", sa.String(), nullable=False),
        sa.Column("user_avatar_url", sa.String(), nullable=True),
        sa.Column("content", sa.Text(), nullable=False),
        sa.Column("rating", sa.Integer(), nullable=True),
        sa.Column("is_approved", sa.Boolean(), nullable=True),
        sa.Column("is_featured", sa.Boolean(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_testimonials_id"), "testimonials", ["id"], unique=False)

    # ── center_proposals ─────────────────────────────────────────────────────
    op.create_table(
        "center_proposals",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("user_name", sa.String(), nullable=True),
        sa.Column("name", sa.String(), nullable=True),
        sa.Column("address", sa.String(), nullable=True),
        sa.Column("lat", sa.String(), nullable=True),
        sa.Column("lng", sa.String(), nullable=True),
        sa.Column("waste_types", sa.String(), nullable=True),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("status", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_center_proposals_id"), "center_proposals", ["id"], unique=False)
    op.create_index(op.f("ix_center_proposals_user_id"), "center_proposals", ["user_id"], unique=False)

    # ── quizzes ──────────────────────────────────────────────────────────────
    op.create_table(
        "quizzes",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("educator_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("pdf_filename", sa.String(), nullable=False),
        sa.Column("questions_json", sa.Text(), nullable=True),
        sa.Column("answer_key_json", sa.Text(), nullable=True),
        sa.Column("total_questions", sa.Integer(), nullable=True),
        sa.Column("status", sa.String(), nullable=True),
        sa.Column("error_message", sa.Text(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_quizzes_id"), "quizzes", ["id"], unique=False)
    op.create_index(op.f("ix_quizzes_educator_id"), "quizzes", ["educator_id"], unique=False)

    # ── quiz_submissions ─────────────────────────────────────────────────────
    op.create_table(
        "quiz_submissions",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("quiz_id", sa.Integer(), sa.ForeignKey("quizzes.id"), nullable=True),
        sa.Column("student_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("student_name", sa.String(), nullable=True),
        sa.Column("answers_json", sa.Text(), nullable=True),
        sa.Column("score", sa.Float(), nullable=True),
        sa.Column("max_score", sa.Float(), nullable=True),
        sa.Column("feedback_json", sa.Text(), nullable=True),
        sa.Column("ai_graded", sa.Boolean(), nullable=True),
        sa.Column("submitted_at", sa.DateTime(), nullable=True),
        sa.Column("graded_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_quiz_submissions_id"), "quiz_submissions", ["id"], unique=False)
    op.create_index(op.f("ix_quiz_submissions_quiz_id"), "quiz_submissions", ["quiz_id"], unique=False)
    op.create_index(op.f("ix_quiz_submissions_student_id"), "quiz_submissions", ["student_id"], unique=False)

    # ── video_categories ─────────────────────────────────────────────────────
    op.create_table(
        "video_categories",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("cover_image_url", sa.String(), nullable=True),
        sa.Column("educator_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_video_categories_id"), "video_categories", ["id"], unique=False)
    op.create_index(op.f("ix_video_categories_educator_id"), "video_categories", ["educator_id"], unique=False)

    # ── educator_videos ──────────────────────────────────────────────────────
    op.create_table(
        "educator_videos",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("educator_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("educator_name", sa.String(), nullable=False),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("video_url", sa.String(), nullable=False),
        sa.Column("thumbnail_url", sa.String(), nullable=True),
        sa.Column("duration", sa.String(), nullable=True),
        sa.Column("category_id", sa.Integer(), sa.ForeignKey("video_categories.id"), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_educator_videos_id"), "educator_videos", ["id"], unique=False)
    op.create_index(op.f("ix_educator_videos_educator_id"), "educator_videos", ["educator_id"], unique=False)
    op.create_index(op.f("ix_educator_videos_category_id"), "educator_videos", ["category_id"], unique=False)

    # ── citizen_groups ───────────────────────────────────────────────────────
    op.create_table(
        "citizen_groups",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("educator_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("name", sa.String(), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("color", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_citizen_groups_id"), "citizen_groups", ["id"], unique=False)
    op.create_index(op.f("ix_citizen_groups_educator_id"), "citizen_groups", ["educator_id"], unique=False)

    # ── group_members ────────────────────────────────────────────────────────
    op.create_table(
        "group_members",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("group_id", sa.Integer(), sa.ForeignKey("citizen_groups.id"), nullable=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("added_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_group_members_id"), "group_members", ["id"], unique=False)
    op.create_index(op.f("ix_group_members_group_id"), "group_members", ["group_id"], unique=False)
    op.create_index(op.f("ix_group_members_user_id"), "group_members", ["user_id"], unique=False)

    # ── meetings ─────────────────────────────────────────────────────────────
    op.create_table(
        "meetings",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("educator_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("educator_name", sa.String(), nullable=False),
        sa.Column("title", sa.String(), nullable=False),
        sa.Column("description", sa.Text(), nullable=True),
        sa.Column("meet_link", sa.String(), nullable=False),
        sa.Column("scheduled_at", sa.DateTime(), nullable=False),
        sa.Column("duration_minutes", sa.Integer(), nullable=True),
        sa.Column("group_name", sa.String(), nullable=True),
        sa.Column("audience", sa.String(), nullable=True),
        sa.Column("status", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_meetings_id"), "meetings", ["id"], unique=False)
    op.create_index(op.f("ix_meetings_educator_id"), "meetings", ["educator_id"], unique=False)

    # ── meeting_participants ─────────────────────────────────────────────────
    op.create_table(
        "meeting_participants",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("meeting_id", sa.Integer(), sa.ForeignKey("meetings.id"), nullable=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("user_name", sa.String(), nullable=True),
        sa.Column("status", sa.String(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_meeting_participants_id"), "meeting_participants", ["id"], unique=False)
    op.create_index(op.f("ix_meeting_participants_meeting_id"), "meeting_participants", ["meeting_id"], unique=False)
    op.create_index(op.f("ix_meeting_participants_user_id"), "meeting_participants", ["user_id"], unique=False)

    # ── smart_bins ───────────────────────────────────────────────────────────
    op.create_table(
        "smart_bins",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("bin_code", sa.String(), nullable=False),
        sa.Column("collection_point_id", sa.Integer(), sa.ForeignKey("collection_points.id"), nullable=True),
        sa.Column("bin_type", sa.String(), nullable=True),
        sa.Column("capacity_kg", sa.Float(), nullable=True),
        sa.Column("status", sa.String(), nullable=True),
        sa.Column("location_note", sa.String(), nullable=True),
        sa.Column("created_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_smart_bins_id"), "smart_bins", ["id"], unique=False)
    op.create_index(op.f("ix_smart_bins_bin_code"), "smart_bins", ["bin_code"], unique=True)
    op.create_index(op.f("ix_smart_bins_collection_point_id"), "smart_bins", ["collection_point_id"], unique=False)

    # ── bin_scans ────────────────────────────────────────────────────────────
    op.create_table(
        "bin_scans",
        sa.Column("id", sa.Integer(), nullable=False),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id"), nullable=True),
        sa.Column("qr_code", sa.String(), nullable=False),
        sa.Column("smart_bin_id", sa.Integer(), sa.ForeignKey("smart_bins.id"), nullable=True),
        sa.Column("bin_id", sa.String(), nullable=True),
        sa.Column("waste_type", sa.String(), nullable=True),
        sa.Column("weight_kg", sa.Float(), nullable=True),
        sa.Column("points_earned", sa.Float(), nullable=True),
        sa.Column("score_before", sa.Float(), nullable=True),
        sa.Column("score_after", sa.Float(), nullable=True),
        sa.Column("firebase_synced", sa.Boolean(), nullable=True),
        sa.Column("scanned_at", sa.DateTime(), nullable=True),
        sa.PrimaryKeyConstraint("id"),
    )
    op.create_index(op.f("ix_bin_scans_id"), "bin_scans", ["id"], unique=False)
    op.create_index(op.f("ix_bin_scans_user_id"), "bin_scans", ["user_id"], unique=False)
    op.create_index(op.f("ix_bin_scans_smart_bin_id"), "bin_scans", ["smart_bin_id"], unique=False)


def downgrade() -> None:
    # Suppression dans l'ordre inverse (respecter les FK)
    op.drop_table("bin_scans")
    op.drop_table("smart_bins")
    op.drop_table("meeting_participants")
    op.drop_table("meetings")
    op.drop_table("group_members")
    op.drop_table("citizen_groups")
    op.drop_table("educator_videos")
    op.drop_table("video_categories")
    op.drop_table("quiz_submissions")
    op.drop_table("quizzes")
    op.drop_table("center_proposals")
    op.drop_table("testimonials")
    op.drop_table("collection_points")
    op.drop_table("notifications")
    op.drop_table("comments")
    op.drop_table("likes")
    op.drop_table("saved_posts")
    op.drop_table("posts")
    op.drop_table("otp_codes")
    op.drop_table("users")
