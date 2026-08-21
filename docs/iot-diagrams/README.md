# Diagrammes IoT EcoRewind

Ce dossier contient les sources Draw.io des diagrammes du code embarqué ESP32-CAM EcoRewind fourni dans la conversation.

## Fichiers

- `iot_architecture_hardware.drawio` : architecture matérielle du prototype, broches GPIO, alimentation, capteurs, actionneurs et Firebase.
- `iot_activity_global.drawio` : activité globale depuis le réveil PIR jusqu’au retour en Deep Sleep.
- `iot_sequence_citizen_deposit.drawio` : scénario citoyen de dépôt avec mesure du poids, calcul des points et mise à jour Firebase.
- `iot_sequence_collector_emptying.drawio` : scénario collecteur avec ouverture du couvercle de vidage, tare du HX711 et remise à zéro du bac.
- `iot_state_power_management.drawio` : états de gestion énergétique et transitions liées au PIR.
- `iot_component_software.drawio` : composants logiciels embarqués et dépendances principales.

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
drawio -x -f png -s 2 -o image/iot_architecture_hardware.png docs/iot-diagrams/iot_architecture_hardware.drawio
```

Répéter la commande pour chaque fichier source.
