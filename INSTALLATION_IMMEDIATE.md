# 🚀 Installation Immédiate de Flutter - 15 Minutes

## Étape 1 : Télécharger Flutter (2 minutes)

1. **Ouvrez votre navigateur** et allez sur :
   ```
   https://storage.googleapis.com/flutter_infra_release/releases/stable/windows/flutter_windows_3.24.5-stable.zip
   ```

2. Le téléchargement commencera automatiquement (~1 GB)

## Étape 2 : Extraire Flutter (3 minutes)

1. Une fois téléchargé, **clic droit** sur le fichier ZIP
2. Sélectionnez **"Extraire tout..."**
3. Choisissez `C:\` comme destination
4. Cliquez sur **"Extraire"**
5. Vous aurez maintenant un dossier `C:\flutter`

## Étape 3 : Ajouter Flutter au PATH (5 minutes)

### Méthode Rapide via PowerShell (Administrateur)

1. **Clic droit** sur le bouton Démarrer
2. Sélectionnez **"Windows PowerShell (Admin)"** ou **"Terminal (Admin)"**
3. Copiez et collez cette commande :

```powershell
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\flutter\bin", "Machine")
```

4. Appuyez sur **Entrée**
5. **Fermez** PowerShell

### OU Méthode Manuelle

1. Appuyez sur **Win + R**
2. Tapez `sysdm.cpl` et appuyez sur **Entrée**
3. Allez dans l'onglet **"Avancé"**
4. Cliquez sur **"Variables d'environnement"**
5. Dans **"Variables système"**, trouvez **"Path"**
6. Cliquez sur **"Modifier"**
7. Cliquez sur **"Nouveau"**
8. Ajoutez : `C:\flutter\bin`
9. Cliquez sur **"OK"** partout

## Étape 4 : Vérifier l'Installation (2 minutes)

1. **Ouvrez un NOUVEAU PowerShell** (important !)
2. Tapez :
   ```powershell
   flutter doctor
   ```
3. Flutter va s'initialiser et afficher son statut

## Étape 5 : Lancer l'Application (3 minutes)

1. Naviguez vers le projet :
   ```powershell
   cd "C:\Users\lenovo\Desktop\TriDéchet"
   ```

2. Installez les dépendances :
   ```powershell
   flutter pub get
   ```

3. Lancez l'application :
   ```powershell
   flutter run -d chrome
   ```

## ✅ C'est Tout !

Votre application TriDéchet s'ouvrira dans Chrome !

---

## 🐛 Si Vous Rencontrez un Problème

### "Chrome not found"
```powershell
flutter run -d windows
```

### "Android licenses not accepted"
Ignorez pour l'instant, l'app fonctionnera sur Chrome/Windows

### Autre erreur
```powershell
flutter clean
flutter pub get
flutter run -d chrome
```

---

## ⏱️ Temps Total : ~15 minutes

- Téléchargement : 2-5 min (selon votre connexion)
- Extraction : 2-3 min
- Configuration PATH : 2 min
- Vérification : 2 min
- Premier lancement : 3-5 min

**TOTAL : 11-17 minutes**

---

## 🎉 Prêt à Commencer ?

Suivez les étapes ci-dessus et vous pourrez exécuter l'application immédiatement !
