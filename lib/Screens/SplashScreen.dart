import 'package:flutter/material.dart';
import 'dart:async';
import 'loginPage.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Attendre 2 secondes avant de naviguer vers la page de connexion
    Timer(const Duration(seconds: 2), () {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    });
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



