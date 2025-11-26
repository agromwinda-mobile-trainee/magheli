# Configuration de l'icône de l'application

Pour configurer l'icône de l'application avec le logo MAGHALI et l'icône du restaurant, vous avez deux options :

## Option 1 : Utiliser flutter_launcher_icons (Recommandé)

1. **Ajouter la dépendance dans `pubspec.yaml`** :
```yaml
dev_dependencies:
  flutter_launcher_icons: ^0.13.1
```

2. **Créer un fichier d'icône** :
   - Créez une image carrée (1024x1024 pixels recommandé)
   - Le logo doit contenir l'icône du restaurant et le texte "MAGHALI"
   - Sauvegardez-la comme `assets/icon/icon.png`

3. **Configurer dans `pubspec.yaml`** :
```yaml
flutter_launcher_icons:
  android: true
  ios: true
  image_path: "assets/icon/icon.png"
  adaptive_icon_background: "#FFFFFF"
  adaptive_icon_foreground: "assets/icon/icon.png"
```

4. **Générer les icônes** :
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

## Option 2 : Remplacer manuellement les icônes

### Pour Android :
Remplacez les fichiers dans `android/app/src/main/res/` :
- `mipmap-mdpi/ic_launcher.png` (48x48)
- `mipmap-hdpi/ic_launcher.png` (72x72)
- `mipmap-xhdpi/ic_launcher.png` (96x96)
- `mipmap-xxhdpi/ic_launcher.png` (144x144)
- `mipmap-xxxhdpi/ic_launcher.png` (192x192)

Et pour l'icône adaptative :
- `mipmap-anydpi-v26/ic_launcher.xml`
- `mipmap-anydpi-v26/ic_launcher_round.xml`
- `mipmap-mdpi/ic_launcher_foreground.png`
- `mipmap-hdpi/ic_launcher_foreground.png`
- etc.

### Pour iOS :
Remplacez les fichiers dans `ios/Runner/Assets.xcassets/AppIcon.appiconset/`

## Design recommandé pour l'icône

L'icône doit contenir :
- L'icône du restaurant (Icons.restaurant) au centre
- Le texte "MAGHALI" en dessous ou autour
- Fond blanc ou transparent
- Design simple et reconnaissable même en petite taille



