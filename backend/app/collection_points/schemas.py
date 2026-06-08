"""
app/collection_points/schemas.py — Schémas Pydantic : CollectionPoint
"""
from pydantic import BaseModel
from typing import Optional
from datetime import datetime


class CollectionPointCreate(BaseModel):
    name: str
    lat: str
    lng: str
    is_verified: bool = False
    types: str = ""  # comma-separated
    address: Optional[str] = None
    hours: Optional[str] = None
    status: str = "disponible"
    load_level: str = "0.0"


class CollectionPointUpdate(BaseModel):
    name: Optional[str] = None
    lat: Optional[str] = None
    lng: Optional[str] = None
    is_verified: Optional[bool] = None
    types: Optional[str] = None
    address: Optional[str] = None
    hours: Optional[str] = None
    status: Optional[str] = None
    load_level: Optional[str] = None


class CollectionPointOut(BaseModel):
    id: int
    name: str
    lat: str
    lng: str
    is_verified: bool
    types: str
    types_detail: dict = {}
    address: Optional[str] = None
    hours: Optional[str] = None
    status: str
    load_level: str
    created_at: datetime

    class Config:
        from_attributes = True
