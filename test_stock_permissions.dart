// Script de test pour diagnostiquer les problèmes de permissions sur le stock
// À exécuter dans Flutter DevTools ou en ajoutant temporairement dans votre app

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<void> testStockPermissions() async {
  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print('❌ Aucun utilisateur connecté');
      return;
    }

    print('✅ Utilisateur connecté: ${user.email}');
    print('   UID: ${user.uid}');

    // 1. Vérifier les données utilisateur
    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (!userDoc.exists) {
      print('❌ Document utilisateur n\'existe pas');
      return;
    }

    final userData = userDoc.data()!;
    print('\n📋 Données utilisateur:');
    print('   - role: ${userData['role']}');
    print('   - activityName: ${userData['activityName']}');
    print('   - activityId: ${userData['activityId']}');
    print('   - profileCompleted: ${userData['profileCompleted']}');

    if (userData['role'] != 'cashier') {
      print('⚠️  L\'utilisateur n\'est pas un caissier');
      return;
    }

    final activityName = userData['activityName'] as String?;
    if (activityName == null || activityName.isEmpty) {
      print('❌ activityName est null ou vide');
      return;
    }

    // 2. Vérifier les produits en stock
    final stockQuery = await FirebaseFirestore.instance
        .collection('stock')
        .where('activity', isEqualTo: activityName)
        .limit(5)
        .get();

    print('\n📦 Produits en stock pour l\'activité "$activityName":');
    if (stockQuery.docs.isEmpty) {
      print('   ⚠️  Aucun produit trouvé');
      return;
    }

    for (var doc in stockQuery.docs) {
      final stockData = doc.data();
      print('   - ${stockData['name']}: ${stockData['quantity']} ${stockData['unit'] ?? 'unité'}');
      print('     activity: ${stockData['activity']}');
      print('     Match avec utilisateur: ${stockData['activity'] == activityName}');
    }

    // 3. Tester une mise à jour (simulation)
    if (stockQuery.docs.isNotEmpty) {
      final testProduct = stockQuery.docs.first;
      final testRef = FirebaseFirestore.instance
          .collection('stock')
          .doc(testProduct.id);

      print('\n🧪 Test de mise à jour du stock...');
      print('   Produit: ${testProduct.data()['name']}');
      print('   Quantité actuelle: ${testProduct.data()['quantity']}');

      try {
        // Tenter une mise à jour (ne sera pas réellement appliquée si les règles bloquent)
        await FirebaseFirestore.instance.runTransaction((transaction) async {
          final snapshot = await transaction.get(testRef);
          if (!snapshot.exists) {
            throw Exception('Document n\'existe pas');
          }

          final currentQty = (snapshot.data()?['quantity'] ?? 0) as int;
          final newQty = currentQty - 1;

          if (newQty < 0) {
            throw Exception('Stock insuffisant');
          }

          transaction.update(testRef, {
            'quantity': newQty,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        });

        print('   ✅ Mise à jour réussie !');
      } catch (e) {
        print('   ❌ Erreur lors de la mise à jour: $e');
        if (e.toString().contains('permission-denied')) {
          print('\n🔍 DIAGNOSTIC: Erreur de permission détectée');
          print('   Vérifiez:');
          print('   1. Les règles Firestore sont-elles à jour ?');
          print('   2. activityName utilisateur = activity stock ?');
          print('   3. Le rôle est-il bien "cashier" ?');
        }
      }
    }
  } catch (e) {
    print('❌ Erreur: $e');
  }
}



