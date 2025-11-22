import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'CashierDashboard.dart';
import 'ProfileCompletionPage.dart';


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
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Maghali',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const SizedBox(height: 40),

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
      String activityId = userDoc["activityId"];
      String activityName = userDoc["activityName"];
      await prefs.setString("activityId", activityId);
      await prefs.setString("activityName", activityName);
      await prefs.setString("role", userDoc["role"]);

      print("Activity saved : $activityId - $activityName");


      if (!userDoc.exists) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text("Compte introuvable. Veuillez contacter un manager.")));
        setState(() => loading = false);
        return;
      }

      if (userDoc.data()!['profileCompleted'] == true) {
        // Récupérer le nom de l'activité
        String activityName = userDoc['activityName'] ?? 'Activité';
        // 🟩 Save in prefs
        // redirect to dashboard cashier
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => CashierDashboard(activityName: activityName, cashierId: uid,)));
      } else {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => ProfileCompletionPage(uid: uid)));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    }

    setState(() => loading = false);
  }
}
