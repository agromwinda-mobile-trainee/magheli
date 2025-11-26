# 📱 Guide de Build Release - Application Maghali

## ✅ APK Android

L'APK Android a été généré avec succès. Le fichier se trouve à :
```
build/app/outputs/flutter-apk/app-release.apk
```

### Installation de l'APK

1. **Transférer l'APK** sur votre appareil Android (via USB, email, ou cloud)
2. **Activer l'installation depuis des sources inconnues** :
   - Paramètres → Sécurité → Activer "Sources inconnues"
3. **Installer l'APK** en le tapotant dans le gestionnaire de fichiers

---

## 🍎 Build iOS (Installation Directe)

Pour installer l'app iOS directement sur un appareil (hors App Store), vous avez besoin :

### Prérequis

1. **Compte développeur Apple** (gratuit ou payant)
2. **Xcode installé** sur votre Mac
3. **Appareil iOS** connecté ou configuré pour TestFlight

### Option 1 : Installation Directe via Xcode (Recommandé)

#### Étape 1 : Configurer le projet dans Xcode

```bash
# Ouvrir le projet dans Xcode
open ios/Runner.xcworkspace
```

#### Étape 2 : Configurer la signature

1. Dans Xcode, sélectionner le projet **Runner** dans le navigateur
2. Aller dans l'onglet **"Signing & Capabilities"**
3. Sélectionner votre **Team** de développement
4. Xcode générera automatiquement un profil de provisioning

#### Étape 3 : Sélectionner l'appareil cible

1. En haut de Xcode, sélectionner votre appareil iOS connecté (ou un simulateur)
2. Choisir **"Any iOS Device"** pour un build générique

#### Étape 4 : Créer le build

**Via Flutter (Recommandé) :**
```bash
# Build pour un appareil spécifique
flutter build ios --release

# Ou pour créer un IPA (pour TestFlight ou installation directe)
flutter build ipa --release
```

**Via Xcode :**
1. Menu **Product** → **Archive**
2. Attendre que l'archive soit créée
3. Dans la fenêtre Organizer :
   - Cliquer sur **"Distribute App"**
   - Choisir **"Ad Hoc"** ou **"Development"**
   - Sélectionner votre appareil
   - Exporter l'IPA

#### Étape 5 : Installer sur l'appareil

**Méthode 1 : Via Xcode**
1. Connecter l'appareil iOS à votre Mac
2. Dans Xcode, sélectionner l'appareil
3. Cliquer sur **"Run"** (▶️) - Xcode installera l'app directement

**Méthode 2 : Via IPA**
1. Transférer le fichier `.ipa` sur l'appareil
2. Utiliser **Apple Configurator 2** ou **3uTools** pour installer
3. Ou utiliser **TestFlight** (nécessite un compte développeur payant)

### Option 2 : Build via Flutter (Plus Simple)

```bash
# 1. Nettoyer le projet
flutter clean

# 2. Récupérer les dépendances
flutter pub get

# 3. Installer les pods iOS
cd ios && pod install && cd ..

# 4. Build en mode release
flutter build ios --release

# 5. Ouvrir dans Xcode pour installer
open ios/Runner.xcworkspace
```

Puis dans Xcode :
1. Sélectionner votre appareil iOS
2. Cliquer sur **Run** (▶️)

### Option 3 : TestFlight (Pour Distribution)

Si vous avez un compte développeur Apple payant ($99/an) :

```bash
# Créer un IPA pour TestFlight
flutter build ipa --release
```

Le fichier IPA sera dans :
```
build/ios/ipa/maghali.ipa
```

Ensuite :
1. Ouvrir **App Store Connect**
2. Créer une nouvelle app
3. Télécharger **Transporter** depuis le Mac App Store
4. Utiliser Transporter pour uploader l'IPA
5. Ajouter des testeurs dans TestFlight

---

## 🔧 Configuration iOS Avancée

### Vérifier la configuration du Bundle ID

Dans `ios/Runner.xcodeproj/project.pbxproj` ou via Xcode :
- Le Bundle ID doit être unique (ex: `com.votredomaine.maghali`)

### Activer le mode développeur sur l'appareil iOS

1. **Paramètres** → **Confidentialité et sécurité**
2. Activer **"Mode développeur"**
3. Redémarrer l'appareil si demandé

### Faire confiance au développeur

Après installation :
1. **Paramètres** → **Général** → **Gestion des appareils**
2. Appuyer sur votre profil de développeur
3. Appuyer sur **"Faire confiance"**

---

## 📝 Notes Importantes

### Android
- ✅ L'APK est prêt à être installé
- ⚠️ Pour publier sur Google Play, vous devrez signer l'APK avec une clé de release

### iOS
- ⚠️ Les builds de développement expirent après 7 jours (compte gratuit) ou 1 an (compte payant)
- ⚠️ Pour une installation permanente, vous avez besoin d'un compte développeur payant
- ✅ Avec un compte payant, vous pouvez utiliser TestFlight pour distribuer à 100 testeurs

---

## 🚀 Commandes Rapides

```bash
# Android APK
flutter build apk --release

# iOS Build
flutter build ios --release

# iOS IPA (pour TestFlight)
flutter build ipa --release

# Vérifier les builds
ls -lh build/app/outputs/flutter-apk/
ls -lh build/ios/ipa/
```

---

## 📞 Support

Si vous rencontrez des problèmes :
1. Vérifier que Xcode est à jour
2. Vérifier que les certificats de développeur sont valides
3. Vérifier que l'appareil iOS est bien enregistré dans votre compte développeur


