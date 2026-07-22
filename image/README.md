# Ressources visuelles du rapport

Ce dossier contient les exports utilisés par les chapitres LaTeX. Les fichiers `.drawio` restent les sources modifiables et doivent être exportés depuis **diagrams.net** avec une échelle suffisante (200 % recommandé), un fond blanc et l'option de rognage activée.

## Chapitre 3

| Source | Export attendu |
| --- | --- |
| `image/architecture_ecorewind.svg` | `image/architecture_ecorewind.png` |
| `image/architecture_technique_ecorewind.svg` | `image/architecture_technique_ecorewind.png` |

## Chapitre 4 — Release 1

| Source Draw.io à la racine | Export PNG attendu dans `image/` |
| --- | --- |
| `usecase_sprint1_access.drawio` | `image/usecase_sprint1_access.png` |
| `sequence_sprint1_authentication.drawio` | `image/sequence_sprint1_authentication.png` |
| `sequence_sprint1_signup.drawio` | `image/sequence_sprint1_signup.png` |
| `class_sprint1_access.drawio` | `image/class_sprint1_access.png` |
| `usecase_sprint2_collection_points.drawio` | `image/usecase_sprint2_collection_points.png` |
| `class_sprint2_collection_points.drawio` | `image/class_sprint2_collection_points.png` |
| `sequence_sprint2_collection_points.drawio` | `image/sequence_sprint2_collection_points.png` |
| `usecase_sprint3_community.drawio` | `image/usecase_sprint3_community.png` |
| `class_sprint3_community.drawio` | `image/class_sprint3_community.png` |
| `sequence_sprint3_publish_post.drawio` | `image/sequence_sprint3_publish_post.png` |

`chap_04.tex` utilise `\IfFileExists`. Le document reste donc compilable si un export manque : un encadré indique alors le fichier Draw.io à exporter.

## Captures d'interface à fournir

Les captures doivent provenir d'une exécution réelle de l'application. Éviter les maquettes présentées comme des écrans implémentés. Les captures recommandées pour la Release 1 sont : connexion/MFA, profil et QR, carte et détails d'un point, fil communautaire, création d'une publication, notifications et écran de modération.
