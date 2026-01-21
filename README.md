# 🚀 Guide de Démarrage Rapide - TriDéchet

## 📌 Résumé de la Situation

### ✅ Ce qui fonctionne
- ✅ Structure du projet complète et correcte
- ✅ Tous les fichiers Dart sont présents
- ✅ Dépendances bien définies dans `pubspec.yaml`
- ✅ Code source sans erreurs apparentes
- ✅ Routes et navigation configurées

### ❌ Problème Principal
- ❌ **Flutter SDK n'est pas installé ou n'est pas dans le PATH**

## 🎯 Solution en 3 Étapes

### Option A: Installation Automatique (Recommandée) ⚡

#### Étape 1: Installer Flutter
1. **Clic droit** sur `installer_flutter.bat`
2. Sélectionnez **"Exécuter en tant qu'administrateur"**
3. Suivez les instructions à l'écran
4. Attendez la fin de l'installation (5-10 minutes)

#### Étape 2: Vérifier l'Installation
1. **Fermez et rouvrez** PowerShell ou le Terminal
2. Exécutez:
   ```powershell
   flutter doctor
   ```
3. Installez les composants manquants si nécessaire

#### Étape 3: Lancer l'Application
Double-cliquez sur `relancer_app.bat`

---

### Option B: Installation Manuelle 🔧

#### Étape 1: Télécharger Flutter
1. Visitez: https://docs.flutter.dev/get-started/install/windows
2. Téléchargez le SDK Flutter
3. Extrayez dans `C:\flutter`

#### Étape 2: Configurer le PATH
1. Ouvrez **Variables d'environnement système**:
   - Appuyez sur `Win + R`
   - Tapez `sysdm.cpl`
   - Onglet **Avancé** → **Variables d'environnement**
2. Modifiez la variable **Path** (Variables système)
3. Ajoutez: `C:\flutter\bin`
4. Cliquez sur **OK**

#### Étape 3: Vérifier et Lancer
1. Ouvrez un **nouveau** PowerShell
2. Exécutez: `flutter doctor`
3. Lancez: `flutter run -d chrome`

---

### Option C: Utiliser VS Code 💻

#### Étape 1: Installer l'Extension Flutter
1. Ouvrez VS Code
2. Extensions (`Ctrl+Shift+X`)
3. Recherchez et installez **"Flutter"**

#### Étape 2: Configurer le SDK
1. `Ctrl+Shift+P`
2. Tapez: **"Flutter: New Project"**
3. Indiquez l'emplacement du SDK Flutter

#### Étape 3: Exécuter
1. Ouvrez le projet TriDéchet
2. Appuyez sur **F5**
3. Sélectionnez **Chrome** comme plateforme

---

## 📋 Scripts Disponibles

| Script | Description | Utilisation |
|--------|-------------|-------------|
| `installer_flutter.bat` | Installe Flutter automatiquement | Clic droit → Exécuter en tant qu'admin |
| `verifier_projet.bat` | Vérifie le code et les dépendances | Double-clic |
| `relancer_app.bat` | Nettoie et lance l'application | Double-clic |

## 🔍 Vérification de l'Installation

Après avoir installé Flutter, vérifiez que tout fonctionne:

```powershell
# Vérifier la version
flutter --version

# Vérifier la configuration
flutter doctor

# Lister les appareils disponibles
flutter devices
```

## 🎨 Fonctionnalités de l'Application

### Pour les Utilisateurs (Clients)
- 📱 **Fil d'actualité** - Conseils et actualités écologiques
- 🎓 **Formation Éco** - Contenu éducatif multimédia
- 📊 **Impact** - Suivi des points et récompenses
- 🗺️ **Carte** - Localisation des points de collecte
- 👤 **Profil** - Gestion du compte et badge QR

### Pour les Administrateurs
- 📈 **Tableau de bord** - Statistiques et gestion
- 👥 **Gestion des utilisateurs** - Collecteurs, éducateurs, etc.
- 📍 **Gestion des points** - Points de collecte
- 🎯 **Intercommunalité** - Coordination régionale

## 🐛 Résolution des Problèmes Courants

### Erreur: "flutter command not found"
**Cause:** Flutter n'est pas dans le PATH  
**Solution:** Exécutez `installer_flutter.bat` en tant qu'administrateur

### Erreur: "Waiting for another flutter command..."
**Solution:**
```powershell
taskkill /F /IM dart.exe
taskkill /F /IM flutter.exe
```

### Erreur: "Unable to locate Android SDK"
**Solution:** Installez Android Studio depuis https://developer.android.com/studio

### Erreur: "Chrome not found"
**Solution:** Installez Google Chrome ou utilisez:
```powershell
flutter run -d windows
```

### Erreur de dépendances
**Solution:**
```powershell
flutter clean
flutter pub cache repair
flutter pub get
```

## 📦 Dépendances du Projet

```yaml
dependencies:
  google_fonts: ^6.1.0          # Polices Google
  flutter_animate: ^4.5.0       # Animations fluides
  font_awesome_flutter: ^10.7.0 # Icônes Font Awesome
  lottie: ^3.3.2                # Animations Lottie
  flutter_svg: ^2.2.3           # Support SVG
  url_launcher: ^6.2.1          # Lancement d'URLs
  qr_flutter: ^4.1.0            # Génération QR codes
  timeago: ^3.6.1               # Formatage dates
  flutter_map: ^8.2.2           # Cartes interactives
  latlong2: ^0.9.1              # Coordonnées GPS
  fl_chart: ^1.1.1              # Graphiques
```

## 🌐 Plateformes Supportées

- ✅ **Web (Chrome)** - Développement rapide
- ✅ **Windows** - Application de bureau
- ✅ **Android** - Application mobile
- ✅ **iOS** - Application mobile (macOS requis)
- ✅ **Linux** - Application de bureau

## 📱 Commandes Utiles

```powershell
# Nettoyer le projet
flutter clean

# Installer les dépendances
flutter pub get

# Analyser le code
flutter analyze

# Lancer sur Chrome
flutter run -d chrome

# Lancer sur Windows
flutter run -d windows

# Lister les appareils
flutter devices

# Créer un build de production
flutter build web
```

## 🎯 Prochaines Étapes

1. ✅ Installer Flutter (Option A, B ou C)
2. ✅ Vérifier avec `flutter doctor`
3. ✅ Exécuter `verifier_projet.bat`
4. ✅ Lancer l'application avec `relancer_app.bat`
5. ✅ Tester toutes les fonctionnalités

## 📞 Support et Documentation

- 📖 **Documentation Flutter:** https://docs.flutter.dev
- 🔧 **Guide de résolution:** Voir `GUIDE_RESOLUTION.md`
- 💡 **Tutoriels:** https://flutter.dev/learn
- 🐛 **Rapporter un bug:** Créez un issue sur GitHub

## ✨ Conseils

- 🔄 **Rechargement à chaud:** Appuyez sur `r` dans le terminal pendant l'exécution
- 🔃 **Rechargement complet:** Appuyez sur `R`
- 🛑 **Arrêter l'app:** Appuyez sur `q`
- 📸 **Capture d'écran:** Appuyez sur `s`

---

**Dernière mise à jour:** 2026-01-20  
**Version:** 1.0.0  
**Flutter requis:** >=3.0.0 <4.0.0

---

## 🎉 Bon développement avec TriDéchet!

Si vous rencontrez des problèmes, consultez `GUIDE_RESOLUTION.md` pour plus de détails.
