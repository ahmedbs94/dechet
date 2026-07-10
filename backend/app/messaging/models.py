"""
app/messaging/models.py — Modèles SQLAlchemy pour la messagerie inter-rôles
===========================================================================
Tables :
  messages               → Message entre deux utilisateurs (ou broadcast groupe)
  message_group_recipients → Destinataires d'un message de groupe
"""
from sqlalchemy import (
    Column, Integer, String, Text, Boolean,
    DateTime, ForeignKey, Index
)
from sqlalchemy.orm import relationship
from datetime import datetime
from app.base import Base


class Message(Base):
    """
    Message entre acteurs.
    - Si receiver_id est renseigné → message 1-à-1
    - Si group_id est renseigné   → message à un groupe de citoyens (éducateur → groupe)
    - Si is_group_broadcast=True  → message broadcast à plusieurs collecteurs
      (les destinataires sont dans MessageGroupRecipient)
    """
    __tablename__ = "messages"

    id = Column(Integer, primary_key=True, index=True)

    # Expéditeur
    sender_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"),
                       nullable=False, index=True)

    # Destinataire (1-à-1)
    receiver_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"),
                         nullable=True, index=True)

    # Groupe de citoyens (éducateur → groupe)
    group_id = Column(Integer, ForeignKey("citizen_groups.id", ondelete="SET NULL"),
                      nullable=True, index=True)

    # Broadcast collecteurs (intercommunalité → plusieurs collecteurs)
    # True quand le message est envoyé à plusieurs destinataires via MessageGroupRecipient
    is_group_broadcast = Column(Boolean, default=False, nullable=False)

    # Libellé optionnel du groupe de collecteurs (ex: "Zone Nord")
    collector_group_label = Column(String, nullable=True)

    # Contenu du message
    content = Column(Text, nullable=False)

    # Réponse à un message parent
    parent_id = Column(Integer, ForeignKey("messages.id", ondelete="SET NULL"),
                       nullable=True)

    # Lu par le destinataire (pour messages 1-à-1)
    is_read = Column(Boolean, default=False, nullable=False)

    created_at = Column(DateTime, default=datetime.utcnow, index=True)

    # Relations
    sender   = relationship("User", foreign_keys=[sender_id])
    receiver = relationship("User", foreign_keys=[receiver_id])
    parent   = relationship("Message", remote_side=[id])
    group_recipients = relationship(
        "MessageGroupRecipient", back_populates="message",
        cascade="all, delete-orphan"
    )

    __table_args__ = (
        Index("ix_messages_sender_receiver", "sender_id", "receiver_id"),
        Index("ix_messages_created_at", "created_at"),
    )


class MessageGroupRecipient(Base):
    """
    Destinataires individuels d'un message de groupe.
    Créé pour chaque destinataire lors d'un broadcast.
    """
    __tablename__ = "message_group_recipients"

    id         = Column(Integer, primary_key=True, index=True)
    message_id = Column(Integer, ForeignKey("messages.id", ondelete="CASCADE"),
                        nullable=False, index=True)
    user_id    = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"),
                        nullable=False, index=True)
    is_read    = Column(Boolean, default=False, nullable=False)

    message = relationship("Message", back_populates="group_recipients")
    user    = relationship("User")
