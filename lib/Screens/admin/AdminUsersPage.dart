import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage> {
  String? selectedRoleFilter;
  final List<String> roles = [
    'cashier',
    'mainCashier',
    'stockManager',
    'manager',
  ];

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

  Future<void> _deleteUser(String userId, String userName, String userRole) async {
    // Vérifier si l'utilisateur est un admin
    if (userRole == 'admin') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Impossible de supprimer un compte administrateur'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Êtes-vous sûr de vouloir supprimer l\'utilisateur "$userName" ?\n\nCette action est irréversible.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Supprimer', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      // Supprimer l'utilisateur de Firestore
      await FirebaseFirestore.instance.collection('users').doc(userId).delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Utilisateur supprimé avec succès')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la suppression: $e')),
        );
      }
    }
  }

  Future<void> _changeUserRole(String userId, String currentRole) async {
    String? newRole = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le rôle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: roles.map((role) {
            return RadioListTile<String>(
              title: Text(_getRoleDisplayName(role)),
              value: role,
              groupValue: currentRole,
              onChanged: (value) {
                Navigator.pop(context, value);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
        ],
      ),
    );

    if (newRole == null || newRole == currentRole) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'role': newRole,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rôle modifié: ${_getRoleDisplayName(newRole)}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la modification: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Gestion Utilisateurs", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Filtre par rôle
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                const Text(
                  'Filtrer par rôle: ',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: selectedRoleFilter,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('Tous les rôles'),
                      ),
                      ...roles.map((role) {
                        return DropdownMenuItem<String>(
                          value: role,
                          child: Text(_getRoleDisplayName(role)),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedRoleFilter = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          // Liste des utilisateurs
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: selectedRoleFilter == null
                  ? FirebaseFirestore.instance
                      .collection('users')
                      .orderBy('fullName')
                      .snapshots()
                  : FirebaseFirestore.instance
                      .collection('users')
                      .where('role', isEqualTo: selectedRoleFilter)
                      .orderBy('fullName')
                      .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text('Aucun utilisateur trouvé'),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final doc = snapshot.data!.docs[index];
                    final data = doc.data() as Map<String, dynamic>;
                    final userId = doc.id;
                    final fullName = data['fullName'] ?? 'Nom inconnu';
                    final email = data['email'] ?? 'Email inconnu';
                    final role = data['role'] ?? 'Aucun rôle';
                    final activityName = data['activityName'];
                    final phone = data['phone'] ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: _getRoleColor(role),
                          child: Text(
                            fullName.isNotEmpty ? fullName[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        title: Text(
                          fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Email: $email'),
                            Text('Rôle: ${_getRoleDisplayName(role)}'),
                            if (activityName != null) Text('Activité: $activityName'),
                            if (phone.isNotEmpty) Text('Téléphone: $phone'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _changeUserRole(userId, role),
                              tooltip: 'Modifier le rôle',
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.delete,
                                color: role == 'admin' ? Colors.grey : Colors.red,
                              ),
                              onPressed: role == 'admin'
                                  ? null
                                  : () => _deleteUser(userId, fullName, role),
                              tooltip: role == 'admin'
                                  ? 'Impossible de supprimer un admin'
                                  : 'Supprimer',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'cashier':
        return Colors.green;
      case 'mainCashier':
        return Colors.blue;
      case 'stockManager':
        return Colors.orange;
      case 'manager':
        return Colors.purple;
      case 'admin':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
}

