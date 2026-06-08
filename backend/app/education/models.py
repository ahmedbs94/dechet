"""
app/education/models.py — Modèles SQLAlchemy : VideoCategory, EducatorVideo,
                           CitizenGroup, GroupMember, Meeting, MeetingParticipant
"""
from sqlalchemy import Column, Integer, String, DateTime, Text, ForeignKey
from sqlalchemy.orm import relationship
from datetime import datetime
from app.base import Base


class VideoCategory(Base):
    __tablename__ = "video_categories"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    cover_image_url = Column(String, nullable=True)
    educator_id = Column(Integer, ForeignKey("users.id"), index=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    educator = relationship("User")
    videos = relationship("EducatorVideo", back_populates="category")


class EducatorVideo(Base):
    __tablename__ = "educator_videos"

    id = Column(Integer, primary_key=True, index=True)
    educator_id = Column(Integer, ForeignKey("users.id"), index=True)
    educator_name = Column(String, nullable=False)
    title = Column(String, nullable=False)
    description = Column(Text, nullable=True)
    video_url = Column(String, nullable=False)
    thumbnail_url = Column(String, nullable=True)
    duration = Column(String, nullable=True)
    category_id = Column(Integer, ForeignKey("video_categories.id"), nullable=True, index=True)
    created_at = Column(DateTime, default=datetime.utcnow)

    educator = relationship("User")
    category = relationship("VideoCategory", back_populates="videos")


class CitizenGroup(Base):
    """Groupes de citoyens créés par un éducateur."""
    __tablename__ = "citizen_groups"

    id = Column(Integer, primary_key=True, index=True)
    educator_id = Column(Integer, ForeignKey("users.id"), index=True)
    name = Column(String, nullable=False)          # Nom du groupe
    description = Column(Text, nullable=True)
    color = Column(String, default="#00C896")       # Couleur d'identification
    created_at = Column(DateTime, default=datetime.utcnow)

    educator = relationship("User")
    members = relationship("GroupMember", back_populates="group",
                           cascade="all, delete-orphan")


class GroupMember(Base):
    """Membres d'un groupe de citoyens."""
    __tablename__ = "group_members"

    id = Column(Integer, primary_key=True, index=True)
    group_id = Column(Integer, ForeignKey("citizen_groups.id"), index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    added_at = Column(DateTime, default=datetime.utcnow)

    group = relationship("CitizenGroup", back_populates="members")
    user = relationship("User")


class Meeting(Base):
    """Séances Google Meet planifiées par un éducateur."""
    __tablename__ = "meetings"

    id = Column(Integer, primary_key=True, index=True)
    educator_id = Column(Integer, ForeignKey("users.id"), index=True)
    educator_name = Column(String, nullable=False)
    title = Column(String, nullable=False)          # Nom du cours
    description = Column(Text, nullable=True)       # Description / objectifs
    meet_link = Column(String, nullable=False)       # Lien Google Meet
    scheduled_at = Column(DateTime, nullable=False)  # Date & heure planifiée
    duration_minutes = Column(Integer, default=60)   # Durée en minutes
    group_name = Column(String, nullable=True)       # Nom du groupe de citoyens
    audience = Column(String, default="all")         # "all" ou "group"
    status = Column(String, default="scheduled")     # scheduled|ongoing|completed|cancelled
    created_at = Column(DateTime, default=datetime.utcnow)

    educator = relationship("User")
    participants = relationship("MeetingParticipant", back_populates="meeting",
                                cascade="all, delete-orphan")


class MeetingParticipant(Base):
    """Citoyens invités à une séance."""
    __tablename__ = "meeting_participants"

    id = Column(Integer, primary_key=True, index=True)
    meeting_id = Column(Integer, ForeignKey("meetings.id"), index=True)
    user_id = Column(Integer, ForeignKey("users.id"), index=True)
    user_name = Column(String, nullable=True)
    status = Column(String, default="invited")  # invited|confirmed|declined

    meeting = relationship("Meeting", back_populates="participants")
    user = relationship("User")
