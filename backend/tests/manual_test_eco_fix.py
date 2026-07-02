"""Test rapide -- verifie que le fix regle les faux positifs eco."""
import sys, os
sys.stdout.reconfigure(encoding="utf-8")
import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from moderation_ai.eco_moderator import get_cnn_moderator
m = get_cnn_moderator()

tests = [
    # (description, texte, image_path)
    ("Nature/eco avec texte court",    "Voici ma contribution !",                   ""),
    ("Tri des dechets explicite",      "Tri des dechets ce matin !",                ""),
    ("Recyclage plastique",            "Recyclage plastique avec mon association",  ""),
    ("Nettoyage foret",                "Nettoyage de la foret aujourd hui",         ""),
    ("Banal hors-sujet",               "Bonjour tout le monde",                    ""),
    ("Sport hors-sujet",               "Match de foot incroyable hier soir 3-0",   ""),
    ("Toxique",                        "Nique ta mere et ton recyclage inutile",    ""),
]

print(f"\n{'='*80}")
print(f"{'TEXTE':42s} | {'STATUS':15s} | {'SCORE':6s} | RAISON")
print(f"{'='*80}")
for label, text, img in tests:
    r = m.moderate(text=text, image_local_path=img)
    icon = "[OK]  " if r.status == "published" else ("[WAIT]" if r.status == "pending_review" else "[ERR] ")
    print(f"{icon} {text[:40]:40s} | {r.status:15s} | {r.score:.2f} | {r.reasons[:1]}")
print(f"{'='*80}\n")
