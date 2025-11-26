#!/bin/bash

# Script pour corriger les namespaces des packages
# Ce script doit être exécuté après flutter pub get

# Corriger blue_thermal_printer
BLUE_THERMAL_PATH="$HOME/.pub-cache/hosted/pub.dev/blue_thermal_printer-1.2.3/android/build.gradle"

if [ -f "$BLUE_THERMAL_PATH" ]; then
    if ! grep -q "namespace = \"id.kakzaki.blue_thermal_printer\"" "$BLUE_THERMAL_PATH"; then
        sed -i '' '/^android {/a\
    namespace = "id.kakzaki.blue_thermal_printer"
' "$BLUE_THERMAL_PATH"
        echo "✅ Namespace ajouté au package blue_thermal_printer"
    else
        echo "ℹ️  Le namespace existe déjà dans blue_thermal_printer"
    fi
else
    echo "⚠️  Le package blue_thermal_printer n'a pas été trouvé."
fi

# Corriger flutter_native_splash
FLUTTER_NATIVE_SPLASH_PATH="$HOME/.pub-cache/hosted/pub.dev/flutter_native_splash-2.2.16/android/build.gradle"

if [ -f "$FLUTTER_NATIVE_SPLASH_PATH" ]; then
    if ! grep -q "namespace = \"net.jonhanson.flutter_native_splash\"" "$FLUTTER_NATIVE_SPLASH_PATH"; then
        sed -i '' '/^android {/a\
    namespace = "net.jonhanson.flutter_native_splash"
' "$FLUTTER_NATIVE_SPLASH_PATH"
        echo "✅ Namespace ajouté au package flutter_native_splash"
    else
        echo "ℹ️  Le namespace existe déjà dans flutter_native_splash"
    fi
else
    echo "⚠️  Le package flutter_native_splash n'a pas été trouvé."
fi

echo ""
echo "✅ Correction des namespaces terminée !"

