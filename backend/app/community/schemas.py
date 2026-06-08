"""
app/community/schemas.py — Schémas Pydantic : Testimonial, CenterProposal
"""
from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class TestimonialCreate(BaseModel):
    content: str
    rating: int = 5  # 1-5


class TestimonialOut(BaseModel):
    id: int
    user_id: Optional[int] = None
    user_name: Optional[str] = None
    user_avatar_url: Optional[str] = None
    content: str
    rating: int
    is_approved: bool = False
    is_featured: bool = False
    created_at: datetime

    class Config:
        from_attributes = True


class CenterProposalCreate(BaseModel):
    name: str
    address: str
    lat: Optional[str] = None
    lng: Optional[str] = None
    waste_types: str = ""  # comma-separated
    description: Optional[str] = None


class CenterProposalOut(BaseModel):
    id: int
    user_id: int
    user_name: Optional[str] = None
    name: str
    address: str
    lat: Optional[str] = None
    lng: Optional[str] = None
    waste_types: str
    description: Optional[str] = None
    status: str
    created_at: datetime

    class Config:
        from_attributes = True
