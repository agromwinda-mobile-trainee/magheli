import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Screens/loginPage.dart';

class AuthUtils {
  static Future<void> logout(BuildContext context) async {
    try {
      // Déconnecter de Firebase Auth
      await FirebaseAuth.instance.signOut();

      // Nettoyer les SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      // Rediriger vers la page de login
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
          (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la déconnexion: $e')),
        );
      }
    }
  }
}

