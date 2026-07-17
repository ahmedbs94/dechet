"""
app/levels/models.py — Table PostgreSQL : user_rewards
═══════════════════════════════════════════════════════
Persiste chaque récompense exclusive débloquée par un utilisateur.
Une ligne = un utilisateur a débloqué une récompense à une date précise.

Contrainte d'unicité sur (user_id, reward_key) : impossible de débloquer
deux fois la même récompense.
"""

from datetime import datetime
from sqlalchemy import (
    Boolean, Column, DateTime, ForeignKey,
    Integer, String, UniqueConstraint,
)
from sqlalchemy.orm import relationship
from app.base import Base


class UserReward(Base):
    """Récompense exclusive débloquée par un utilisateur."""

    __tablename__ = "user_rewards"

    __table_args__ = (
        # Empêche le double-déblocage d'une même récompense
        UniqueConstraint("user_id", "reward_key", name="uq_user_rewards_user_reward"),
    )

    id          = Column(Integer, primary_key=True, index=True)
    user_id     = Column(
        Integer,
        ForeignKey("users.id", ondelete="CASCADE"),
        nullable=False,
        index=True,
    )
    reward_key  = Column(String, nullable=False, index=True)
    # Type de récompense : "badge" | "discount" | "feature" | "certificate"
    reward_type = Column(String, nullable=False, default="badge")
    label       = Column(String, nullable=False)
    description = Column(String, nullable=True)
    icon        = Column(String, nullable=True)
    unlocked_at = Column(DateTime, default=datetime.utcnow, nullable=False)
    # True une fois la notification push envoyée à l'utilisateur
    notified    = Column(Boolean, default=False, nullable=False)

    # Relation optionnelle (lazy) pour jointures futures
    user = relationship("User", back_populates="rewards", lazy="noload")
