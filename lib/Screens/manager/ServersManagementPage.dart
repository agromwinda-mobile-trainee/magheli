import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../common/error_messages.dart';
import 'ServersStatsPage.dart';

class ServersManagementPage extends StatefulWidget {
  const ServersManagementPage({super.key});

  @override
  State<ServersManagementPage> createState() => _ServersManagementPageState();
}

class _ServersManagementPageState extends State<ServersManagementPage> {
  String? selectedActivityFilter;
  List<Map<String, dynamic>> activities = [];

  @override
  void initState() {
    super.initState();
    _loadActivities();
  }

  Future<void> _loadActivities() async {
    try {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMessages.fromException(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Gestion des Serveurs',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ServersStatsPage(),
                ),
              );
            },
            tooltip: 'Statistiques',
          ),
        ],
      ),
      body: Column(
        children: [
          // Filtre par activité
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    'Filtrer par activité: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: selectedActivityFilter,
                    isExpanded: true,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    hint: const Text(
                      'Toutes les activités',
                      overflow: TextOverflow.ellipsis,
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text(
                          'Toutes les activités',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ...activities.map((activity) {
                        return DropdownMenuItem<String>(
                          value: activity['name'] as String,
                          child: Text(
                            activity['name'] as String,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        );
                      }),
                    ],
                    onChanged: (value) {
                      setState(() {
                        selectedActivityFilter = value;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          // Liste des serveurs
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: selectedActivityFilter == null
                  ? FirebaseFirestore.instance
                      .collection('servers')
                      .orderBy('fullName')
                      .snapshots()
                  : FirebaseFirestore.instance
                      .collection('servers')
                      .where('activity', isEqualTo: selectedActivityFilter)
                      .orderBy('fullName')
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      ErrorMessages.fromException(snapshot.error),
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person_off,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Aucun serveur trouvé',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final servers = snapshot.data!.docs;

                return ListView.builder(
                  itemCount: servers.length,
                  itemBuilder: (context, index) {
                    final server = servers[index];
                    final data = server.data() as Map<String, dynamic>;
                    final fullName = data['fullName'] ?? 'Nom inconnu';
                    final activity = data['activity'] ?? 'Activité inconnue';
                    final phone = data['phone'] as String?;
                    final email = data['email'] as String?;

                    return Card(
                      margin: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue[100],
                          child: Icon(
                            Icons.person,
                            color: Colors.blue[700],
                          ),
                        ),
                        title: Text(
                          fullName,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Activité: $activity',
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            if (phone != null)
                              Text(
                                'Téléphone: $phone',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                            if (email != null)
                              Text(
                                'Email: $email',
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () => _editServer(server.id, data),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _deleteServer(server.id, fullName),
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
      floatingActionButton: FloatingActionButton(
        onPressed: _addServer,
        backgroundColor: Colors.black,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  void _addServer() {
    _showServerDialog();
  }

  void _editServer(String serverId, Map<String, dynamic> currentData) {
    _showServerDialog(
      serverId: serverId,
      currentData: currentData,
    );
  }

  void _showServerDialog({
    String? serverId,
    Map<String, dynamic>? currentData,
  }) {
    final nameController = TextEditingController(
      text: currentData?['fullName'] ?? '',
    );
    final phoneController = TextEditingController(
      text: currentData?['phone'] ?? '',
    );
    final emailController = TextEditingController(
      text: currentData?['email'] ?? '',
    );
    String? selectedActivity;

    if (currentData != null) {
      selectedActivity = currentData['activity'] as String?;
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(serverId == null ? 'Ajouter un serveur' : 'Modifier le serveur'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet *',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: phoneController,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedActivity,
                  decoration: const InputDecoration(
                    labelText: 'Activité *',
                    border: OutlineInputBorder(),
                  ),
                  items: activities.map((activity) {
                    return DropdownMenuItem<String>(
                      value: activity['name'] as String,
                      child: Text(activity['name'] as String),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedActivity = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            ElevatedButton(
              onPressed: () => _saveServer(
                serverId: serverId,
                name: nameController.text.trim(),
                phone: phoneController.text.trim(),
                email: emailController.text.trim(),
                activity: selectedActivity,
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
              ),
              child: const Text(
                'Enregistrer',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveServer({
    String? serverId,
    required String name,
    required String phone,
    required String email,
    required String? activity,
  }) async {
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Le nom est obligatoire'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (activity == null || activity.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('L\'activité est obligatoire'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.pop(context); // Fermer le dialog

    try {
      final serverData = <String, dynamic>{
        'fullName': name,
        'activity': activity,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (phone.isNotEmpty) {
        serverData['phone'] = phone;
      }

      if (email.isNotEmpty) {
        serverData['email'] = email;
      }

      if (serverId == null) {
        // Créer un nouveau serveur
        serverData['createdAt'] = FieldValue.serverTimestamp();
        await FirebaseFirestore.instance.collection('servers').add(serverData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Serveur créé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        // Modifier un serveur existant
        await FirebaseFirestore.instance
            .collection('servers')
            .doc(serverId)
            .update(serverData);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Serveur modifié avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMessages.fromException(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteServer(String serverId, String serverName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la suppression'),
        content: Text('Êtes-vous sûr de vouloir supprimer le serveur "$serverName" ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await FirebaseFirestore.instance
          .collection('servers')
          .doc(serverId)
          .delete();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Serveur supprimé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ErrorMessages.fromException(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

