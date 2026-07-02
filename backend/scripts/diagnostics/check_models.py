import os, sys
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

"""Verifie que tous les modeles IA sont charges."""
import sys, io
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8', errors='replace')
from moderation_ai.eco_moderator import EcoCNNModerator

m = EcoCNNModerator()
print()
print("=" * 60)
print("  VERIFICATION MODELES IA")
print("=" * 60)
detox = "OK" if m._detoxify_model else "MANQUANT"
nude = "OK" if m._nude_detector else "MANQUANT"
tcnn = "OK" if m._text_cnn else "MANQUANT"
rnet = "OK" if m._img_resnet else "MANQUANT"
print(f"  Detoxify (BERT multilingual) : {detox}")
print(f"  NudeNet (CNN NSFW)           : {nude}")
print(f"  TextCNN (EcoTextCNN)         : {tcnn}")
print(f"  ResNet18 (Image eco)         : {rnet}")
print(f"  ML Ready : {m._ml_ready}")
print(f"  CNN Ready: {m._cnn_ready}")
total = sum(1 for x in [m._detoxify_model, m._nude_detector, m._text_cnn, m._img_resnet] if x)
print(f"\n  {total}/4 modeles charges avec succes")
print("=" * 60)
