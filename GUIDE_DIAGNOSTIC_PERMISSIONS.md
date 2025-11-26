# 🔍 Guide de Diagnostic : Permission Denied pour le Stock

## Étape 1 : Vérifier les logs de debug

Lancez l'application et essayez de créer un ticket. Regardez les logs dans la console Flutter. Vous devriez voir :

```
🔍 DEBUG - User ID: ...
🔍 DEBUG - User role: "cashier"
🔍 DEBUG - User activityName: "..." (type: String)
🔍 DEBUG - Stock activity: "..." (type: String)
🔍 DEBUG - Match: true/false
```

### ✅ Si `Match: false`

**Problème :** Les noms d'activité ne correspondent pas.

**Solutions :**
1. Vérifiez dans Firebase Console que :
   - Le document `/users/{userId}` a un champ `activityName` (ex: "Restaurant")
   - Le document `/stock/{productId}` a un champ `activity` avec la **même valeur** (ex: "Restaurant")
   - Pas de différences de casse ("Restaurant" vs "restaurant")
   - Pas d'espaces en trop ("Restaurant " vs "Restaurant")

2. Corrigez les données dans Firebase Console si nécessaire.

### ✅ Si `Match: true` mais erreur persiste

**Problème :** Les règles Firestore ont un autre problème.

**Solutions :**
1. Vérifiez que les règles sont bien publiées dans Firebase Console
2. Testez avec la version simplifiée des règles (voir `REGLES_FIRESTORE_STOCK_TEST.txt`)

---

## Étape 2 : Tester avec des règles simplifiées

### Test 1 : Règles minimales

Dans Firebase Console → Firestore → Règles, remplacez temporairement la règle `allow update` par :

```javascript
allow update: if isAuth() && isCashier();
```

**Si ça fonctionne :** Le problème vient des conditions supplémentaires.

**Si ça ne fonctionne pas :** Le problème vient de `isAuth()` ou `isCashier()`.

### Test 2 : Ajouter les vérifications une par une

```javascript
// Test 2a : Avec vérification de diminution
allow update: if isAuth() && isCashier() && isStockDecreaseOnly() && notGoingNegative();

// Test 2b : Avec vérification d'activité
allow update: if isAuth() && isCashier() && isSameActivity();
```

---

## Étape 3 : Vérifier la structure des données

### Document Utilisateur (`/users/{userId}`)

```json
{
  "email": "caissier@example.com",
  "fullName": "Jean Dupont",
  "role": "cashier",           // ✅ Doit être exactement "cashier"
  "activityName": "Restaurant", // ✅ Doit exister et correspondre
  "activityId": "abc123"
}
```

### Document Stock (`/stock/{productId}`)

```json
{
  "name": "Coca-Cola",
  "activity": "Restaurant",     // ✅ Doit correspondre à user.activityName
  "quantity": 50,
  "unit": "bouteille"
}
```

**⚠️ IMPORTANT :**
- `user.activityName` doit **exactement** correspondre à `stock.activity`
- Même casse (majuscules/minuscules)
- Pas d'espaces en trop
- Pas de caractères invisibles

---

## Étape 4 : Vérifier les fonctions helper

Assurez-vous que **toutes** ces fonctions sont définies **AVANT** les règles `match` :

```javascript
function isAuth() { ... }
function isAdmin() { ... }
function isManager() { ... }
function isCashier() { ... }
function isSameActivity() { ... }
function isStockDecreaseOnly() { ... }
function notGoingNegative() { ... }
```

**Ordre correct :**
1. ✅ Toutes les fonctions helper
2. ✅ Toutes les fonctions spécifiques au stock
3. ✅ Les règles `match`

---

## Étape 5 : Vérifier la syntaxe Firestore

### ❌ Syntaxe incorrecte (ne fonctionne pas)

```javascript
function isSameActivity() {
  if (!("activityName" in user)) {
    return false;  // ❌ ERREUR
  }
  return user.activityName == currentStock.activity;
}
```

### ✅ Syntaxe correcte

```javascript
function isSameActivity() {
  let user = get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
  let currentStock = resource.data;
  
  return ("activityName" in user) 
         && user.activityName != null
         && ("activity" in currentStock)
         && currentStock.activity != null
         && user.activityName == currentStock.activity;
}
```

---

## Étape 6 : Vérifier l'utilisateur authentifié

Dans les logs, vérifiez que :
- ✅ `User ID` n'est pas vide
- ✅ `User role` est exactement `"cashier"` (pas "Cashier" ou "CASHIER")
- ✅ L'utilisateur est bien authentifié (pas `null`)

---

## Solutions rapides

### Solution 1 : Règles temporaires permissives (pour test)

```javascript
match /stock/{productId} {
  allow read: if request.auth != null;
  allow create: if request.auth != null;
  allow update: if request.auth != null;  // ⚠️ TEMPORAIRE - pour test uniquement
  allow delete: if false;
}
```

**Si ça fonctionne :** Le problème vient des conditions dans les règles.

**Si ça ne fonctionne pas :** Le problème vient de l'authentification ou de la structure des règles.

### Solution 2 : Vérifier l'ID utilisateur

Dans `NewTicketPage.dart`, vérifiez que `widget.cashierId` correspond bien à l'ID de l'utilisateur authentifié :

```dart
final currentUser = FirebaseAuth.instance.currentUser;
print('Current user ID: ${currentUser?.uid}');
print('Widget cashier ID: ${widget.cashierId}');
```

Si les deux ne correspondent pas, c'est le problème !

---

## Checklist finale

- [ ] Les logs de debug s'affichent correctement
- [ ] `User role` est `"cashier"`
- [ ] `User activityName` correspond à `Stock activity`
- [ ] Les règles Firestore sont publiées sans erreur
- [ ] Toutes les fonctions helper sont définies avant les `match`
- [ ] La syntaxe Firestore est correcte (pas de `if` avec accolades)
- [ ] L'utilisateur est bien authentifié
- [ ] `widget.cashierId` correspond à `FirebaseAuth.instance.currentUser?.uid`

---

## Fichiers de référence

- `REGLES_FIRESTORE_STOCK_COMPLETE.txt` : Règles complètes corrigées
- `REGLES_FIRESTORE_STOCK_TEST.txt` : Règles simplifiées pour test
- `DIAGNOSTIC_PERMISSIONS_STOCK.md` : Guide de diagnostic détaillé



