# Configuration du Splash Screen Natif

✅ **Le splash screen natif a été configuré avec succès !**

Actuellement, le splash screen utilise un fond blanc (#FFFFFF). Pour ajouter votre logo MAGHALI avec l'icône du restaurant, suivez les étapes ci-dessous.

## Étape 1 : Créer l'image du splash screen

Créez une image pour le splash screen avec les spécifications suivantes :

### Dimensions recommandées :
- **Android** : 1080x1920 pixels (portrait)
- **iOS** : 1242x2688 pixels (portrait)

### Design de l'image :
L'image doit contenir :
- **Icône du restaurant** au centre (style Material Icons restaurant)
- **Texte "MAGHALI"** en majuscules, en dessous de l'icône
- **Fond blanc** (#FFFFFF)
- Design centré et équilibré

### Exemple de layout :
```
        [Icône Restaurant]
        
        MAGHALI
        
    Gestion interne
```

## Étape 2 : Placer l'image

1. Créez le dossier `assets/splash/` à la racine du projet
2. Placez votre image dans ce dossier avec le nom `splash.png`

## Étape 3 : Activer l'image dans pubspec.yaml

Une fois l'image créée et placée dans `assets/splash/splash.png`, décommentez la ligne dans `pubspec.yaml` :

```yaml
flutter_native_splash:
  color: "#FFFFFF"
  image: assets/splash/splash.png  # Décommentez cette ligne
  android: true
  ios: true
```

## Étape 4 : Régénérer le splash screen natif

Exécutez la commande suivante :

```bash
flutter pub run flutter_native_splash:create
```

Cette commande va :
- Générer les fichiers de splash screen pour Android avec votre image
- Générer les fichiers de splash screen pour iOS avec votre image
- Mettre à jour les fichiers natifs nécessaires

## Étape 5 : Vérifier la configuration

Le fichier `pubspec.yaml` contient déjà la configuration :

```yaml
flutter_native_splash:
  color: "#FFFFFF"
  image: assets/splash/splash.png
  android: true
  android_12: true
  ios: true
  remove_after: true
```

## Étape 6 : Tester

1. Nettoyez le projet : `flutter clean`
2. Reconstruisez : `flutter pub get`
3. Lancez l'application : `flutter run`

Le splash screen natif devrait maintenant s'afficher au démarrage de l'application au lieu du splash screen Flutter par défaut.

## Note importante

Si vous modifiez l'image du splash screen, vous devez réexécuter :
```bash
flutter pub run flutter_native_splash:create
```

## État actuel

Le splash screen natif est maintenant configuré et fonctionnel avec :
- ✅ Fond blanc (#FFFFFF)
- ✅ Remplacement du splash screen Flutter par défaut
- ✅ Configuration pour Android et iOS
- ⏳ Image personnalisée : à ajouter (voir étapes ci-dessus)

L'application affichera maintenant le splash screen natif au démarrage au lieu du splash screen Flutter par défaut. Une fois que vous aurez créé et ajouté l'image avec le logo MAGHALI, le splash screen sera complet.

