"""
Script de test de modération IA — EcoRewind v2
================================================
Teste les différents cas : éco-pertinent, hors-sujet, accident, NSFW, etc.

Usage :
    python test_moderation.py
"""

import sys
import os

# Ajouter le dossier parent au path
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.ai_moderator import moderator, SAFE_THRESHOLD, REVIEW_THRESHOLD

# ─── Couleurs terminal ───────────────────────────────────────────────────────
GREEN  = "\033[92m"
YELLOW = "\033[93m"
RED    = "\033[91m"
BLUE   = "\033[94m"
RESET  = "\033[0m"
BOLD   = "\033[1m"

def status_color(status):
    return {
        "published":     f"{GREEN}✅ PUBLIÉ{RESET}",
        "pending_review":f"{YELLOW}⏳ EN ATTENTE{RESET}",
        "rejected":      f"{RED}❌ REJETÉ{RESET}",
    }.get(status, status)

def run_test(label, text="", image_path="", expect=None):
    print(f"\n{BOLD}{BLUE}{'─'*60}{RESET}")
    print(f"{BOLD}🧪 Test : {label}{RESET}")
    if text:
        print(f"   📝 Texte  : {text[:80]}{'...' if len(text)>80 else ''}")
    if image_path:
        print(f"   🖼️  Image  : {os.path.basename(image_path)}")

    result = moderator.moderate(text=text, image_local_path=image_path)

    score_bar = "█" * int(result.score * 20) + "░" * (20 - int(result.score * 20))
    print(f"   📊 Score  : [{score_bar}] {result.score:.3f}")
    print(f"   🏷️  Statut : {status_color(result.status)}")

    if result.reasons:
        for r in result.reasons:
            print(f"   ⚠️  {r}")
    else:
        print(f"   {GREEN}✓ Aucune raison de blocage{RESET}")

    if expect:
        ok = result.status == expect
        verdict = f"{GREEN}PASS{RESET}" if ok else f"{RED}FAIL (attendu: {expect}){RESET}"
        print(f"   → {verdict}")

    return result


# ═══════════════════════════════════════════════════════════════════════════════
print(f"\n{BOLD}{'═'*60}{RESET}")
print(f"{BOLD}  EcoRewind — Tests de modération IA v2{RESET}")
print(f"{BOLD}  Seuils : SAFE={SAFE_THRESHOLD} | REVIEW={REVIEW_THRESHOLD}{RESET}")
print(f"{BOLD}{'═'*60}{RESET}")
print(f"  Modèles ML chargés : {moderator._ml_ready}")
print(f"  • Detoxify  : {'✅' if moderator._detoxify_model else '❌ non installé'}")
print(f"  • XLM-RoBERTa ZSC : {'✅' if moderator._nli_classifier else '❌ non installé'}")
print(f"  • CLIP ViT  : {'✅' if moderator._clip_model else '❌ non installé'}")
print(f"  • NudeNet   : {'✅' if moderator._nude_detector else '❌ non installé'}")

# ── CAS 1 : Publications éco-pertinentes (doivent être publiées) ─────────────
run_test(
    "Post éco — recyclage",
    text="J'ai trié mes déchets aujourd'hui et je les ai déposés au point de collecte !",
    expect="published",
)

run_test(
    "Post éco — nettoyage",
    text="Nous avons organisé un nettoyage de la plage ce matin. 50kg de déchets ramassés !",
    expect="published",
)

run_test(
    "Post éco — arabe",
    text="قمنا بتنظيف الشاطئ اليوم وجمعنا الكثير من النفايات لحماية البيئة",
    expect="published",
)

run_test(
    "Post éco — arbre planté",
    text="Plantation d'arbres dans le quartier pour reverdir notre ville. Rejoignez-nous !",
    expect="published",
)

# ── CAS 2 : Publications hors-sujet (doivent aller en attente) ───────────────
run_test(
    "Hors-sujet — accident voiture",
    text="Terrible accident sur l'autoroute A1 ce matin, 3 blessés graves transportés à l'hôpital",
    expect="pending_review",
)

run_test(
    "Hors-sujet — politique",
    text="Les élections municipales approchent, avez-vous décidé pour qui voter ?",
    expect="pending_review",
)

run_test(
    "Hors-sujet — sport",
    text="Quel match incroyable hier soir ! Notre équipe a marqué 3 buts en finale de la coupe",
    expect="pending_review",
)

run_test(
    "Hors-sujet — météo sans contexte éco",
    text="Il fait très beau aujourd'hui !",
    expect="pending_review",
)

# ── CAS 3 : Contenu toxique (doit être rejeté) ───────────────────────────────
run_test(
    "Toxique — insultes",
    text="Ce service est nul, quelle arnaque de merde, vous êtes des connards",
    expect="rejected",
)

run_test(
    "Anti-environnement",
    text="Je m'en fous de la nature, jeter par terre c'est plus simple",
    expect="rejected",
)

# ── CAS 4 : Cas limites ───────────────────────────────────────────────────────
run_test(
    "Post vide (aucun texte)",
    text="",
    expect="pending_review",  # Image seule sans CLIP → prudence
)

run_test(
    "Post éco avec mot sensible",
    text="La déforestation est un accident écologique majeur, nous devons recycler et protéger nos forêts",
    expect="published",  # Texte éco dominant malgré 'accident'
)

print(f"\n{BOLD}{BLUE}{'═'*60}{RESET}")
print(f"{BOLD}  Tests terminés.{RESET}")
print(f"  Note : Les tests d'image nécessitent des fichiers locaux réels.")
print(f"{BOLD}{'═'*60}{RESET}\n")
