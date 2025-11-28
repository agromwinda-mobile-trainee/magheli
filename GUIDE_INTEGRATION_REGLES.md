# Guide d'intégration des règles Firestore

## ⚠️ Problème identifié

Les erreurs indiquent que les fonctions sont définies **après** les règles `match`, ce qui n'est pas autorisé.

## ✅ Solution : Ordre correct

Dans Firestore Rules, l'ordre est **CRITIQUE** :

1. **Toutes les fonctions helper** (isAuth, isAdmin, isManager, isCashier, etc.)
2. **Toutes les règles match** (match /stock, match /tickets, etc.)

## 📋 Instructions

### Étape 1 : Ouvrir Firebase Console

1. Allez dans Firebase Console → Firestore Database → Règles
2. Copiez votre fichier de règles actuel (au cas où)

### Étape 2 : Structure complète

Votre fichier de règles doit ressembler à ceci :

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // ============================
    // FONCTIONS HELPER (EN PREMIER)
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
      let user = get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
      let currentStock = resource.data;
      
      if (!("activityName" in user) || user.activityName == null) {
        return false;
      }
      
      if (!("activity" in currentStock) || currentStock.activity == null) {
        return false;
      }
      
      return user.activityName == currentStock.activity;
    }

    function isStockDecreaseOnly() {
      return request.resource.data.keys().hasOnly(["quantity", "updatedAt"])
             && request.resource.data.quantity < resource.data.quantity;
    }

    function notGoingNegative() {
      return request.resource.data.quantity >= 0;
    }

    // ============================
    // RÈGLES MATCH (ENSUITE)
    // ============================

    match /stock/{productId} {
      allow read: if request.auth != null;
      allow create: if isAuth() && (isAdmin() || isManager());
      allow update: if (isManager() || isCashier())
                    && isStockDecreaseOnly()
                    && notGoingNegative()
                    && (isManager() || isSameActivity());
      allow delete: if false;
    }

    match /tickets/{ticketId} {
      allow read, write: if request.auth != null;
    }

    // ... vos autres règles match ici ...
  }
}
```

### Étape 3 : Vérifications

1. ✅ Toutes les fonctions sont **avant** tous les `match`
2. ✅ Les fonctions helper de base (isAuth, isAdmin, etc.) sont définies
3. ✅ La syntaxe est correcte (parenthèses autour de `(isManager() || isCashier())`)

### Étape 4 : Publier

1. Cliquez sur "Publier" dans Firebase Console
2. Vérifiez qu'il n'y a pas d'erreurs de syntaxe
3. Testez la création d'un ticket

## 🔍 Si vous avez encore des erreurs

Vérifiez que :
- [ ] Toutes les fonctions sont définies **avant** les règles `match`
- [ ] Vous n'avez pas de fonctions dupliquées
- [ ] Toutes les fonctions utilisées dans les règles sont définies
- [ ] La syntaxe des parenthèses est correcte




