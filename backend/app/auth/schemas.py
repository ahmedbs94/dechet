"""
app/auth/schemas.py — Schémas Pydantic : Auth / JWT / OTP
"""
from pydantic import BaseModel
from typing import Optional


class Token(BaseModel):
    access_token: str
    refresh_token: Optional[str] = None
    token_type: str
    role: str
    id: int
    email: str
    full_name: Optional[str] = None
    qr_code: Optional[str] = None
    firebase_token: Optional[str] = None  # Firebase Custom Token pour signInWithCustomToken()


class RefreshTokenRequest(BaseModel):
    refresh_token: str


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


class VerifyResetCode(BaseModel):
    email: str
    code: str


class OTPSendRequest(BaseModel):
    identifier: str   # email or phone
    method: str = "email"  # "email" or "sms"


class OTPVerifyRequest(BaseModel):
    identifier: str
    code: str


class QRVerifyRequest(BaseModel):
    qr_code: str
