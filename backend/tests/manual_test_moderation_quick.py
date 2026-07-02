import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# -*- coding: utf-8 -*-
"""Test rapide de modération IA — vérifie les 6 cas métier."""
import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')

from moderation_ai.eco_moderator import EcoCNNModerator

m = EcoCNNModerator()
print("\n" + "="*65)
print("  TESTS MODERATION IA — EcoRewind")
print("="*65 + "\n")

tests = [
    # (texte, statut attendu, description)
    ("Bonjour! Trions nos déchets pour un monde plus propre", "published", "CAS 1: éco + salutation"),
    ("Nettoyage de la plage demain, rejoignez-nous!", "published", "CAS 2: éco pur"),
    ("La pollution détruit nos océans, protégeons-les", "published", "CAS 2: pollution + encouragement"),
    ("salam les amis", "published", "CAS 1: salutation seule"),
    ("Recyclage et compostage pour réduire les déchets", "published", "CAS 2: éco conseils"),
    ("vend iphone 15 pas cher neuf", "pending_review", "CAS 5: hors-sujet commerce"),
    ("match de foot ce soir", "pending_review", "CAS 5: hors-sujet sport"),
    ("recette de couscous maison", "pending_review", "CAS 5: hors-sujet cuisine"),
]

passed = 0
failed = 0

for text, expected, desc in tests:
    r = m.moderate(text)
    ok = r.status == expected
    icon = "✅" if ok else "❌"
    if ok:
        passed += 1
    else:
        failed += 1
    print(f"  {icon} {desc}")
    print(f"     Texte   : \"{text}\"")
    print(f"     Attendu : {expected}")
    print(f"     Obtenu  : {r.status} (score={r.score:.3f})")
    if r.reasons:
        print(f"     Raisons : {r.reasons}")
    print()

print("="*65)
print(f"  RESULTAT : {passed}/{passed+failed} tests réussis")
if failed > 0:
    print(f"  ⚠️  {failed} test(s) échoué(s)")
print("="*65)
