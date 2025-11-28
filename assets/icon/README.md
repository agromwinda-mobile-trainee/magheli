# Dossier pour l'icône de l'application

## Fichiers nécessaires

Placez deux fichiers dans ce dossier :

### 1. `app_icon.png` (Icône principale)
- **Format** : PNG
- **Dimensions** : 1024x1024 pixels (carré)
- **Contenu** : 
  - Fond noir (#000000)
  - Texte "maghali" en italique, couleur blanche
  - Centré dans l'image
  - Design simple et lisible même en petite taille

### 2. `app_icon_foreground.png` (Pour Android adaptatif)
- **Format** : PNG
- **Dimensions** : 1024x1024 pixels (carré)
- **Contenu** : 
  - Même design que `app_icon.png`
  - Texte "maghali" en italique, couleur blanche
  - Fond transparent ou blanc (sera remplacé par le fond adaptatif)

## Design recommandé

L'icône doit être simple et reconnaissable :
- Fond noir (#000000)
- Texte "maghali" en italique, police blanche
- Texte centré
- Pas d'éléments décoratifs supplémentaires (pour rester lisible en petite taille)

## Génération des icônes

Une fois les fichiers créés, exécutez :
```bash
flutter pub get
flutter pub run flutter_launcher_icons
```

Cette commande générera automatiquement toutes les tailles d'icônes nécessaires pour Android et iOS.




