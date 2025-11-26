# Correction des namespaces pour les packages

## Problème
Certains packages n'ont pas de namespace défini dans leur `build.gradle`, ce qui cause une erreur lors du build Android avec les versions récentes d'Android Gradle Plugin.

Packages concernés :
- `blue_thermal_printer`
- `flutter_native_splash`

## Solution
Un script `fix_packages_namespace.sh` a été créé pour corriger automatiquement ces problèmes.

### Utilisation

1. **Après chaque `flutter pub get`**, exécutez :
   ```bash
   ./fix_packages_namespace.sh
   ```

2. **Ou exécutez directement** :
   ```bash
   flutter pub get && ./fix_packages_namespace.sh
   ```

## Note
Les namespaces ont déjà été ajoutés aux packages dans le cache. Si vous supprimez le cache pub (`flutter pub cache repair`), vous devrez réexécuter le script.

## Packages corrigés
- ✅ `blue_thermal_printer` : namespace `id.kakzaki.blue_thermal_printer`
- ✅ `flutter_native_splash` : namespace `net.jonhanson.flutter_native_splash`

