# Diagnostic : Erreur Permission Denied pour le stock

## 🔍 Problèmes identifiés et corrigés

### 1. ✅ Code de login corrigé

Le code de `loginPage.dart` accédait incorrectement aux données du document utilisateur. **Corrigé**.

### 2. ✅ Règles Firestore améliorées

Nouvelle version des règles qui gère les cas où `activityName` pourrait être null ou ne pas exister.

## 📋 Vérifications à faire

### Étape 1 : Vérifier que les règles Firestore sont à jour

1. Ouvrez Firebase Console → Firestore Database → Règles
2. Vérifiez que la fonction `isSameActivity()` utilise cette version :

```javascript
function isSameActivity() {
  let user = get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
  let currentStock = resource.data;
  
  // Vérifier que l'utilisateur a un activityName
  if (!("activityName" in user) || user.activityName == null) {
    return false;
  }
  
  // Vérifier que le stock a un activity
  if (!("activity" in currentStock) || currentStock.activity == null) {
    return false;
  }
  
  // Comparer le nom de l'activité
  return user.activityName == currentStock.activity;
}
```

3. **Publiez les règles** si elles ont été modifiées

### Étape 2 : Vérifier les données utilisateur dans Firestore

1. Ouvrez Firebase Console → Firestore Database → Collection `users`
2. Trouvez le document de votre utilisateur caissier
3. Vérifiez que les champs suivants existent :
   - ✅ `role` = `"cashier"`
   - ✅ `activityName` = nom de l'activité (ex: `"Restaurant"`)
   - ✅ `activityId` = ID de l'activité
   - ✅ `profileCompleted` = `true`

**Exemple de document utilisateur correct :**
```json
{
  "email": "caissier@example.com",
  "fullName": "Jean Dupont",
  "role": "cashier",
  "activityName": "Restaurant",
  "activityId": "abc123",
  "profileCompleted": true
}
```

### Étape 3 : Vérifier les données stock dans Firestore

1. Ouvrez Firebase Console → Firestore Database → Collection `stock`
2. Vérifiez qu'un produit existe avec :
   - ✅ `activity` = nom de l'activité (ex: `"Restaurant"`)
   - ✅ `name` = nom du produit
   - ✅ `quantity` = quantité en stock

**Exemple de document stock correct :**
```json
{
  "name": "Coca-Cola",
  "activity": "Restaurant",
  "quantity": 50,
  "unit": "bouteille"
}
```

### Étape 4 : Vérifier que les noms correspondent

**IMPORTANT** : Le `activityName` de l'utilisateur doit **exactement** correspondre au `activity` du stock.

- ✅ Utilisateur : `activityName = "Restaurant"`
- ✅ Stock : `activity = "Restaurant"`
- ❌ Utilisateur : `activityName = "Restaurant"` et Stock : `activity = "restaurant"` (différence de casse)
- ❌ Utilisateur : `activityName = "Restaurant"` et Stock : `activity = "Restaurant "` (espace en trop)

## 🛠️ Solution si le problème persiste

### Option A : Vérifier les logs Firebase

1. Ouvrez Firebase Console → Firestore Database → Règles
2. Cliquez sur "Tester les règles"
3. Testez une mise à jour de stock avec les données de votre utilisateur

### Option B : Ajouter des logs de debug

Ajoutez temporairement ce code dans `NewTicketPage.dart` avant la transaction :

```dart
// Debug : Vérifier les données
final userDoc = await FirebaseFirestore.instance
    .collection('users')
    .doc(widget.cashierId)
    .get();
final userData = userDoc.data();
print('DEBUG - User activityName: ${userData?['activityName']}');
print('DEBUG - Stock activity: ${stockQuery.docs.first.data()['activity']}');
print('DEBUG - Match: ${userData?['activityName'] == stockQuery.docs.first.data()['activity']}');
```

### Option C : Vérifier les règles complètes

Assurez-vous que toutes les fonctions nécessaires existent dans vos règles :

- ✅ `isAuth()` - vérifie que l'utilisateur est authentifié
- ✅ `isCashier()` - vérifie que le rôle est "cashier"
- ✅ `isSameActivity()` - compare les activités (CORRIGÉ)
- ✅ `isStockDecreaseOnly()` - vérifie que seule la quantité diminue
- ✅ `notGoingNegative()` - vérifie que la quantité ne devient pas négative

## 📝 Fichiers de référence

- `firestore_rules_stock_fixed_v2.txt` - Règles complètes corrigées
- `FIRESTORE_RULES_STOCK_COMPLETE.md` - Documentation complète



