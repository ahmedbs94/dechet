# -*- coding: utf-8 -*-
"""
test_moderation_rules.py
========================
Teste les regles metier de moderation IA EcoRewind.

Cas testes :
  CAS 1 : Image eco + salutation → PUBLISHED
  CAS 2 : Image pollution + texte encourageant → PUBLISHED
  CAS 3 : Contenu hors sujet → PENDING_REVIEW (admin)
  CAS 4 : Contenu toxique → REJECTED
  CAS 5 : Texte eco pur → PUBLISHED
  CAS 6 : Texte off-topic pur → PENDING_REVIEW
"""
import os, sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# ── Charger le moderator ──────────────────────────────────────────────────────
from moderation_ai.eco_moderator import EcoCNNModerator

print("=" * 70)
print("  TEST REGLES DE MODERATION IA EcoRewind")
print("=" * 70)
print()

moderator = EcoCNNModerator()
print()

# ── Resultats ─────────────────────────────────────────────────────────────────
results = []
PASS = "[OK]"
FAIL = "[ECHEC]"

def test(name, text, expected_status, image_path=""):
    result = moderator.moderate(text=text, image_local_path=image_path)
    ok = result.status == expected_status
    status = PASS if ok else FAIL
    results.append((ok, name, result.status, expected_status))
    print(f"  {status} {name}")
    print(f"        Texte    : \"{text[:60]}{'...' if len(text)>60 else ''}\"")
    if image_path:
        print(f"        Image    : {os.path.basename(image_path)}")
    print(f"        Score    : {result.score:.3f}")
    print(f"        Status   : {result.status} (attendu: {expected_status})")
    print(f"        Raisons  : {result.reasons[:2]}")
    print()
    return ok


sep = lambda t: print(f"\n{'─'*70}\n  {t}\n{'─'*70}")

# ═══════════════════════════════════════════════════════════════════════════════
# TESTS TEXTE SEULEMENT (pas d'image)
# ═══════════════════════════════════════════════════════════════════════════════
sep("TEXTE SEULEMENT (sans image)")

# Publications eco → PUBLISHED
test("Texte eco: recyclage",
     "Recyclons ensemble pour un monde plus propre !",
     "published")

test("Texte eco: tri des dechets",
     "Pensez a trier vos dechets plastiques et cartons dans les bacs prevus",
     "published")

test("Texte eco: sensibilisation pollution",
     "Saviez-vous que le plastique met 400 ans a se degrader dans la nature ?",
     "published")

test("Texte eco: conseil citoyen",
     "Chaque petit geste compte pour proteger notre environnement",
     "published")

test("Texte eco: nettoyage plage",
     "Rejoignez-nous ce samedi pour nettoyer la plage de Sidi Bou Said !",
     "published")

test("Texte eco: compostage",
     "Le compostage reduit nos dechets de 30%, adoptez-le chez vous",
     "published")

# Salutation seule → PUBLISHED (via le parent, is_greeting_only)
test("Salutation seule: bonjour",
     "Bonjour a tous !",
     "published")

test("Salutation seule: salam",
     "Salam les amis",
     "published")

# Publications hors sujet → PENDING_REVIEW
test("Hors sujet: sport",
     "Quel match incroyable hier soir, 3 buts en 10 minutes !",
     "pending_review")

test("Hors sujet: cuisine",
     "Ma recette de tajine d'agneau aux pruneaux est delicieuse",
     "pending_review")

test("Hors sujet: technologie",
     "Le nouvel iPhone est sorti avec une puce surpuissante incroyable",
     "pending_review")

test("Hors sujet: politique",
     "Les resultats des elections sont tres surprenants cette annee",
     "pending_review")

# Contenu toxique → REJECTED
test("Toxique: insultes",
     "Vous etes des connards et des salopes, allez vous faire foutre",
     "rejected")

test("Anti-environnement",
     "Je m'en fous de la nature, jeter par terre c'est plus simple",
     "rejected")


# ═══════════════════════════════════════════════════════════════════════════════
# RAPPORT FINAL
# ═══════════════════════════════════════════════════════════════════════════════
sep("RAPPORT FINAL")

total = len(results)
passed = sum(1 for ok, *_ in results if ok)
failed = sum(1 for ok, *_ in results if not ok)

print(f"""
  Total tests    : {total}
  {PASS} Reussis  : {passed}
  {FAIL} Echoues  : {failed}
""")

if failed > 0:
    print("  ECHECS :")
    for ok, name, got, expected in results:
        if not ok:
            print(f"    {FAIL} {name}: got={got}, expected={expected}")

if failed == 0:
    print("  >>> TOUTES LES REGLES DE MODERATION SONT CORRECTES <<<")
else:
    print(f"\n  >>> {failed} REGLE(S) A CORRIGER <<<")

print(f"\n{'='*70}\n")
