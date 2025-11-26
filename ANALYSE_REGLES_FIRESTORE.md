# Analyse des règles Firestore pour le stock

## 🔍 Règles fournies

```javascript
match /stock/{productId} {
  allow read: if request.auth != null;
  allow create: if isAuth() && (isAdmin() || isManager());
  
  allow update: if isManager() || isCashier()
                && isSameActivity()
                && isStockDecreaseOnly()
                && notGoingNegative();
  
  allow delete: if false;
}

function isSameActivity() {
  let user = get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
  let currentStock = resource.data;
  return user.activityName == currentStock.activity;
}

function isStockDecreaseOnly() {
  return request.resource.data.keys().hasOnly(["quantity", "updatedAt"])
         && request.resource.data.quantity < resource.data.quantity;
}

function notGoingNegative() {
  return request.resource.data.quantity >= 0;
}
```

## ❌ PROBLÈME CRITIQUE : Erreur de syntaxe dans les règles

### Problème identifié

La règle `allow update` a une erreur de priorité des opérateurs :

```javascript
// ❌ INCORRECT (syntaxe actuelle)
allow update: if isManager() || isCashier()
              && isSameActivity()
              && isStockDecreaseOnly()
              && notGoingNegative();
```

**Problème :** En JavaScript/Firestore Rules, `&&` a une priorité plus élevée que `||`, donc cela est évalué comme :
```javascript
isManager() || (isCashier() && isSameActivity() && isStockDecreaseOnly() && notGoingNegative())
```

Cela signifie qu'un **manager peut modifier le stock SANS vérifier les autres conditions** !

### ✅ Solution

Ajoutez des parenthèses pour clarifier l'intention :

```javascript
// ✅ CORRECT
allow update: if (isManager() || isCashier())
              && isSameActivity()
              && isStockDecreaseOnly()
              && notGoingNegative();
```

Ou mieux encore, séparez les règles pour plus de clarté :

```javascript
// ✅ MEILLEURE SOLUTION
allow update: if (isManager() || isCashier())
              && (
                // Si manager, pas besoin de vérifier l'activité (peut gérer tous les stocks)
                (isManager())
                ||
                // Si caissier, vérifier toutes les conditions
                (isCashier() && isSameActivity() && isStockDecreaseOnly() && notGoingNegative())
              );
```

Mais si vous voulez que même les managers respectent les règles de diminution, utilisez :

```javascript
// ✅ SOLUTION RECOMMANDÉE
allow update: if (isManager() || isCashier())
              && isStockDecreaseOnly()
              && notGoingNegative()
              && (isManager() || isSameActivity());
```

## ✅ Vérification du code

### Code actuel (après corrections)

```dart
transaction.update(stockRef, {
  'quantity': newQty,
  'updatedAt': FieldValue.serverTimestamp(),
});
```

**✅ Compatible avec `isStockDecreaseOnly()`** :
- Seuls `quantity` et `updatedAt` sont modifiés ✓
- `newQty < currentQty` est vérifié avant (ligne 359) ✓

**✅ Compatible avec `notGoingNegative()`** :
- `newQty >= 0` est vérifié avant (ligne 359) ✓

**✅ Compatible avec `isSameActivity()`** :
- Compare `user.activityName` avec `currentStock.activity` ✓
- Le code utilise `widget.activityName` qui correspond à `user.activityName` ✓

## 🔧 Corrections nécessaires dans les règles Firestore

### Correction 1 : Priorité des opérateurs

```javascript
allow update: if (isManager() || isCashier())
              && isStockDecreaseOnly()
              && notGoingNegative()
              && (isManager() || isSameActivity());
```

**Explication :**
- Un manager peut modifier n'importe quel stock (sans vérifier l'activité)
- Un caissier ne peut modifier que le stock de son activité
- Les deux doivent respecter `isStockDecreaseOnly()` et `notGoingNegative()`

### Correction 2 : Si vous voulez que les managers respectent aussi l'activité

```javascript
allow update: if (isManager() || isCashier())
              && isSameActivity()
              && isStockDecreaseOnly()
              && notGoingNegative();
```

## 📋 Checklist de compatibilité

- [x] Code modifie seulement `quantity` et `updatedAt` ✓
- [x] Code vérifie que `newQty < currentQty` ✓
- [x] Code vérifie que `newQty >= 0` ✓
- [x] Code utilise `activityName` qui correspond à `user.activityName` ✓
- [ ] **Règles Firestore : Corriger la priorité des opérateurs** ❌

## 🎯 Action requise

**Corrigez les règles Firestore** en ajoutant des parenthèses autour de `(isManager() || isCashier())` pour que toutes les conditions soient correctement évaluées.



