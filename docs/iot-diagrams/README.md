# Diagrammes IoT EcoRewind

Ce dossier contient les diagrammes Draw.io de la partie embarquée ESP32-CAM EcoRewind.

## Diagrammes recommandés pour le rapport

Les fichiers suivants ont été refaits avec une forme UML plus proche des diagrammes globaux du dépôt :

- `class_iot_ecorewind.drawio` : diagramme de classes de la partie IoT.
- `sequence_iot_citizen_deposit_v2.drawio` : diagramme de séquence du dépôt citoyen.
- `sequence_iot_collector_emptying_v2.drawio` : diagramme de séquence du vidage collecteur.

Ils remplacent les versions simplifiées précédentes pour les besoins du rapport PFE.

## Autres vues disponibles

- `iot_architecture_hardware.drawio` : architecture matérielle et câblage.
- `iot_activity_global.drawio` : activité globale du prototype.
- `iot_state_power_management.drawio` : gestion énergétique et Deep Sleep.
- `iot_component_software.drawio` : composants logiciels embarqués.

## Connexions matérielles représentées

- PIR HC-SR505 : `OUT -> GPIO 14`.
- Servomoteur utilisateur : `PWM -> GPIO 2`.
- Servomoteur collecteur : `PWM -> GPIO 4`.
- LCD I2C 16x2 : `SDA -> GPIO 15`, `SCL -> GPIO 13`.
- HX711 : `DOUT -> GPIO 1`, `SCK -> GPIO 3`.
- Caméra OV2640 : intégrée au module ESP32-CAM AI Thinker.
- Alimentation recommandée : 5 V / 3 A minimum, rail 5 V pour les servos, masse commune GND, condensateur 470–1000 µF près des servomoteurs.

## Flux Firebase représentés

Les diagrammes ne reproduisent aucun secret. Ils décrivent uniquement les chemins fonctionnels :

- `/utilisateurs/{qrID}/role`
- `/utilisateurs/{qrID}/score`
- `/poubelles/BIN-GENERAL-001/poids`
- `/poubelles/BIN-GENERAL-001/etat`

## Sécurité

Le code source partagé contient un SSID, un mot de passe Wi-Fi et un jeton Firebase. Ils ne sont volontairement pas reproduits dans ces diagrammes. Dans un projet réel, ces secrets doivent être révoqués, remplacés et déplacés vers une configuration sécurisée.

## Modification et export

1. Ouvrir https://app.diagrams.net/.
2. Choisir **File > Open From > Device**.
3. Sélectionner un fichier `.drawio` de ce dossier.
4. Modifier le diagramme si nécessaire.
5. Exporter en PNG via **File > Export as > PNG** avec une résolution élevée et fond inclus.

Commande possible si diagrams.net desktop ou `drawio` CLI est installé :

```bash
drawio -x -f png -s 2 -o image/class_iot_ecorewind.png docs/iot-diagrams/class_iot_ecorewind.drawio
drawio -x -f png -s 2 -o image/sequence_iot_citizen_deposit.png docs/iot-diagrams/sequence_iot_citizen_deposit_v2.drawio
drawio -x -f png -s 2 -o image/sequence_iot_collector_emptying.png docs/iot-diagrams/sequence_iot_collector_emptying_v2.drawio
```
