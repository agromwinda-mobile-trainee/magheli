import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'CashierDashboard.dart';



class ProfileCompletionPage extends StatefulWidget {
  final String uid;
  const ProfileCompletionPage({super.key, required this.uid});

  @override
  State<ProfileCompletionPage> createState() => _ProfileCompletionPageState();
}

class _ProfileCompletionPageState extends State<ProfileCompletionPage> {
  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  bool loading = false;
  String activityName = '';
  String userId='';

  @override
  void initState() {
    super.initState();
    _fetchActivity();
    _fetchuserId();
  }

  Future<void> _fetchActivity() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
    setState(() {
      activityName = doc.data()?['activity'] ?? '';
    });
  }
  Future<void> _fetchuserId() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(widget.uid).get();
    setState(() {
      userId = doc.data()?['uid'] ?? '';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Compléter votre profil'), backgroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Nom complet'),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: phoneController,
              decoration: const InputDecoration(labelText: 'Téléphone'),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: loading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12))),
              child: loading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("Enregistrer",
                  style: TextStyle(color: Colors.white, fontSize: 18)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (nameController.text.isEmpty || phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez remplir tous les champs')));
      return;
    }

    setState(() => loading = true);

    await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
      'fullName': nameController.text.trim(),
      'phone': phoneController.text.trim(),
      'profileCompleted': true,
    });

    setState(() => loading = false);

    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => CashierDashboard(activityName:activityName, cashierId: userId,)));
  }
}
