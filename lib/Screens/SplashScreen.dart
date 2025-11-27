import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'loginPage.dart';
import '../common/role_router.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuthState();
  }

  Future<void> _checkAuthState() async {
    // Attendre un court délai pour l'animation du splash
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final user = FirebaseAuth.instance.currentUser;

    // Si l'utilisateur est connecté, vérifier ses données
    if (user != null) {
      try {
        final prefs = await SharedPreferences.getInstance();
        
        // Vérifier si les données sont déjà en cache
        final role = prefs.getString("role");

        // Si on a les données en cache, rediriger directement
        if (role != null && role.isNotEmpty) {
          // Mettre à jour les données depuis Firestore (au cas où elles auraient changé)
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();

          if (userDoc.exists) {
            final userData = userDoc.data()!;
            String? activityId = userData["activityId"] as String?;
            String? activityName = userData["activityName"] as String?;
            String? fullName = userData["fullName"] as String?;

            // Mettre à jour SharedPreferences
            if (activityId != null) {
              await prefs.setString("activityId", activityId);
            }
            if (activityName != null) {
              await prefs.setString("activityName", activityName);
            }
            if (fullName != null) {
              await prefs.setString("fullName", fullName);
            }
            await prefs.setString("role", userData["role"] as String? ?? "");
            await prefs.setBool("profileCompleted", userData['profileCompleted'] ?? false);

            // Rediriger selon le rôle
            if (mounted) {
              await RoleRouter.routeAfterLogin(context, user.uid);
              return;
            }
          }
        }
      } catch (e) {
        // En cas d'erreur, rediriger vers login
        print("Erreur lors de la vérification de la session: $e");
      }
    }

    // Si pas connecté ou erreur, rediriger vers login
    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icône du restaurant
            Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restaurant,
                size: 100,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 40),
            // Texte MAGHALI
            const Text(
              'MAGHALI',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 56,
                fontWeight: FontWeight.bold,
                letterSpacing: 3,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Gestion interne',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 60),
            // Indicateur de chargement
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}



