from pydantic import BaseModel, EmailStr
from typing import Optional, List
from datetime import datetime

class UserBase(BaseModel):
    email: str
    full_name: Optional[str] = None
    role: str = "user"

class UserCreate(BaseModel):
    email: str
    full_name: Optional[str] = None
    role: str = "user"
    password: str

class User(UserBase):
    id: int
    is_active: bool = True

    class Config:
        from_attributes = True

class Token(BaseModel):
    access_token: str
    token_type: str
    role: str
    id: int
    email: str
    full_name: Optional[str] = None

class TokenData(BaseModel):
    email: Optional[str] = None

class GoogleAuth(BaseModel):
    token: str

class FacebookAuth(BaseModel):
    access_token: str

class ForgotPassword(BaseModel):
    email: str

class ResetPassword(BaseModel):
    token: str
    new_password: str

class PostBase(BaseModel):
    user_name: str
    user_avatar_url: str
    image_url: str
    description: str

class PostCreate(PostBase):
    pass

class CommentBase(BaseModel):
    user_name: str
    user_avatar_url: Optional[str] = None
    content: str

class CommentCreate(CommentBase):
    pass

class Comment(CommentBase):
    id: int
    user_id: int
    post_id: int
    created_at: datetime

    class Config:
        from_attributes = True

class CommentUpdate(BaseModel):
    content: str

class Post(PostBase):
    id: int
    user_id: int
    created_at: datetime
    likes_count: int
    comments: List[Comment] = []

    class Config:
        from_attributes = True

class PostUpdate(BaseModel):
    description: Optional[str] = None
    image_url: Optional[str] = None

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
