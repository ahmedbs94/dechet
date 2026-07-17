"""
app/levels/definitions.py — Référentiel des paliers EcoRewind
═══════════════════════════════════════════════════════════════
Constantes Python pures : aucune DB, importables partout.

Paliers :
  1. Éco-Citoyen        →     0 pts
  2. Champion Vert      → 2 000 pts
  3. Gardien de la Terre→ 5 000 pts
  4. Héros du Recyclage →10 000 pts
  5. Ambassadeur Éco    →20 000 pts
  6. Légende Verte      →50 000 pts
"""

from dataclasses import dataclass, field
from typing import List, Optional


# ─────────────────────────────────────────────────────────────────────────────
# Structures de données
# ─────────────────────────────────────────────────────────────────────────────

@dataclass
class Advantage:
    """Un avantage lié à un palier."""
    key:         str    # identifiant machine ex: "priority_events"
    label:       str    # libellé affiché
    description: str    # explication courte


@dataclass
class ExclusiveReward:
    """Récompense exclusive débloquée une seule fois au passage d'un palier."""
    key:         str    # identifiant unique en DB ex: "badge_champion_vert"
    label:       str    # libellé affiché
    description: str    # description de la récompense
    icon:        str    # emoji ou code icône
    reward_type: str    # "badge" | "discount" | "feature" | "certificate"


@dataclass
class LevelDefinition:
    """Définition complète d'un palier."""
    rank:        int                      # 1–6
    name:        str                      # Nom du niveau
    min_points:  float                    # Score minimum pour ce palier
    icon:        str                      # Emoji représentant le niveau
    color:       str                      # Couleur hex CSS
    gradient:    List[str]                # Dégradé [from, to]
    advantages:  List[Advantage]          # Avantages permanents
    rewards:     List[ExclusiveReward]    # Récompenses débloquées à l'atteinte


# ─────────────────────────────────────────────────────────────────────────────
# Définition des 6 paliers
# ─────────────────────────────────────────────────────────────────────────────

LEVELS: List[LevelDefinition] = [

    # ── 1. Éco-Citoyen ────────────────────────────────────────────────────────
    LevelDefinition(
        rank=1,
        name="Éco-Citoyen",
        min_points=0,
        icon="🌱",
        color="#4CAF50",
        gradient=["#81C784", "#4CAF50"],
        advantages=[
            Advantage(
                key="access_app",
                label="Accès à l'application",
                description="Accès complet aux fonctionnalités de base d'EcoRewind.",
            ),
            Advantage(
                key="scan_bins",
                label="Scanner les poubelles QR",
                description="Gagnez des points à chaque tri de déchet via QR code.",
            ),
            Advantage(
                key="participate_quiz",
                label="Participer aux quiz",
                description="Testez vos connaissances et gagnez des points bonus.",
            ),
        ],
        rewards=[
            ExclusiveReward(
                key="badge_eco_citoyen",
                label="Badge Éco-Citoyen",
                description="Félicitations ! Vous avez rejoint la communauté EcoRewind.",
                icon="🌱",
                reward_type="badge",
            ),
        ],
    ),

    # ── 2. Champion Vert ──────────────────────────────────────────────────────
    LevelDefinition(
        rank=2,
        name="Champion Vert",
        min_points=2_000,
        icon="🏆",
        color="#FF9800",
        gradient=["#FFB74D", "#FF9800"],
        advantages=[
            Advantage(
                key="priority_events",
                label="Accès prioritaire aux événements",
                description="Inscrivez-vous en priorité aux ateliers et actions de quartier.",
            ),
            Advantage(
                key="double_quiz_points",
                label="Points quiz x1.25",
                description="Vos scores de quiz sont multipliés par 1.25.",
            ),
            Advantage(
                key="community_highlight",
                label="Mise en avant communautaire",
                description="Vos publications sont mises en avant dans le fil communautaire.",
            ),
        ],
        rewards=[
            ExclusiveReward(
                key="badge_champion_vert",
                label="Badge Champion Vert",
                description="Vous avez atteint 2 000 points — un vrai champion du recyclage !",
                icon="🏆",
                reward_type="badge",
            ),
            ExclusiveReward(
                key="avatar_frame_champion",
                label="Cadre d'avatar Champion",
                description="Cadre doré exclusif pour votre photo de profil.",
                icon="🖼️",
                reward_type="feature",
            ),
        ],
    ),

    # ── 3. Gardien de la Terre ────────────────────────────────────────────────
    LevelDefinition(
        rank=3,
        name="Gardien de la Terre",
        min_points=5_000,
        icon="🌍",
        color="#2196F3",
        gradient=["#64B5F6", "#2196F3"],
        advantages=[
            Advantage(
                key="discount_partners",
                label="Réductions partenaires -10%",
                description="10 % de réduction chez nos partenaires éco-responsables.",
            ),
            Advantage(
                key="advanced_impact",
                label="Rapport d'impact détaillé",
                description="Accès à vos statistiques d'impact CO₂ mensuelles avancées.",
            ),
            Advantage(
                key="mentor_badge",
                label="Statut Mentor",
                description="Devenez référent pour les nouveaux membres de votre groupe.",
            ),
        ],
        rewards=[
            ExclusiveReward(
                key="badge_gardien_terre",
                label="Badge Gardien de la Terre",
                description="5 000 points — vous protégez activement notre planète.",
                icon="🌍",
                reward_type="badge",
            ),
            ExclusiveReward(
                key="discount_card_10",
                label="Carte Réduction -10%",
                description="Coupon numérique -10% chez les commerçants partenaires EcoRewind.",
                icon="🎟️",
                reward_type="discount",
            ),
            ExclusiveReward(
                key="certificate_gardien",
                label="Certificat Gardien de la Terre",
                description="Certificat PDF officiel EcoRewind attestant votre engagement.",
                icon="📜",
                reward_type="certificate",
            ),
        ],
    ),

    # ── 4. Héros du Recyclage ─────────────────────────────────────────────────
    LevelDefinition(
        rank=4,
        name="Héros du Recyclage",
        min_points=10_000,
        icon="♻️",
        color="#9C27B0",
        gradient=["#CE93D8", "#9C27B0"],
        advantages=[
            Advantage(
                key="vip_events",
                label="Accès VIP aux événements",
                description="Invitation exclusive aux événements VIP EcoRewind.",
            ),
            Advantage(
                key="scan_bonus_x15",
                label="Bonus scan x1.5",
                description="Points de scan de poubelles multipliés par 1.5.",
            ),
            Advantage(
                key="leaderboard_highlight",
                label="Mise en avant classement",
                description="Votre profil est mis en évidence dans le classement global.",
            ),
            Advantage(
                key="early_features",
                label="Accès anticipé nouvelles fonctionnalités",
                description="Testez les nouvelles features avant tout le monde.",
            ),
        ],
        rewards=[
            ExclusiveReward(
                key="badge_heros_recyclage",
                label="Badge Héros du Recyclage",
                description="10 000 points — vous êtes un héros du recyclage !",
                icon="♻️",
                reward_type="badge",
            ),
            ExclusiveReward(
                key="avatar_frame_heros",
                label="Cadre d'avatar Héros",
                description="Cadre violet lumineux exclusif pour votre profil.",
                icon="💜",
                reward_type="feature",
            ),
            ExclusiveReward(
                key="discount_card_20",
                label="Carte Réduction -20%",
                description="Coupon numérique -20% chez tous les partenaires EcoRewind.",
                icon="🎟️",
                reward_type="discount",
            ),
        ],
    ),

    # ── 5. Ambassadeur Éco ────────────────────────────────────────────────────
    LevelDefinition(
        rank=5,
        name="Ambassadeur Éco",
        min_points=20_000,
        icon="⭐",
        color="#FF5722",
        gradient=["#FF8A65", "#FF5722"],
        advantages=[
            Advantage(
                key="ambassador_title",
                label="Titre Ambassadeur officiel",
                description="Titre officiel EcoRewind Ambassadeur sur votre profil.",
            ),
            Advantage(
                key="free_merch",
                label="Merchandising EcoRewind offert",
                description="Kit de goodies EcoRewind (sac, gourde, stickers) offert.",
            ),
            Advantage(
                key="content_boost",
                label="Boost de visibilité x2",
                description="Vos publications bénéficient d'un boost algorithmique x2.",
            ),
            Advantage(
                key="scan_bonus_x2",
                label="Bonus scan x2",
                description="Points de scan de poubelles multipliés par 2.",
            ),
        ],
        rewards=[
            ExclusiveReward(
                key="badge_ambassadeur_eco",
                label="Badge Ambassadeur Éco",
                description="20 000 points — vous représentez EcoRewind dans votre communauté.",
                icon="⭐",
                reward_type="badge",
            ),
            ExclusiveReward(
                key="certificate_ambassadeur",
                label="Certificat Ambassadeur Officiel",
                description="Certificat officiel EcoRewind Ambassadeur, avec signature numérique.",
                icon="🏅",
                reward_type="certificate",
            ),
            ExclusiveReward(
                key="discount_card_30",
                label="Carte Réduction -30%",
                description="Coupon numérique -30% exclusif Ambassadeur.",
                icon="🎟️",
                reward_type="discount",
            ),
        ],
    ),

    # ── 6. Légende Verte ──────────────────────────────────────────────────────
    LevelDefinition(
        rank=6,
        name="Légende Verte",
        min_points=50_000,
        icon="👑",
        color="#FFD700",
        gradient=["#FFF176", "#FFD700"],
        advantages=[
            Advantage(
                key="legend_title",
                label="Titre Légende Verte",
                description="Le titre suprême — vous figurez dans le Hall of Fame EcoRewind.",
            ),
            Advantage(
                key="free_premium_year",
                label="Premium EcoRewind 1 an offert",
                description="Accès premium à toutes les fonctionnalités avancées pendant 1 an.",
            ),
            Advantage(
                key="scan_bonus_x3",
                label="Bonus scan x3",
                description="Points de scan de poubelles multipliés par 3.",
            ),
            Advantage(
                key="hall_of_fame",
                label="Hall of Fame",
                description="Votre nom gravé dans le Hall of Fame EcoRewind.",
            ),
            Advantage(
                key="exclusive_nft",
                label="NFT Collectible Exclusif",
                description="NFT numérique unique certifiant votre statut Légende Verte.",
            ),
        ],
        rewards=[
            ExclusiveReward(
                key="badge_legende_verte",
                label="Badge Légende Verte",
                description="50 000 points — vous êtes une Légende Verte EcoRewind !",
                icon="👑",
                reward_type="badge",
            ),
            ExclusiveReward(
                key="avatar_frame_legende",
                label="Cadre d'avatar Légendaire",
                description="Cadre doré animé ultra-exclusif pour les Légendes.",
                icon="✨",
                reward_type="feature",
            ),
            ExclusiveReward(
                key="certificate_legende",
                label="Certificat Légende Verte",
                description="Certificat officiel de rang suprême, signé par EcoRewind.",
                icon="🏆",
                reward_type="certificate",
            ),
            ExclusiveReward(
                key="discount_card_50",
                label="Carte Réduction -50%",
                description="Coupon numérique -50% permanent chez tous les partenaires.",
                icon="🎟️",
                reward_type="discount",
            ),
        ],
    ),
]


# ─────────────────────────────────────────────────────────────────────────────
# Helpers d'accès rapide
# ─────────────────────────────────────────────────────────────────────────────

# Index par rank pour O(1)
LEVELS_BY_RANK: dict = {lvl.rank: lvl for lvl in LEVELS}

# Index de toutes les récompenses par key
ALL_REWARDS_BY_KEY: dict = {
    reward.key: reward
    for lvl in LEVELS
    for reward in lvl.rewards
}
