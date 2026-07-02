"""
Test RAPIDE — Couche 1 (règles) uniquement — EcoRewind v2
===========================================================
Lance les tests sans charger aucun modèle ML.
Résultat en < 5 secondes.

Usage :
    python -X utf8 test_rules_only.py
"""

import sys
import os

# Activer le mode règles seules AVANT tout import
os.environ["ECOREWIND_RULES_ONLY"] = "1"

import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from services.ai_moderator import AIModerator, SAFE_THRESHOLD, REVIEW_THRESHOLD

# Instance en mode règles seules
mod = AIModerator(rules_only=True)

# ─── Couleurs ────────────────────────────────────────────────────────────────
G    = "\033[92m"
Y    = "\033[93m"
R    = "\033[91m"
B    = "\033[94m"
BOLD = "\033[1m"
RST  = "\033[0m"

PASS_COUNT = 0
FAIL_COUNT = 0

def test(label, text="", expect=None):
    global PASS_COUNT, FAIL_COUNT
    result = mod.moderate(text=text, image_local_path="")
    bar = "█" * int(result.score * 20) + "░" * (20 - int(result.score * 20))
    status_str = {
        "published":      f"{G}PUBLIE{RST}",
        "pending_review": f"{Y}EN ATTENTE{RST}",
        "rejected":       f"{R}REJETE{RST}",
    }.get(result.status, result.status)

    ok = (expect is None) or (result.status == expect)
    verdict = f"{G}PASS{RST}" if ok else f"{R}FAIL (attendu={expect}, obtenu={result.status}){RST}"
    if ok:
        PASS_COUNT += 1
    else:
        FAIL_COUNT += 1

    print(f"\n  {BOLD}{label}{RST}")
    print(f"  Score [{bar}] {result.score:.3f}  |  {status_str}  |  {verdict}")
    if result.reasons:
        for r in result.reasons[:2]:
            print(f"    >> {r}")

# ─── Header ──────────────────────────────────────────────────────────────────
print(f"\n{BOLD}{B}{'='*65}{RST}")
print(f"{BOLD}  EcoRewind — Tests couche regles  |  SAFE={SAFE_THRESHOLD} | REVIEW={REVIEW_THRESHOLD}{RST}")
print(f"{BOLD}  (Sans ML — resultats instantanes){RST}")
print(f"{BOLD}{B}{'='*65}{RST}")

# ── CAS 1 : ECO-PERTINENTS → publiés ─────────────────────────────────────────
print(f"\n{BOLD}[CAS 1] Publications eco-pertinentes (attendu: published){RST}")

test("Recyclage tri selectif",
     "J'ai trie mes dechets aujourd'hui au point de collecte !",
     expect="published")

test("Nettoyage plage",
     "Nous avons nettoye la plage ce matin, 50kg de dechets ramasses !",
     expect="published")

test("Plantation arbres",
     "Plantation de 20 arbres dans notre quartier pour le reboisement.",
     expect="published")

test("Energie solaire",
     "Installation de panneaux solaires pour reduire notre empreinte carbone.",
     expect="published")

test("Compostage zero dechet",
     "Compostage de mes dechets organiques, zero dechet cette semaine !",
     expect="published")

test("Biodiversite abeilles",
     "Preservation des abeilles et de la biodiversite dans notre jardin ecologique.",
     expect="published")

test("Texte arabe eco",
     "قمنا بتنظيف الشاطئ وجمعنا النفايات لحماية البيئة اليوم",
     expect="published")

test("Eco mixte court",
     "Ramassage des dechets au parc naturel ce weekend.",
     expect="published")

# ── CAS 2 : HORS-SUJET → en attente ─────────────────────────────────────────
print(f"\n{BOLD}[CAS 2] Hors-sujet (attendu: pending_review){RST}")

test("Accident voiture",
     "Terrible accident sur l'autoroute A1 ce matin, 3 blesses a l'hopital",
     expect="pending_review")

test("Politique elections",
     "Les elections municipales approchent, avez-vous decide pour qui voter ?",
     expect="pending_review")

test("Sport foot",
     "Quel match incroyable hier soir, notre equipe a marque 3 buts en finale",
     expect="pending_review")

test("Meteo seule",
     "Il fait tres beau aujourd'hui !",
     expect="pending_review")

test("Nourriture restaurant",
     "J'ai mange un excellent couscous ce midi au restaurant",
     expect="pending_review")

test("Mort deces",
     "Deces d'une victime suite a l'accident de la route survenu hier soir",
     expect="pending_review")

test("Urgence medicale",
     "Trois personnes hospitalisees apres une collision sur la route nationale",
     expect="pending_review")

# ── CAS 3 : IMAGE SEULE → en attente (sans CLIP) ─────────────────────────────
print(f"\n{BOLD}[CAS 3] Image seule sans texte (attendu: pending_review){RST}")

test("Image seule (pas de CLIP dispo)",
     text="",
     expect="pending_review")

# ── CAS 4 : TOXIQUE → rejeté ─────────────────────────────────────────────────
print(f"\n{BOLD}[CAS 4] Contenu toxique (attendu: rejected){RST}")

test("Insultes multiples FR",
     "Ce service est nul, quelle merde, vous etes des connards et des imbeciles",
     expect="rejected")

test("Anti-environnement",
     "Je m'en fous de la nature, jeter par terre c'est tellement plus simple",
     expect="rejected")

test("Insultes EN",
     "This is bullshit, you fucking idiots, I hate this stupid app",
     expect="rejected")

# ── CAS 5 : LIMITES ──────────────────────────────────────────────────────────
print(f"\n{BOLD}[CAS 5] Cas limites{RST}")

test("Eco + mot sensible (accident ecologique)",
     "La deforestation est un accident ecologique majeur, recycler et proteger nos forets est urgent",
     expect="published")

test("Post vide total",
     "",
     expect="pending_review")

test("Texte court banal",
     "Bonjour tout le monde",
     expect="pending_review")

# ── RÉSUMÉ ────────────────────────────────────────────────────────────────────
total = PASS_COUNT + FAIL_COUNT
print(f"\n{BOLD}{B}{'='*65}{RST}")
print(f"{BOLD}  RESULTATS : {G}{PASS_COUNT} PASS{RST}{BOLD}  |  {R}{FAIL_COUNT} FAIL{RST}{BOLD}  |  Total : {total}{RST}")
print(f"{BOLD}{B}{'='*65}{RST}\n")

if FAIL_COUNT > 0:
    sys.exit(1)
