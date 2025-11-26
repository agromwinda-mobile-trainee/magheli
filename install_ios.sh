#!/bin/bash

# Script pour installer l'app iOS sur un appareil connecté
# Usage: ./install_ios.sh

echo "🍎 Installation de Maghali sur iOS"
echo "===================================="
echo ""

# Vérifier que Xcode est installé
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode n'est pas installé. Veuillez installer Xcode depuis le App Store."
    exit 1
fi

# Vérifier qu'un appareil est connecté
echo "📱 Vérification des appareils connectés..."
DEVICES=$(xcrun xctrace list devices 2>&1 | grep -i "iphone\|ipad" | grep -v "Simulator" | wc -l)

if [ "$DEVICES" -eq 0 ]; then
    echo "⚠️  Aucun appareil iOS connecté détecté."
    echo ""
    echo "Pour installer l'app :"
    echo "1. Connectez votre appareil iOS à votre Mac"
    echo "2. Déverrouillez votre appareil et faites confiance à l'ordinateur"
    echo "3. Ouvrez Xcode : open ios/Runner.xcworkspace"
    echo "4. Sélectionnez votre appareil dans la barre d'outils"
    echo "5. Cliquez sur Run (▶️)"
    echo ""
    echo "Ou exécutez cette commande :"
    echo "flutter run --release -d <device-id>"
    exit 1
fi

echo "✅ Appareil(s) détecté(s)"
echo ""

# Ouvrir Xcode
echo "🚀 Ouverture de Xcode..."
open ios/Runner.xcworkspace

echo ""
echo "📋 Instructions :"
echo "1. Dans Xcode, sélectionnez votre appareil iOS en haut"
echo "2. Allez dans Signing & Capabilities et sélectionnez votre Team"
echo "3. Cliquez sur Run (▶️) pour installer l'app"
echo ""
echo "Ou utilisez cette commande Flutter :"
echo "flutter run --release"


