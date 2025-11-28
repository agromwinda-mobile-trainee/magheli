#!/bin/zsh
set -e

echo "🚀 Build iOS Release - Maghali"
echo "================================"
echo ""

# Se placer dans le projet
cd "/Users/celestinsaleh/flutter course/Maghali"

# 1. Nettoyer le projet
echo "➡️  Nettoyage du projet..."
flutter clean

# 2. Récupérer les dépendances
echo ""
echo "➡️  Récupération des dépendances..."
flutter pub get

# 3. Build iOS en release
echo ""
echo "➡️  Build iOS en mode release..."
flutter build ios --release

echo ""
echo "✅ Build iOS terminé avec succès!"
echo ""
echo "📱 Prochaines étapes dans Xcode:"
echo "   1. Ouvrir le projet iOS:"
echo "      open ios/Runner.xcworkspace"
echo ""
echo "   2. Dans Xcode:"
echo "      - Sélectionner 'Any iOS Device' ou ton iPhone connecté"
echo "      - Menu Product > Archive"
echo "      - Une fois l'archive créée, cliquer sur 'Distribute App'"
echo "      - Choisir 'Development' ou 'Ad Hoc' pour installer en dur"
echo "      - Suivre les étapes pour générer le .ipa"
echo ""
echo "   3. Installer le .ipa sur iPhone:"
echo "      - Via Xcode (Window > Devices and Simulators)"
echo "      - Ou via Finder (glisser-déposer le .ipa sur l'iPhone)"
echo ""

