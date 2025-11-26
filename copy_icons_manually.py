#!/usr/bin/env python3
"""
Script pour copier manuellement les icônes dans les dossiers Android et iOS
"""

from PIL import Image
import os
import shutil

def resize_and_copy_icon(source_path, dest_path, size):
    """Redimensionne et copie une icône"""
    img = Image.open(source_path)
    img_resized = img.resize((size, size), Image.Resampling.LANCZOS)
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    img_resized.save(dest_path)
    print(f"✅ Créé: {dest_path} ({size}x{size})")

def main():
    source_icon = "assets/icon/app_icon.png"
    source_foreground = "assets/icon/app_icon_foreground.png"
    
    if not os.path.exists(source_icon):
        print(f"❌ Fichier source introuvable: {source_icon}")
        return
    
    # Tailles Android
    android_sizes = {
        "mdpi": 48,
        "hdpi": 72,
        "xhdpi": 96,
        "xxhdpi": 144,
        "xxxhdpi": 192,
    }
    
    # Copier les icônes Android
    for density, size in android_sizes.items():
        dest_path = f"android/app/src/main/res/mipmap-{density}/ic_launcher.png"
        resize_and_copy_icon(source_icon, dest_path, size)
        
        # Icône ronde
        dest_path_round = f"android/app/src/main/res/mipmap-{density}/ic_launcher_round.png"
        resize_and_copy_icon(source_icon, dest_path_round, size)
    
    # Icônes adaptatives Android (foreground)
    adaptive_sizes = {
        "mdpi": 108,
        "hdpi": 162,
        "xhdpi": 216,
        "xxhdpi": 324,
        "xxxhdpi": 432,
    }
    
    if os.path.exists(source_foreground):
        for density, size in adaptive_sizes.items():
            dest_path = f"android/app/src/main/res/mipmap-{density}/ic_launcher_foreground.png"
            resize_and_copy_icon(source_foreground, dest_path, size)
    
    # Tailles iOS
    ios_sizes = {
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-20x20@3x.png": 60,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-29x29@3x.png": 87,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-40x40@3x.png": 120,
        "Icon-App-60x60@2x.png": 120,
        "Icon-App-60x60@3x.png": 180,
        "Icon-App-20x20@1x.png": 20,
        "Icon-App-20x20@2x.png": 40,
        "Icon-App-29x29@1x.png": 29,
        "Icon-App-29x29@2x.png": 58,
        "Icon-App-40x40@1x.png": 40,
        "Icon-App-40x40@2x.png": 80,
        "Icon-App-76x76@1x.png": 76,
        "Icon-App-76x76@2x.png": 152,
        "Icon-App-83.5x83.5@2x.png": 167,
        "Icon-App-1024x1024@1x.png": 1024,
    }
    
    ios_dir = "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    os.makedirs(ios_dir, exist_ok=True)
    
    for filename, size in ios_sizes.items():
        dest_path = os.path.join(ios_dir, filename)
        resize_and_copy_icon(source_icon, dest_path, size)
    
    print("\n✅ Toutes les icônes ont été copiées avec succès !")
    print("Nettoyez et reconstruisez le projet:")
    print("  flutter clean")
    print("  flutter pub get")
    print("  flutter run")

if __name__ == '__main__':
    main()



