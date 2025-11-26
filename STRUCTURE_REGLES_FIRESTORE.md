# Structure correcte des règles Firestore

## ⚠️ Ordre important

Dans Firestore Rules, l'ordre est **CRITIQUE** :

1. **D'abord** : Toutes les fonctions helper
2. **Ensuite** : Toutes les règles `match`

## ✅ Structure correcte

```javascript
// ============================
// 1. FONCTIONS HELPER (EN PREMIER)
// ============================

function isAuth() {
  return request.auth != null;
}

function isAdmin() {
  return isAuth() && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
}

function isManager() {
  return isAuth() && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'manager';
}

function isCashier() {
  return isAuth() && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'cashier';
}

function isSameActivity() {
  // ... votre fonction
}

function isStockDecreaseOnly() {
  // ... votre fonction
}

function notGoingNegative() {
  // ... votre fonction
}

// ============================
// 2. RÈGLES MATCH (ENSUITE)
// ============================

match /stock/{productId} {
  // ... vos règles
}

match /tickets/{ticketId} {
  // ... vos règles
}

// etc.
```

## ❌ Erreur courante

```javascript
// ❌ INCORRECT - Fonctions après les règles match
match /stock/{productId} {
  // ...
}

function isSameActivity() {  // ❌ Erreur: Unexpected 'function'
  // ...
}
```

## ✅ Solution

Déplacez **toutes les fonctions** avant **tous les `match`**.



