import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Screens/loginPage.dart';
import 'error_messages.dart';

class AuthUtils {
  static Future<void> logout(BuildContext context) async {
    try {
      // Déconnecter de Firebase Auth
      await FirebaseAuth.instance.signOut();

      // Nettoyer les SharedPreferences mais conserver l'email pour faciliter la reconnexion
      final prefs = await SharedPreferences.getInstance();
      final lastEmail = prefs.getString("lastEmail"); // Sauvegarder l'email
      await prefs.clear();
      if (lastEmail != null) {
        await prefs.setString("lastEmail", lastEmail); // Restaurer l'email
      }

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
          SnackBar(
            content: Text(ErrorMessages.deconnexionEchouee),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

