"""
app/users/schemas.py — Schémas Pydantic : User
"""
from pydantic import BaseModel
from typing import Optional


class UserBase(BaseModel):
    email: str
    full_name: Optional[str] = None
    role: str = "user"
    qr_code: Optional[str] = None


class UserCreate(BaseModel):
    email: str
    full_name: Optional[str] = None
    role: str = "user"
    password: str


class UserOut(UserBase):
    id: int
    is_active: bool = True

    class Config:
        from_attributes = True


class UserSmall(BaseModel):
    id: int
    full_name: str
    email: str

    class Config:
        from_attributes = True


class UserUpdate(BaseModel):
    full_name: Optional[str] = None
    role: Optional[str] = None
    password: Optional[str] = None


class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str
