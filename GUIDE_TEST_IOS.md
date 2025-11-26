# 🍎 Guide de Test iOS - Application Maghali

## ✅ Prérequis vérifiés

- ✅ Xcode installé (version 16.0)
- ✅ CocoaPods installé (version 1.16.2)
- ✅ Pods iOS installés avec succès
- ✅ Permissions Internet configurées dans Info.plist

## 🚀 Lancer l'application sur iOS

### Option 1 : Simulateur iOS (Recommandé pour les tests)

1. **Lancer le simulateur iOS :**
   ```bash
   flutter emulators --launch apple_ios_simulator
   ```

2. **Attendre que le simulateur démarre** (environ 10-30 secondes)

3. **Lancer l'application :**
   ```bash
   flutter run -d apple_ios_simulator
   ```
   
   Ou simplement :
   ```bash
   flutter run
   ```
   (Flutter détectera automatiquement le simulateur)

### Option 2 : Appareil iOS physique

1. **Connecter l'appareil** via câble USB à votre Mac

2. **Activer le mode développeur** sur l'appareil :
   - Paramètres → Confidentialité et sécurité → Mode développeur → Activer

3. **Faire confiance à l'ordinateur** sur l'appareil (si demandé)

4. **Vérifier que l'appareil est détecté :**
   ```bash
   flutter devices
   ```

5. **Lancer l'application :**
   ```bash
   flutter run -d <device-id>
   ```

## 🔧 Commandes utiles

### Vérifier les appareils disponibles
```bash
flutter devices
```

### Lister les simulateurs disponibles
```bash
flutter emulators
```

### Nettoyer et reconstruire
```bash
flutter clean
cd ios && pod install && cd ..
flutter pub get
flutter run
```

### Voir les logs en temps réel
```bash
flutter run --verbose
```

## ⚠️ Problèmes courants et solutions

### 1. Erreur d'encodage CocoaPods
**Solution :** Définir l'encodage UTF-8
```bash
export LANG=en_US.UTF-8
cd ios && pod install
```

### 2. Simulateur ne démarre pas
**Solution :** Ouvrir Xcode et lancer un simulateur manuellement
```bash
open -a Simulator
```

### 3. Erreur de signature de code
**Solution :** Configurer le Team dans Xcode
1. Ouvrir `ios/Runner.xcworkspace` dans Xcode
2. Sélectionner le projet "Runner"
3. Aller dans "Signing & Capabilities"
4. Sélectionner votre Team de développement

### 4. Pods non à jour
**Solution :** Réinstaller les pods
```bash
cd ios
rm -rf Pods Podfile.lock
pod install
cd ..
```

## 📱 Fonctionnalités à tester sur iOS

- ✅ Connexion utilisateur
- ✅ Navigation selon les rôles
- ✅ Création de tickets
- ✅ Gestion des factures
- ✅ Impression Bluetooth (si disponible sur iOS)
- ✅ Synchronisation Firestore en temps réel
- ✅ Stockage local (SharedPreferences)

## 🔍 Vérifications importantes

1. **Permissions Internet** : Vérifier que les requêtes Firestore fonctionnent
2. **Bluetooth** : Tester l'impression si un appareil Bluetooth est disponible
3. **Performance** : Vérifier que l'application est fluide
4. **UI/UX** : Vérifier que l'interface s'adapte bien à iOS

## 📝 Notes

- Les pods sont déjà installés et à jour
- La configuration iOS est prête
- L'application devrait fonctionner directement après `flutter run`


