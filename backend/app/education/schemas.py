"""
app/education/schemas.py — Schémas Pydantic : VideoCategory, EducatorVideo,
                            CitizenGroup, GroupMember, Meeting, MeetingParticipant
"""
from pydantic import BaseModel
from typing import Optional, List
from datetime import datetime


class VideoCategoryOut(BaseModel):
    id: int
    title: str
    description: Optional[str] = None
    cover_image_url: Optional[str] = None
    educator_id: int
    created_at: datetime

    class Config:
        from_attributes = True


class EducatorVideoOut(BaseModel):
    id: int
    educator_id: int
    educator_name: str
    title: str
    description: Optional[str] = None
    video_url: str
    thumbnail_url: Optional[str] = None
    duration: Optional[str] = None
    category_id: Optional[int] = None
    created_at: datetime

    class Config:
        from_attributes = True


class GroupMemberOut(BaseModel):
    id: int
    group_id: int
    user_id: int
    added_at: datetime

    class Config:
        from_attributes = True


class GroupOut(BaseModel):
    id: int
    educator_id: int
    name: str
    description: Optional[str] = None
    color: str
    created_at: datetime
    members: List[GroupMemberOut] = []

    class Config:
        from_attributes = True


class MeetingParticipantOut(BaseModel):
    id: int
    meeting_id: int
    user_id: int
    user_name: Optional[str] = None
    status: str

    class Config:
        from_attributes = True


class MeetingOut(BaseModel):
    id: int
    educator_id: int
    educator_name: str
    title: str
    description: Optional[str] = None
    meet_link: str
    scheduled_at: datetime
    duration_minutes: int
    group_name: Optional[str] = None
    audience: str
    status: str
    created_at: datetime
    participants: List[MeetingParticipantOut] = []

    class Config:
        from_attributes = True
