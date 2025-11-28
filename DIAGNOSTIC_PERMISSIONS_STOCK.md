# Diagnostic : Permission Denied pour la mise à jour du stock

## 🔍 Problèmes potentiels

### 1. Vérifier que les règles sont bien déployées

Assurez-vous que :
- ✅ Les règles ont été publiées dans Firebase Console
- ✅ Aucune erreur de syntaxe lors de la publication
- ✅ Les fonctions helper (isAuth, isCashier, isManager, isAdmin) sont définies

### 2. Vérifier la structure des données

**Dans Firestore, vérifiez que :**

#### Document utilisateur (`/users/{userId}`)
```json
{
  "role": "cashier",
  "activityName": "Restaurant",  // ✅ Doit exister
  "activityId": "abc123"
}
```

#### Document stock (`/stock/{productId}`)
```json
{
  "name": "Coca-Cola",
  "activity": "Restaurant",  // ✅ Doit correspondre à user.activityName
  "quantity": 50
}
```

**⚠️ IMPORTANT :** `user.activityName` doit **exactement** correspondre à `stock.activity` (même casse, pas d'espaces)

### 3. Problème potentiel : Comparaison de chaînes

La fonction `isSameActivity()` compare :
```javascript
user.activityName == currentStock.activity
```

**Vérifiez que :**
- Les deux valeurs sont des strings
- Pas de différences de casse ("Restaurant" vs "restaurant")
- Pas d'espaces en trop ("Restaurant " vs "Restaurant")

### 4. Test de la fonction isSameActivity()

Ajoutez temporairement ce code dans votre app pour tester :

```dart
// Dans _createTicket(), avant la transaction
final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(widget.cashierId)
    .get();
final userData = userDoc.data();
final userActivityName = userData?['activityName'];

final stockDoc = await stockQuery.docs.first.reference.get();
final stockData = stockDoc.data();
final stockActivity = stockData?['activity'];

print('DEBUG - User activityName: "$userActivityName"');
print('DEBUG - Stock activity: "$stockActivity"');
print('DEBUG - Match: ${userActivityName == stockActivity}');
print('DEBUG - User role: ${userData?['role']}');
```

### 5. Vérifier que isCashier() fonctionne

La fonction `isCashier()` doit retourner `true`. Vérifiez que :
- L'utilisateur est authentifié
- Le document utilisateur existe
- Le champ `role` est exactement `"cashier"` (pas "Cashier" ou "CASHIER")

### 6. Solution alternative : Simplifier temporairement les règles

Pour tester, simplifiez temporairement la règle `allow update` :

```javascript
// Version simplifiée pour test
allow update: if isAuth() && isCashier();
```

Si ça fonctionne, ajoutez progressivement les autres conditions :
1. `&& isStockDecreaseOnly()`
2. `&& notGoingNegative()`
3. `&& isSameActivity()`

Cela vous permettra d'identifier quelle condition échoue.




