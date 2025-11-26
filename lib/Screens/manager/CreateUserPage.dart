import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../common/error_messages.dart';
import '../loginPage.dart';

class CreateUserPage extends StatefulWidget {
  const CreateUserPage({super.key});

  @override
  State<CreateUserPage> createState() => _CreateUserPageState();
}

class _CreateUserPageState extends State<CreateUserPage> {
  final _formKey = GlobalKey<FormState>();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final fullNameController = TextEditingController();
  final phoneController = TextEditingController();
  
  String? selectedRole;
  String? selectedActivityId;
  String? selectedActivityName;
  
  List<Map<String, dynamic>> activities = [];
  bool loading = false;
  bool showPassword = false;

  final List<String> roles = [
    'cashier',
    'mainCashier',
    'stockManager',
    'manager',
  ];

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    final query = await FirebaseFirestore.instance
        .collection('activities')
        .get();

    setState(() {
      activities = query.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['activityName'] ?? 'Activité inconnue',
        };
      }).toList();
    });
  }

  bool _requiresActivity() {
    return selectedRole == 'cashier';
  }

  Future<void> _createUser() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un rôle')),
      );
      return;
    }

    if (_requiresActivity() && (selectedActivityId == null || selectedActivityName == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner une activité pour le caissier')),
      );
      return;
    }

    setState(() => loading = true);

    // Sauvegarder l'email du manager actuel avant de créer l'utilisateur
    final currentManagerEmail = FirebaseAuth.instance.currentUser?.email;
    
    if (currentManagerEmail == null) {
      setState(() => loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(ErrorMessages.connexionRequise),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    try {
      // Créer l'utilisateur avec Firebase Auth
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailController.text.trim(),
            password: passwordController.text.trim(),
          );

      final uid = userCredential.user!.uid;

      // Créer le document utilisateur dans Firestore
      // À ce moment, le manager est toujours connecté (car createUserWithEmailAndPassword
      // connecte automatiquement le nouvel utilisateur, mais les règles Firebase vérifient
      // le rôle du manager dans le document users, pas la session actuelle)
      final userData = <String, dynamic>{
        'email': emailController.text.trim(),
        'fullName': fullNameController.text.trim(),
        'phone': phoneController.text.trim(),
        'role': selectedRole,
        'profileCompleted': false,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Ajouter les informations d'activité si nécessaire
      if (_requiresActivity()) {
        userData['activityId'] = selectedActivityId;
        userData['activityName'] = selectedActivityName;
      }

      // IMPORTANT: Créer le document Firestore AVANT de déconnecter
      // Les règles Firebase vérifient que l'utilisateur actuel (le manager) 
      // a le rôle manager ou admin dans son document users
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(userData);

      // Déconnecter l'utilisateur créé (il devra se connecter avec son mot de passe)
      await FirebaseAuth.instance.signOut();

      // Se reconnecter en tant que manager
      // Note: On ne peut pas se reconnecter automatiquement sans le mot de passe
      // Le manager devra se reconnecter manuellement
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMessages.utilisateurCree),
            duration: const Duration(seconds: 3),
            backgroundColor: Colors.green,
          ),
        );

        // Attendre un peu avant de rediriger pour que le message soit visible
        await Future.delayed(const Duration(seconds: 1));

        // Rediriger vers la page de login
        if (mounted) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        }
      }
    } on FirebaseAuthException catch (e) {
      String errorMessage = ErrorMessages.utilisateurNonCree;
      if (e.code == 'weak-password') {
        errorMessage = ErrorMessages.motDePasseFaible;
      } else if (e.code == 'email-already-in-use') {
        errorMessage = ErrorMessages.emailDejaUtilise;
      } else if (e.code == 'invalid-email') {
        errorMessage = ErrorMessages.emailInvalide;
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
    } finally {
      setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Créer Utilisateur", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: fullNameController,
                decoration: InputDecoration(
                  labelText: 'Nom complet *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.person),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez saisir le nom complet';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Email *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.email),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez saisir un email';
                  }
                  if (!value.contains('@')) {
                    return 'Email invalide';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                obscureText: !showPassword,
                decoration: InputDecoration(
                  labelText: 'Mot de passe *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.lock),
                  suffixIcon: IconButton(
                    icon: Icon(showPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () {
                      setState(() => showPassword = !showPassword);
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Veuillez saisir un mot de passe';
                  }
                  if (value.length < 6) {
                    return 'Le mot de passe doit contenir au moins 6 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Téléphone',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedRole,
                decoration: InputDecoration(
                  labelText: 'Rôle *',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.work),
                ),
                items: roles.map((role) {
                  return DropdownMenuItem<String>(
                    value: role,
                    child: Text(_getRoleDisplayName(role)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    selectedRole = value;
                    if (!_requiresActivity()) {
                      selectedActivityId = null;
                      selectedActivityName = null;
                    }
                  });
                },
                validator: (value) {
                  if (value == null) {
                    return 'Veuillez sélectionner un rôle';
                  }
                  return null;
                },
              ),
              if (_requiresActivity()) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedActivityId,
                  decoration: InputDecoration(
                    labelText: 'Activité *',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    prefixIcon: const Icon(Icons.business),
                  ),
                  items: activities.map((activity) {
                    return DropdownMenuItem<String>(
                      value: activity['id'] as String,
                      child: Text(activity['name'] as String),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedActivityId = value;
                      selectedActivityName = activities
                          .firstWhere((a) => a['id'] == value)['name'] as String;
                    });
                  },
                  validator: (value) {
                    if (_requiresActivity() && value == null) {
                      return 'Veuillez sélectionner une activité';
                    }
                    return null;
                  },
                ),
              ],
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: loading ? null : _createUser,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Créer l\'utilisateur',
                        style: TextStyle(color: Colors.white, fontSize: 18),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getRoleDisplayName(String role) {
    switch (role) {
      case 'cashier':
        return 'Caissier';
      case 'mainCashier':
        return 'Caissier Principale';
      case 'stockManager':
        return 'Gestionnaire Stock';
      case 'manager':
        return 'Manager';
      case 'admin':
        return 'Admin';
      default:
        return role;
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    fullNameController.dispose();
    phoneController.dispose();
    super.dispose();
  }
}

