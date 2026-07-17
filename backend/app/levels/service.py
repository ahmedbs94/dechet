"""
app/levels/service.py — Service métier : Niveaux & Récompenses
═══════════════════════════════════════════════════════════════════
Expose des fonctions pures (calcul de niveau) et des fonctions avec DB
(déblocage de récompenses).

Fonctions principales :
  get_level_for_score(score)          → LevelDefinition du palier actuel
  get_next_level(score)               → LevelDefinition suivant ou None
  get_progress_percent(score)         → float 0–100
  build_level_response(user, score, db) → dict complet pour l'API
  check_and_unlock_rewards(user, score, db) → liste de UserReward créées
"""

from __future__ import annotations

from typing import List, Optional, TYPE_CHECKING
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from app.levels.definitions import LEVELS, LevelDefinition, ALL_REWARDS_BY_KEY
from app.levels.models import UserReward

if TYPE_CHECKING:
    from app.users.models import User


# ─────────────────────────────────────────────────────────────────────────────
# 1. Fonctions pures (sans accès DB)
# ─────────────────────────────────────────────────────────────────────────────

def get_level_for_score(score: float) -> LevelDefinition:
    """
    Retourne le palier correspondant au score donné.
    Toujours au moins le niveau 1 (Éco-Citoyen, 0 pts).
    """
    current = LEVELS[0]
    for lvl in LEVELS:
        if score >= lvl.min_points:
            current = lvl
    return current


def get_next_level(score: float) -> Optional[LevelDefinition]:
    """
    Retourne le prochain palier à atteindre, ou None si déjà au maximum.
    """
    for lvl in LEVELS:
        if lvl.min_points > score:
            return lvl
    return None


def get_progress_percent(score: float) -> float:
    """
    Calcule le pourcentage de progression entre le palier actuel et le suivant.
    Retourne 100.0 si l'utilisateur est au niveau maximum.

    Exemple :
      score=3250, palier actuel=2000, prochain=5000
      → (3250-2000) / (5000-2000) * 100 = 41.67 %
    """
    current = get_level_for_score(score)
    next_lvl = get_next_level(score)

    if next_lvl is None:
        return 100.0

    span = next_lvl.min_points - current.min_points
    if span <= 0:
        return 100.0

    done = score - current.min_points
    return round(min(100.0, max(0.0, done / span * 100)), 2)


def get_scan_multiplier(score: float) -> float:
    """
    Retourne le multiplicateur de points de scan selon le niveau actuel.
    """
    level = get_level_for_score(score)
    multipliers = {1: 1.0, 2: 1.0, 3: 1.0, 4: 1.5, 5: 2.0, 6: 3.0}
    return multipliers.get(level.rank, 1.0)


def get_quiz_multiplier(score: float) -> float:
    """
    Retourne le multiplicateur de points de quiz selon le niveau actuel.
    """
    level = get_level_for_score(score)
    multipliers = {1: 1.0, 2: 1.25, 3: 1.25, 4: 1.25, 5: 1.25, 6: 1.25}
    return multipliers.get(level.rank, 1.0)


# ─────────────────────────────────────────────────────────────────────────────
# 2. Fonctions avec DB (PostgreSQL)
# ─────────────────────────────────────────────────────────────────────────────

def _get_already_unlocked_keys(user_id: int, db: Session) -> set:
    """Retourne l'ensemble des reward_key déjà enregistrés pour cet utilisateur."""
    rows = (
        db.query(UserReward.reward_key)
        .filter(UserReward.user_id == user_id)
        .all()
    )
    return {r.reward_key for r in rows}


def check_and_unlock_rewards(
    user_id: int,
    score: float,
    db: Session,
) -> List[UserReward]:
    """
    Compare les récompenses dues (selon le score) avec celles déjà en DB.
    Insère en PostgreSQL les nouvelles récompenses et les retourne.

    La contrainte UNIQUE (user_id, reward_key) garantit l'idempotence
    même en cas d'appel concurrent.
    """
    already_unlocked = _get_already_unlocked_keys(user_id, db)

    # Toutes les récompenses dues à ce score
    due_rewards = []
    for lvl in LEVELS:
        if score >= lvl.min_points:
            for reward in lvl.rewards:
                if reward.key not in already_unlocked:
                    due_rewards.append(reward)

    if not due_rewards:
        return []

    new_user_rewards: List[UserReward] = []
    for reward in due_rewards:
        ur = UserReward(
            user_id     = user_id,
            reward_key  = reward.key,
            reward_type = reward.reward_type,
            label       = reward.label,
            description = reward.description,
            icon        = reward.icon,
            notified    = False,
        )
        db.add(ur)
        new_user_rewards.append(ur)

    try:
        db.commit()
        for ur in new_user_rewards:
            db.refresh(ur)
    except IntegrityError:
        # Race condition : une autre requête a inséré en même temps → safe
        db.rollback()
        new_user_rewards = []

    return new_user_rewards


def get_all_user_rewards(user_id: int, db: Session) -> List[UserReward]:
    """Retourne toutes les récompenses débloquées par l'utilisateur, ordre chronologique."""
    return (
        db.query(UserReward)
        .filter(UserReward.user_id == user_id)
        .order_by(UserReward.unlocked_at.asc())
        .all()
    )


# ─────────────────────────────────────────────────────────────────────────────
# 3. Builder de réponse API
# ─────────────────────────────────────────────────────────────────────────────

def build_level_response(user_id: int, score: float, db: Session) -> dict:
    """
    Construit le dictionnaire de réponse complet pour GET /users/me/level.
    Déclenche aussi le déblocage des nouvelles récompenses si nécessaire.
    """
    current   = get_level_for_score(score)
    next_lvl  = get_next_level(score)
    progress  = get_progress_percent(score)
    pts_next  = round(next_lvl.min_points - score, 2) if next_lvl else 0.0

    # Déblocage automatique des récompenses non encore enregistrées
    newly_unlocked = check_and_unlock_rewards(user_id, score, db)

    # Toutes les récompenses débloquées (pour affichage)
    all_rewards = get_all_user_rewards(user_id, db)

    def _lvl_dict(lvl: LevelDefinition) -> dict:
        return {
            "rank":       lvl.rank,
            "name":       lvl.name,
            "icon":       lvl.icon,
            "color":      lvl.color,
            "gradient":   lvl.gradient,
            "min_points": lvl.min_points,
        }

    def _reward_dict(ur: UserReward) -> dict:
        return {
            "reward_key":   ur.reward_key,
            "reward_type":  ur.reward_type,
            "label":        ur.label,
            "description":  ur.description,
            "icon":         ur.icon,
            "unlocked_at":  ur.unlocked_at.isoformat() if ur.unlocked_at else None,
            "is_new":       ur in newly_unlocked,
        }

    return {
        "score":              score,
        "current_level":      _lvl_dict(current),
        "next_level":         _lvl_dict(next_lvl) if next_lvl else None,
        "progress_percent":   progress,
        "points_to_next":     pts_next,
        "scan_multiplier":    get_scan_multiplier(score),
        "quiz_multiplier":    get_quiz_multiplier(score),
        "advantages": [
            {
                "key":         adv.key,
                "label":       adv.label,
                "description": adv.description,
            }
            for adv in current.advantages
        ],
        "unlocked_rewards":   [_reward_dict(ur) for ur in all_rewards],
        "newly_unlocked":     [_reward_dict(ur) for ur in newly_unlocked],
    }
