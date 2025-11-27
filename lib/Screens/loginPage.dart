import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../common/role_router.dart';
import '../common/error_messages.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool loading = false;

  @override
  void initState() {
    super.initState();
    _loadLastEmail();
  }

  Future<void> _loadLastEmail() async {
    final prefs = await SharedPreferences.getInstance();
    final lastEmail = prefs.getString("lastEmail");
    if (lastEmail != null && lastEmail.isNotEmpty) {
      setState(() {
        emailController.text = lastEmail;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 60),
                      // Logo avec icône de restaurant
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.restaurant,
                          size: 80,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Texte Maghali stylisé
                      const Text(
                        'MAGHALI',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Gestion interne',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 60),

                      TextField(
                        controller: emailController,
                        decoration: const InputDecoration(labelText: 'Email'),
                      ),
                      const SizedBox(height: 16),

                      TextField(
                        controller: passwordController,
                        obscureText: true,
                        decoration: const InputDecoration(labelText: 'Mot de passe'),
                      ),
                      const SizedBox(height: 32),

                      ElevatedButton(
                        onPressed: loading ? null : _login,
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12))),
                        child: loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('Connexion',
                            style: TextStyle(color: Colors.white, fontSize: 18)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Signature en bas
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '@bymaxedena',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _login() async {
    setState(() => loading = true);
    final prefs = await SharedPreferences.getInstance();

    try {
      UserCredential cred = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim());

      final uid = cred.user!.uid;
      final userDoc =
      await FirebaseFirestore.instance.collection('users').doc(uid).get();
      
      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Compte introuvable. Veuillez contacter un manager.")));
        setState(() => loading = false);
        return;
      }

      final userData = userDoc.data()!;
      String? activityId = userData["activityId"] as String?;
      String? activityName = userData["activityName"] as String?;
      String? fullName = userData["fullName"] as String?;
      
      // Sauvegarder dans SharedPreferences (peut être null pour certains rôles)
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

      // Sauvegarder l'email pour pré-remplir le champ lors de la prochaine connexion
      await prefs.setString("lastEmail", emailController.text.trim());

      print("Activity saved : $activityId - $activityName");
      print("FullName saved : $fullName");

      // Sauvegarder profileCompleted dans prefs
      await prefs.setBool("profileCompleted", userData['profileCompleted'] ?? false);

      // Router selon le rôle
      await RoleRouter.routeAfterLogin(context, uid);
    } on FirebaseAuthException catch (e) {
      String errorMessage = ErrorMessages.connexionEchec;
      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        errorMessage = ErrorMessages.emailOuMotDePasseIncorrect;
      } else if (e.code == 'user-disabled') {
        errorMessage = 'Ce compte a été désactivé. Contactez un administrateur.';
      } else if (e.code == 'too-many-requests') {
        errorMessage = 'Trop de tentatives. Veuillez réessayer plus tard.';
      } else if (e.code == 'network-request-failed') {
        errorMessage = ErrorMessages.erreurReseau;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ErrorMessages.fromException(e)),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => loading = false);
  }
}
