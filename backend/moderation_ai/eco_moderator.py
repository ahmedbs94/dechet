"""
EcoRewind -- CNN Moderator (Text CNN + ResNet18)
================================================
Remplace/complète ai_moderator.py avec des modèles CNN
entraînés spécifiquement sur les publications citoyennes EcoRewind.

Pipeline complet :
  Couche 0 : Règles (mots-clés FR/AR/EN)        -- toujours actif, < 1ms
  Couche 1 : Text CNN (EcoTextCNN)               -- ~5ms, CPU
  Couche 2 : ResNet18 fine-tuné (image)          -- ~20ms, CPU
  Couche 3 : NudeNet (NSFW images)               -- ~100ms (optionnel)

Seuils de décision CNN :
  P(toxic)    ≥ 0.50 → REJECTED
  P(eco)      ≥ 0.60 → PUBLISHED
  P(off_topic)≥ 0.55 → PENDING_REVIEW
  else               → PENDING_REVIEW (précaution)
"""

import os
import sys
import time
import json
from typing import Optional

# ── Résolution path backend ───────────────────────────────────────────────────
# __file__ = backend/moderation_ai/eco_moderator.py
# _BACKEND  = backend/   (remonter d'un niveau depuis moderation_ai/)
_BACKEND = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, _BACKEND)

from services.ai_moderator import (
    AIModerator, ModerationResult, ModerationStatus,
    SAFE_THRESHOLD, REVIEW_THRESHOLD,
)

# ── Seuils CNN ────────────────────────────────────────────────────────────────
CNN_ECO_THRESHOLD      = 0.45   # -> publie (seuil abaisse pour eco dominant)
CNN_OFFTOPIC_THRESHOLD = 0.55   # -> REJETE si image hors-sujet (vetements, maquillage, violence...)
CNN_TOXIC_THRESHOLD    = 0.50   # -> rejete (texte)
CNN_NSFW_THRESHOLD     = 0.45   # -> rejete (contenu violent/NSFW detecte par ResNet18)


class EcoCNNModerator(AIModerator):
    """
    Moderator augmenté avec Text CNN + ResNet18 entraînés sur mesure.

    Hérite de AIModerator (règles + Detoxify + CLIP + NudeNet)
    et ajoute les couches CNN custom en remplacement/complément.
    """

    def __init__(self, rules_only: bool = False):
        # Initialise les couches règles (+ optionnellement les modèles pré-entraînés)
        super().__init__(rules_only=rules_only)
        self._text_cnn   = None
        self._img_resnet = None
        self._cnn_ready  = False
        if not rules_only:
            self._load_cnn_models()

    def _load_cnn_models(self):
        """Charge Text CNN et ResNet18 (silencieux si pas encore entraînés)."""
        # ── Text CNN ─────────────────────────────────────────────────────────
        try:
            from moderation_ai.text_cnn_model import TextCNNClassifier
            self._text_cnn = TextCNNClassifier()
            self._cnn_ready = True
            print("[CNN] [OK] Text CNN (EcoTextCNN) chargé")
        except FileNotFoundError:
            print("[CNN] [WARN]  Text CNN non trouvé -- lancez train_text_cnn.py")
        except Exception as e:
            print(f"[CNN] [ERR] Erreur Text CNN : {e}")

        # ── ResNet18 ─────────────────────────────────────────────────────────
        try:
            from moderation_ai.image_resnet_model import ImageResNetClassifier
            self._img_resnet = ImageResNetClassifier()
            self._cnn_ready  = True
            print("[CNN] [OK] ResNet18 (image eco-classifier) chargé")
        except FileNotFoundError:
            print("[CNN] [WARN]  ResNet18 non trouvé -- lancez train_image_resnet.py")
        except Exception as e:
            print(f"[CNN] [ERR] Erreur ResNet18 : {e}")

    # ── Analyse texte enrichie ────────────────────────────────────────────────

    def analyze_text(self, text: str) -> dict:
        """
        Couche 0 (règles) + Couche 1 (Text CNN) fusionnées.
        Le score CNN prime sur le score règles si le modèle est disponible.
        Les salutations courtes ne sont jamais pénalisées par le CNN.
        """
        result = super().analyze_text(text)   # Règles + Detoxify + XLM-RoBERTa

        if self._text_cnn and text and text.strip():
            try:
                probs = self._text_cnn.predict(text)
                result["categories"]["cnn_text"] = {
                    **probs,
                    "description": "Text CNN (EcoTextCNN entraîné sur publications citoyennes)",
                }
                result["cnn_probs"] = probs
                result["ml_used"]   = True

                # ── Détection salutation (protection contre faux positif CNN) ─
                # Les salutations courtes comme "Salam les amis", "Bonjour !"
                # ne doivent jamais être classées off_topic par le CNN.
                import re, unicodedata
                _norm_t = unicodedata.normalize("NFKD", text.lower().strip())
                _norm_t = "".join(c for c in _norm_t if not unicodedata.combining(c))
                _tokens = set(re.findall(r'\b\w+\b', _norm_t))
                _GREET = {"bonjour", "bonsoir", "salut", "salam", "hello",
                          "hi", "hey", "marhaba", "ahlan", "coucou"}
                _is_greeting = bool(_tokens & _GREET) and len(_tokens) <= 10
                _profanity_sc = result.get("categories", {}).get("profanity", {}).get("score", 0.0)

                # ── Ajustement du score final via CNN ─────────────────────────
                if probs["toxic"] >= CNN_TOXIC_THRESHOLD:
                    # CNN détecte du contenu toxique → forcer score élevé
                    result["score"] = max(result["score"], 0.70)
                    result["cnn_decision"] = "toxic"

                elif probs["eco"] >= CNN_ECO_THRESHOLD:
                    # CNN détecte du contenu éco → alléger le score
                    result["score"] = min(result["score"], 0.20)
                    result["cnn_decision"] = "eco"

                elif probs["off_topic"] >= CNN_OFFTOPIC_THRESHOLD:
                    if _is_greeting and _profanity_sc == 0.0:
                        # Salutation courte classée off_topic par le CNN → ignorer
                        result["cnn_decision"] = "greeting"
                    else:
                        # Vrai hors-sujet → pousser vers pending_review
                        result["score"] = max(result["score"], SAFE_THRESHOLD + 0.05)
                        result["cnn_decision"] = "off_topic"

                else:
                    result["cnn_decision"] = "uncertain"

            except Exception as e:
                print(f"[CNN] [WARN]  Erreur Text CNN inférence : {e}")

        return result

    # ── Analyse image enrichie ────────────────────────────────────────────────

    def analyze_image(self, image_path: str) -> dict:
        """
        Couche NudeNet (héritée) + Couche 2 (ResNet18 custom) fusionnées.
        """
        result = super().analyze_image(image_path)   # NudeNet + CLIP

        if self._img_resnet and image_path and os.path.exists(image_path):
            try:
                probs = self._img_resnet.predict(image_path)
                result["categories"]["resnet_image"] = {
                    **probs,
                    "description": "ResNet18 fine-tuné (eco/off_topic/nsfw)",
                }
                result["resnet_probs"] = probs
                result["ml_used"]      = True

                # ── Ajustement du score image via ResNet18 (logique argmax) ──────────
                eco_p  = probs.get("eco", 0)
                off_p  = probs.get("off_topic", 0)
                nsfw_p = probs.get("nsfw", 0)

                # Priorité 1 : NSFW → rejet immédiat (indépendant des autres)
                if nsfw_p >= CNN_NSFW_THRESHOLD:
                    result["score"] = 0.95
                    result["resnet_decision"] = "nsfw"
                    result["categories"]["nsfw"] = {
                        "score": nsfw_p, "severity": "high", "source": "ResNet18-CNN",
                    }

                # Priorité 2 : Eco dominant (argmax) → lever les pénalités
                # FIX: vérifie que eco EST la classe majoritaire, pas juste un seuil absolu
                elif eco_p >= off_p and eco_p >= CNN_ECO_THRESHOLD:
                    result["score"] = min(result["score"], 0.15)
                    result["resnet_decision"] = "eco"

                # Priorité 3 : Off-topic clairement dominant ET au-dessus du seuil relevé
                elif off_p >= CNN_OFFTOPIC_THRESHOLD and off_p > eco_p:
                    result["score"] = max(result["score"], 0.45)
                    result["resnet_decision"] = "off_topic"
                    result["categories"]["off_topic_image"] = {
                        "score": off_p, "severity": "medium",
                        "source": "ResNet18-CNN",
                        "description": "Image hors-sujet detectable (en attente validation admin)",
                    }

                # Cas incertain
                else:
                    if eco_p < 0.40:
                        result["score"] = max(result["score"], SAFE_THRESHOLD + 0.05)
                    result["resnet_decision"] = "uncertain"

            except Exception as e:
                print(f"[CNN] [WARN]  Erreur ResNet18 inférence : {e}")

        return result

    # ── Pipeline final : correction CNN éco ──────────────────────────────────

    def moderate(self, text: str = "", image_local_path: str = "") -> "ModerationResult":
        """
        Override de AIModerator.moderate() :
        Corrige les faux positifs quand ResNet18 ou EcoTextCNN confirme
        un contenu éco-pertinent, annulant les pénalités de contexte.

        Règles métier :
          Cas 1 : Image éco + salutation (bonjour, salam...) → PUBLISHED
          Cas 2 : Image pollution/déchets + texte encourageant (conseils, sensibilisation) → PUBLISHED
          Hors sujet (ni tri, ni propreté, ni sensibilisation pollution) → PENDING_REVIEW (admin)
        """
        import time
        t0 = time.time()

        # Exécuter le pipeline parent (règles + Detoxify + scoring de base)
        result = super().moderate(text=text, image_local_path=image_local_path)

        # ── GARDE CRITIQUE : respect de la décision parente forte ────────────
        # Si le parent a signalé pending_review avec un score élevé (>= 0.50),
        # le CNN NE PEUT PAS améliorer le statut vers "published".
        # Le CNN peut uniquement maintenir ou aggraver la décision parente.
        # Cela empêche les faux positifs CNN d'annuler une détection correcte
        # du pipeline parent (règles + Detoxify).
        _parent_status = result.status
        _parent_score  = result.score
        _parent_is_strict_pending = (
            _parent_status == ModerationStatus.PENDING_REVIEW.value
            and _parent_score >= 0.50
        )

        # ── Récupérer les décisions CNN ───────────────────────────────────────
        cnn_text_decision = result.text_analysis.get("cnn_decision", "uncertain")
        cnn_img_decision  = result.image_analysis.get("resnet_decision", "uncertain")
        cnn_text_probs    = result.text_analysis.get("cnn_probs", {})
        cnn_img_probs     = result.image_analysis.get("resnet_probs", {})

        toxic_txt = cnn_text_probs.get("toxic", 0.0)
        nsfw_img  = cnn_img_probs.get("nsfw",  0.0)
        off_img   = cnn_img_probs.get("off_topic", 0.0)
        eco_img   = cnn_img_probs.get("eco",   0.0)

        # ── NSFW image : verdict IA = rejected ──────────────────────────────
        # Note : ce statut est le VERDICT DU MODÈLE IA.
        # La politique finale (posts.py) le reclasse en 'pending_review'
        # pour arbitrage admin. L'IA ne décide jamais la sanction finale.
        if cnn_img_decision == "nsfw":
            result.score  = 0.95
            result.status = ModerationStatus.REJECTED.value
            result.processing_time_ms = round((time.time() - t0) * 1000, 2)
            return result

        # ── Texte toxique confirmé : verdict IA = rejected ─────────────────────
        # Si le TextCNN classe le texte comme toxique ET que Detoxify confirme
        # (toxicity > 0.5), le modèle recommande le rejet. La décision finale
        # reste à l'admin (posts.py reclasse ce statut en 'pending_review').
        # Ex: "Vous êtes des connards et des salopes" → verdict IA : rejected
        ml_toxicity = result.text_analysis.get("categories", {}).get("ml_toxicity", {})
        detoxify_tox = ml_toxicity.get("toxicity", 0.0)
        profanity_sc = result.text_analysis.get("categories", {}).get("profanity", {}).get("score", 0.0)
        if (
            (cnn_text_decision == "toxic" and toxic_txt >= CNN_TOXIC_THRESHOLD)
            or (profanity_sc >= 0.70 and detoxify_tox > 0.4)
            or (detoxify_tox > 0.7)
        ):
            result.score  = max(result.score, 0.80)
            result.status = ModerationStatus.REJECTED.value
            if "Contenu toxique auto-rejete" not in str(result.reasons):
                result.reasons.append("Contenu toxique auto-rejete (profanite + IA)")
            result.processing_time_ms = round((time.time() - t0) * 1000, 2)
            return result

        # ── Rescue salutation simple ──────────────────────────────────────
        # Si le texte est une salutation courte et propre (pas de profanite,
        # pas d'anti-env), on le publie directement quel que soit le score parent.
        # MAIS : seulement si l'image n'est pas hors-sujet par ResNet18.
        # Ex: "Salam les amis" + photo de recyclage -> PUBLISHED
        # Ex: "Bonjour" + photo de moto -> PENDING_REVIEW (image hors sujet)
        from services.ai_moderator import _normalize as _norm, _tokenize as _tok
        norm_text_full = _norm(text or "")
        text_tokens = set(_tok(text or ""))
        _GREETINGS_SET = {
            "bonjour", "bonsoir", "salut", "salam", "hello",
            "hi", "hey", "marhaba", "ahlan", "coucou",
        }
        _has_greeting = bool(text_tokens & _GREETINGS_SET)
        _text_clean = (
            result.text_analysis.get("categories", {}).get("profanity", {}).get("score", 0.0) == 0.0
            and result.text_analysis.get("categories", {}).get("anti_environmental", {}).get("score", 0.0) == 0.0
        )
        # Une image est considérée hors-sujet si :
        #   - explicitement classée off_topic PAR LE CNN
        #   - classée "eco" mais avec faible confiance (< 0.60) → ResNet incertain
        #   - classée autre chose que eco et eco_img < 0.40
        # IMPORTANT : si aucune image n'a été fournie, on ne pénalise PAS.
        #   Une salutation ou un texte éco sans image est un contenu légitime.
        _has_image = bool(image_local_path and os.path.exists(image_local_path))
        image_is_clearly_eco = (_has_image and cnn_img_decision == "eco" and eco_img >= 0.60)
        image_is_off_topic = (
            _has_image and (
                cnn_img_decision == "off_topic"
                or (cnn_img_decision == "eco" and eco_img < 0.60)   # eco mais peu confiant
                or (cnn_img_decision not in ("eco",) and self._img_resnet is not None and eco_img < 0.40)
            )
        )
        if _has_greeting and len(text_tokens) <= 10 and _text_clean and toxic_txt < CNN_TOXIC_THRESHOLD:
            if image_is_off_topic:
                # Image présente mais hors-sujet → ne pas publier automatiquement
                result.score  = max(result.score, 0.45)
                result.status = ModerationStatus.PENDING_REVIEW.value
                off_img_reason = "Salutation avec image hors sujet : publication envoyee a l'administrateur pour validation"
                if off_img_reason not in result.reasons:
                    result.reasons.append(off_img_reason)
                result.processing_time_ms = round((time.time() - t0) * 1000, 2)
                return result
            # Salutation propre (avec ou sans image éco) → publié directement
            result.score  = min(result.score, 0.10)
            result.status = ModerationStatus.PUBLISHED.value
            result.reasons = [r for r in result.reasons if "précaution" not in r.lower()]
            result.processing_time_ms = round((time.time() - t0) * 1000, 2)
            return result


        # --- Racines d'ACTION éco (nettoyage, recyclage, protection...) ---
        _ECO_ACTION_STEMS = [
            # Nettoyage / ramassage
            "nettoy", "ramass", "depollut", "depollu",
            # Recyclage / tri
            "recycl", "trier", "trions", "tri selectif", "tri des",
            "compost",
            # Protection / préservation
            "proteg", "preserv", "sauvegard",
            # Plantation / reboisement
            "plant", "rebois", "reforest",
            # Mobilisation / appels à l'action
            "agissons", "mobilisons", "mobilisez", "engageons",
            "venez", "rejoignez", "participez",
            # Verbes d'arrêt / lutte
            "doit cesser", "arretons", "luttons", "combattons",
            "stop a la",
            # Propreté
            "proprete",
            # Réduction / réutilisation
            "reduire", "reutilis", "zero dechet",
            # Énergie renouvelable
            "solaire", "eolien", "panneau",
        ]

        # --- Racines de CONSEIL / ENCOURAGEMENT / SENSIBILISATION ---
        # Textes comme "Pensez à trier", "Ensemble protégeons la nature",
        # "Saviez-vous que le plastique met 400 ans à se dégrader ?",
        # "Chaque geste compte", "Faisons la différence"
        _ECO_ADVICE_STEMS = [
            # Conseils / astuces
            "conseil", "astuce", "rappel", "recommand",
            "saviez-vous", "le saviez-vous", "saviez vous",
            "penser a", "pensez a", "n oubliez pas", "oubliez pas",
            "il faut", "il est important", "important de",
            "bonne pratique", "bonnes pratiques",
            # Encouragement collectif
            "ensemble", "tous ensemble", "chacun de nous",
            "chaque geste", "petit geste", "chaque action",
            "faisons", "faites", "contribu",  # contribuer, contribution...
            "effort", "difference", "changement",
            # Sensibilisation / impact
            "sensibilis",  # sensibiliser, sensibilisation...
            "conscien",    # conscience, consciencieux...
            "impact", "consequence", "degradation",
            "danger", "menace", "risque",
            "avenir", "futur", "generation", "enfants",
            "planete", "terre", "climat",
            # Verbes d'encouragement
            "encourag", "motiv", "inspir",  # encourager, motiver, inspirer...
            "respecter", "respect", "prendre soin",
            "adopter", "adoptons", "adoptez",
            "eviter", "evitons", "evitez",
            # Partage / communauté
            "partag", "communaute", "citoyen", "responsab",
            "engagement", "engag",
            # Termes de tri / propreté / environnement (contexte positif)
            "poubelle", "conteneur", "bac de tri", "point de collecte",
            "dechets", "dechet", "ordure", "plastique", "verre",
            "papier", "carton", "ecologi", "environnement",
            "nature", "biodiversite", "pollution", "pollu",
            # ── Adjectifs et descriptions éco ─────────────────────────────────
            # Couleur verte / verdure (ex: "une Tunisie verte", "ville verte")
            "vert", "verte", "verts", "vertes", "verdur", "verdoy",
            # Propreté (ex: "une ville propre", "gardons notre pays propre")
            "propre", "propret",
            # Beauté naturelle (ex: "belle nature", "magnifique paysage")
            "beaute", "beau", "belle", "magnifique", "splendide",
            "paysage", "paysag",
            # Aspirations territoriales (ex: "une Tunisie verte", "un pays vert")
            "tunisie", "algerie", "maroc", "pays",  # contexte local fréquent
            "ville", "region", "quartier",           # espaces verts urbains
            # Nature / faune / flore
            "foret", "arbr", "fleur", "prairie", "montagne",
            "mer", "ocean", "lac", "riviere",
            "oiseau", "faune", "flore",
            # Énergie et durabilité
            "durable", "durabilit", "renouvelab",
            "ecologique", "ecolo",
        ]

        text_promotes_action = any(
            stem in norm_text_full for stem in _ECO_ACTION_STEMS
        )
        text_has_eco_advice = any(
            stem in norm_text_full for stem in _ECO_ADVICE_STEMS
        )
        # Le texte est "éco-pertinent" s'il promeut une action OU donne un conseil/encouragement
        text_is_eco_relevant = text_promotes_action or text_has_eco_advice


        # --- Détection salutation ---
        GREETINGS = {
            "bonjour", "bonsoir", "salut", "salam", "hello",
            "hi", "hey", "marhaba", "ahlan", "coucou",
            "bonne journee", "bonne soiree",
        }
        has_greeting = bool(text_tokens & GREETINGS)

        # Gardes de sécurité : pas de contenu toxique ni NSFW
        is_safe_text  = toxic_txt < CNN_TOXIC_THRESHOLD
        is_safe_image = nsfw_img  < CNN_NSFW_THRESHOLD

        # ══════════════════════════════════════════════════════════════════════
        # CAS 1 : Image éco + salutation → PUBLISHED directement
        # ══════════════════════════════════════════════════════════════════════
        # Ex: Photo de nature/recyclage/nettoyage + "Bonjour !" ou "Salam"
        # L'image en elle-même est en lien avec le contexte éco, la salutation
        # montre un citoyen engagé qui partage → accepté.
        if (
            cnn_img_decision == "eco"
            and eco_img > off_img          # eco EST dominant
            and eco_img >= 0.60           # éco clairement majoritaire (seuil durci anti-faux positifs)
            and has_greeting
            and is_safe_text
            and is_safe_image
        ):
            result.reasons = [
                r for r in result.reasons
                if "sans contexte environnemental" not in r
                and "hors sujet" not in r.lower()
                and "sans action eco" not in r.lower()
            ]
            result.score  = min(result.score, 0.15)
            result.status = ModerationStatus.PUBLISHED.value
            result.processing_time_ms = round((time.time() - t0) * 1000, 2)
            return result

        # ══════════════════════════════════════════════════════════════════════
        # CAS 2 : Image pollution/déchets + texte encourageant → PUBLISHED
        # ══════════════════════════════════════════════════════════════════════
        # Ex: Photo de déchets dans la nature + "Protégeons notre environnement,
        #     pensez à trier vos déchets !"
        # L'image montre une situation négative MAIS le texte encourage à agir.
        # Cela inclut :
        #   - Verbes d'action (nettoyons, recyclons, protégeons...)
        #   - Conseils (pensez à, n'oubliez pas, chaque geste compte...)
        #   - Sensibilisation (saviez-vous que, impact, conséquences...)
        if cnn_img_decision in ("off_topic", "eco") and text_is_eco_relevant:
            if is_safe_text and is_safe_image:
                result.reasons = [
                    r for r in result.reasons
                    if "sans contexte environnemental" not in r
                    and "hors sujet" not in r.lower()
                    and "sans action eco" not in r.lower()
                    and "contenu potentiellement inapproprie" not in r.lower()
                ]
                result.score  = min(result.score, 0.20)
                result.status = ModerationStatus.PUBLISHED.value
                result.processing_time_ms = round((time.time() - t0) * 1000, 2)
                return result

        # ══════════════════════════════════════════════════════════════════════
        # CAS 3 : Image off_topic SANS texte éco → PENDING_REVIEW (admin)
        # ══════════════════════════════════════════════════════════════════════
        # Le contenu n'encourage pas le tri, la propreté ou la sensibilisation.
        # Il est envoyé à l'administrateur pour validation manuelle.
        if cnn_img_decision == "off_topic":
            result.score  = max(result.score, 0.45)
            result.status = ModerationStatus.PENDING_REVIEW.value
            off_reason = "Contenu hors sujet : publication non liee au tri, a la proprete ou a la sensibilisation environnementale (envoyee a l'administrateur)"
            if off_reason not in result.reasons:
                result.reasons.append(off_reason)
            result.processing_time_ms = round((time.time() - t0) * 1000, 2)
            return result

        # ══════════════════════════════════════════════════════════════════════
        # CAS 4 : Image éco + texte sans mots-clés éco → PUBLISHED si texte neutre
        # ══════════════════════════════════════════════════════════════════════
        # PRINCIPE : on punit le NÉGATIF, pas l'absence de vocabulaire éco.
        # Une photo de nature + texte neutre/positif = contenu légitime.
        # On envoie en pending si :
        #   - texte commercial/spam ("achetez", "prix", "livraison"...)
        #   - CNN texte dit "off_topic" (le modèle détecte du hors-sujet)
        #   - signaux anti-environnementaux explicites
        # Ex PUBLIÉ   : nature + "une Tunisie verte"  → pas de signaux négatifs
        # Ex PUBLIÉ   : nature + "magnifique !"       → neutre
        # Ex PENDING  : nature + "achetez chez nous" → commercial détecté
        if cnn_img_decision == "eco" and not text_is_eco_relevant and not has_greeting:
            anti_env_score = result.text_analysis.get("categories", {}).get(
                "anti_environmental", {}
            ).get("score", 0.0)

            # ── Détection de contenu commercial/spam ─────────────────────────
            _COMMERCIAL_STEMS = [
                "achetez", "achet", "vente", "vend", "vendez",
                "promotion", "promo", "solde", "offre speciale",
                "prix", "livraison", "commandez", "commander",
                "boutique", "magasin", "shop", "buy", "sell",
                "discount", "reduction", "euro", "dinar", "tnd",
                "cod", "delivery", "together for better",
                "gratuit", "cadeau", "gagnez", "gagner",
            ]
            is_commercial = any(stem in norm_text_full for stem in _COMMERCIAL_STEMS)

            # ── Texte clairement hors-sujet selon le CNN texte ───────────────
            text_cnn_is_offtopic = (cnn_text_decision == "off_topic")

            # ── Décision ─────────────────────────────────────────────────────
            # Publier SEULEMENT si : texte neutre + pas commercial + CNN pas off_topic
            if (
                is_safe_text
                and is_safe_image
                and anti_env_score < 0.35
                and profanity_sc < 0.30
                and not is_commercial        # pas de spam/pub commerciale
                and not text_cnn_is_offtopic # CNN texte ne crie pas "off_topic"
            ):
                result.reasons = [
                    r for r in result.reasons
                    if "sans contexte environnemental" not in r
                    and "hors sujet" not in r.lower()
                    and "sans action eco" not in r.lower()
                    and "sans encouragement" not in r.lower()
                ]
                result.score  = min(result.score, 0.25)
                result.status = ModerationStatus.PUBLISHED.value
                result.processing_time_ms = round((time.time() - t0) * 1000, 2)
                return result

            # Texte avec signaux négatifs ou commercial → admin valide
            result.score  = max(result.score, 0.45)
            result.status = ModerationStatus.PENDING_REVIEW.value
            if is_commercial:
                pending_reason = "Contenu commercial ou publicitaire detecte : non conforme a la plateforme eco-citoyenne"
            elif text_cnn_is_offtopic:
                pending_reason = "Texte hors sujet detecte par l'IA : publication envoyee a l'administrateur"
            else:
                pending_reason = "Image eco-pertinente avec texte potentiellement problematique (validation admin requise)"
            if pending_reason not in result.reasons:
                result.reasons.append(pending_reason)
            result.processing_time_ms = round((time.time() - t0) * 1000, 2)
            return result


        # ══════════════════════════════════════════════════════════════════════
        # CAS 5 : Texte seul éco-pertinent (sans image ou image neutre)
        # ══════════════════════════════════════════════════════════════════════
        # Le TextCNN a classé le texte comme "eco" → publié directement.
        # CONDITION SUPPLÉMENTAIRE : le texte doit contenir au moins un
        # mot-clé éco réel (dictionnaire) pour éviter les faux positifs CNN.
        # Ex: "recette de couscous maison" → CNN dit eco mais AUCUN mot éco réel.
        eco_count = result.text_analysis.get("categories", {}).get("positive_context", {}).get("count", 0)
        if cnn_text_decision == "eco" and is_safe_text and (text_is_eco_relevant or eco_count >= 1):
            result.score  = min(result.score, 0.20)
            result.status = ModerationStatus.PUBLISHED.value
            result.processing_time_ms = round((time.time() - t0) * 1000, 2)
            return result

        # ══════════════════════════════════════════════════════════════════════
        # CAS 6 : Texte off_topic (sans contexte éco ni salutation) → PENDING_REVIEW
        # ══════════════════════════════════════════════════════════════════════
        # Les salutations (salam, bonjour...) ne sont PAS du hors sujet —
        # ce sont des échanges civils normaux dans la communauté.
        if cnn_text_decision == "off_topic" and not text_is_eco_relevant and not has_greeting:
            result.score  = max(result.score, 0.40)
            result.status = ModerationStatus.PENDING_REVIEW.value
            ot_reason = "Texte hors sujet detecte : ne concerne pas le tri, la proprete ou l'environnement (envoyee a l'administrateur)"
            if ot_reason not in result.reasons:
                result.reasons.append(ot_reason)
            result.processing_time_ms = round((time.time() - t0) * 1000, 2)
            return result

        # ══════════════════════════════════════════════════════════════════════
        # CAS 7 : Filet de sécurité — texte sans AUCUN contexte éco → PENDING_REVIEW
        # ══════════════════════════════════════════════════════════════════════
        # Si le texte ne contient aucun mot-clé éco (dictionnaire), n'est pas
        # une salutation, et que le parent l'a déjà pénalisé (score >= SAFE_THRESHOLD),
        # on force pending_review. Cela attrape les cas comme "recette de couscous"
        # que le CNN classe incorrectement comme "eco" ou "uncertain".
        if (
            not text_is_eco_relevant
            and not has_greeting
            and eco_count == 0
            and result.score >= SAFE_THRESHOLD
        ):
            result.score  = max(result.score, 0.40)
            result.status = ModerationStatus.PENDING_REVIEW.value
            safety_reason = "Publication sans lien avec le tri, la proprete ou l'environnement (envoyee a l'administrateur)"
            if safety_reason not in result.reasons:
                result.reasons.append(safety_reason)
            result.processing_time_ms = round((time.time() - t0) * 1000, 2)
            return result

        # ── GARDE FINALE : le CNN ne peut pas publier ce que le parent a bloqué ─
        # Si le parent a rendu un verdict fort (pending_review, score >= 0.50)
        # ET que le CNN veut publier → on revient à pending_review.
        # Exemple concret : image hors-sujet détectée par les règles (score 0.6),
        # mais le CNN voit "eco" dans l'image → SANS cette garde, il publie.
        result.processing_time_ms = round((time.time() - t0) * 1000, 2)
        if (
            _parent_is_strict_pending
            and result.status == ModerationStatus.PUBLISHED.value
        ):
            result.status = ModerationStatus.PENDING_REVIEW.value
            result.score  = max(result.score, _parent_score)
            lock_reason = "Validation admin requise : signal fort du pipeline de regles (score parent >= 0.50)"
            if lock_reason not in result.reasons:
                result.reasons.append(lock_reason)
        return result


# ─────────────────────────────────────────────────────────────────────────────
# Singleton lazy (utilisé par routers/posts.py)
# ─────────────────────────────────────────────────────────────────────────────

_cnn_moderator_instance: Optional[EcoCNNModerator] = None


def get_cnn_moderator() -> EcoCNNModerator:
    """Retourne le singleton EcoCNNModerator, chargé au premier appel."""
    global _cnn_moderator_instance
    if _cnn_moderator_instance is None:
        _cnn_moderator_instance = EcoCNNModerator()
    return _cnn_moderator_instance


class _LazyCNNModerator:
    """Proxy transparent -- instancie EcoCNNModerator au premier accès."""
    _obj = None

    def _ensure(self):
        if self._obj is None:
            self._obj = get_cnn_moderator()

    def __getattr__(self, name):
        self._ensure()
        return getattr(self._obj, name)

    def moderate(self, *args, **kwargs):
        self._ensure()
        return self._obj.moderate(*args, **kwargs)


# Alias utilisable par les routers :
#   from moderation_ai.eco_moderator import cnn_moderator
cnn_moderator = _LazyCNNModerator()
