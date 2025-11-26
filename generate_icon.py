#!/usr/bin/env python3
"""
Script pour générer automatiquement l'icône de l'application Maghali
Fond noir avec texte "maghali" en italique blanc
"""

try:
    from PIL import Image, ImageDraw, ImageFont
    import os
    
    def create_icon():
        # Dimensions
        size = 1024
        
        # Créer l'image avec fond noir
        img = Image.new('RGB', (size, size), color='#000000')
        draw = ImageDraw.Draw(img)
        
        # Essayer de charger une police avec support italique
        # Si aucune police n'est trouvée, on utilisera la police par défaut
        font_size = 200
        try:
            # Essayer différentes polices système
            font_paths = [
                '/System/Library/Fonts/Helvetica.ttc',  # macOS
                '/usr/share/fonts/truetype/dejavu/DejaVuSans-Oblique.ttf',  # Linux
                'C:/Windows/Fonts/ariali.ttf',  # Windows
            ]
            
            font = None
            for font_path in font_paths:
                if os.path.exists(font_path):
                    try:
                        font = ImageFont.truetype(font_path, font_size)
                        break
                    except:
                        continue
            
            if font is None:
                # Utiliser la police par défaut
                font = ImageFont.load_default()
                print("⚠️  Utilisation de la police par défaut (pas d'italique)")
        except Exception as e:
            font = ImageFont.load_default()
            print(f"⚠️  Utilisation de la police par défaut: {e}")
        
        # Texte à afficher
        text = "maghali"
        
        # Calculer la position pour centrer le texte
        bbox = draw.textbbox((0, 0), text, font=font)
        text_width = bbox[2] - bbox[0]
        text_height = bbox[3] - bbox[1]
        
        x = (size - text_width) / 2
        y = (size - text_height) / 2 - bbox[1]
        
        # Dessiner le texte en blanc
        draw.text((x, y), text, fill='#FFFFFF', font=font)
        
        # Sauvegarder app_icon.png
        icon_path = 'assets/icon/app_icon.png'
        img.save(icon_path)
        print(f"✅ Icône créée: {icon_path}")
        
        # Créer app_icon_foreground.png (même image mais avec fond transparent)
        img_foreground = Image.new('RGBA', (size, size), color=(0, 0, 0, 0))
        draw_foreground = ImageDraw.Draw(img_foreground)
        
        # Dessiner le texte en blanc
        draw_foreground.text((x, y), text, fill='#FFFFFF', font=font)
        
        # Sauvegarder app_icon_foreground.png
        foreground_path = 'assets/icon/app_icon_foreground.png'
        img_foreground.save(foreground_path)
        print(f"✅ Icône foreground créée: {foreground_path}")
        
        print("\n✅ Icônes générées avec succès !")
        print("Exécutez maintenant: flutter pub run flutter_launcher_icons")
        
    if __name__ == '__main__':
        create_icon()
        
except ImportError:
    print("❌ Le module PIL (Pillow) n'est pas installé.")
    print("\nPour installer Pillow:")
    print("  pip3 install Pillow")
    print("\nOu créez manuellement les icônes:")
    print("  1. Créez une image 1024x1024 pixels")
    print("  2. Fond noir (#000000)")
    print("  3. Texte 'maghali' en italique, couleur blanche")
    print("  4. Sauvegardez comme assets/icon/app_icon.png")
    print("  5. Créez app_icon_foreground.png (même design, fond transparent)")
    exit(1)



