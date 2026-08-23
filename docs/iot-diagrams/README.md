# Diagrammes IoT EcoRewind

## Architecture matérielle complète

Le fichier `iot_architecture_hardware_complete.svg` présente l’architecture complète de la partie IoT :

- ESP32-CAM AI Thinker avec caméra OV2640 intégrée ;
- PIR HC-SR505 : `OUT → GPIO 14` ;
- cellule de charge + HX711 : `DOUT → GPIO 1`, `SCK → GPIO 3` ;
- servo utilisateur : `PWM → GPIO 2` pendant 5 secondes ;
- servo collecteur : `PWM → GPIO 4` pendant 8 secondes ;
- LCD I²C : `SDA → GPIO 15`, `SCL → GPIO 13` ;
- communication Wi-Fi vers Firebase Realtime Database ;
- alimentation 5 V / 3 A minimum, GND commun et rail 5 V stable pour les servos ;
- gestion Deep Sleep et réveil par le PIR.

Les visuels sont des illustrations vectorielles réalistes basées sur les composants identifiés dans les images fournies : ESP32-CAM, PIR SR505, HX711, cellule de charge et servomoteur. La caméra est volontairement représentée comme intégrée à l’ESP32-CAM.

## Ouvrir et exporter

Ouvrir le fichier SVG avec un navigateur, Inkscape ou diagrams.net. Pour un export PNG haute résolution, utiliser Inkscape :

```bash
inkscape docs/iot-diagrams/iot_architecture_hardware_complete.svg \\
  --export-type=png \\
  --export-filename=image/iot_architecture_hardware_complete.png \\
  --export-dpi=180
```

Aucun secret Wi-Fi, token Firebase ou mot de passe n’est inclus dans le diagramme.
