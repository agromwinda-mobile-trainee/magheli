# Règles Firestore pour le stock - Version corrigée

## 🔧 Correction appliquée

La fonction `isSameActivity()` a été modifiée pour comparer les **noms d'activité** au lieu des IDs.

### ❌ Ancienne version (ne fonctionnait pas)
```javascript
function isSameActivity() {
  let user = get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
  let currentStock = resource.data;
  return user.activityId == currentStock.activityId; // ❌ activityId n'existe pas dans le stock
}
```

### ✅ Nouvelle version (corrigée)
```javascript
function isSameActivity() {
  let user = get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
  let currentStock = resource.data;
  // Comparer le nom de l'activité au lieu de l'ID
  return user.activityName == currentStock.activity; // ✅ Compare les noms
}
```

## 📋 Règles complètes à copier dans Firebase Console

```javascript
// === Règles pour le stock ===
match /stock/{productId} {

  allow read: if request.auth != null;

  // stock doit être créé par l'admin depuis la console
  allow create: if isAuth() && (isAdmin() || isManager());

  //  Seul un caissier peut déduire le stock
  allow update: if isCashier()              // rôle caisse obligatoire
                && isSameActivity()         // même activité (compare par nom)
                && isStockDecreaseOnly()    // la quantité doit baisser
                && notGoingNegative();      // impossible d'aller sous 0

  // 🔥 Empêcher suppression :
  allow delete: if false;
}

// ============================
//      FONCTIONS COMMUNES
// ============================

// L'utilisateur ne peut toucher que le stock de sa propre activité
// CORRIGÉ : Compare activityName (user) avec activity (stock)
function isSameActivity() {
  let user = get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
  let currentStock = resource.data;
  // Comparer le nom de l'activité au lieu de l'ID
  return user.activityName == currentStock.activity;
}

// 🔥 Vérifie que la mise à jour DIMINUE la quantité
function isStockDecreaseOnly() {
  return request.resource.data.keys().hasOnly(["quantity", "updatedAt"])
         && request.resource.data.quantity < resource.data.quantity;
}

// 🔥 Vérifie que la quantité finale ne devient pas négative
function notGoingNegative() {
  return request.resource.data.quantity >= 0;
}
```

## ✅ Instructions de déploiement

1. Ouvrez Firebase Console → Firestore Database → Règles
2. Trouvez la fonction `isSameActivity()` dans vos règles
3. Remplacez-la par la version corrigée ci-dessus (avec vérification null)
4. Cliquez sur "Publier" pour déployer les nouvelles règles

## 🔧 Version améliorée (recommandée)

Utilisez cette version qui gère les cas où `activityName` pourrait être null :

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

## 🎯 Résultat attendu

Après cette correction :
- ✅ Les caissiers pourront créer des tickets
- ✅ Le stock sera correctement déduit lors de la création de tickets
- ✅ Les règles vérifieront que le caissier modifie uniquement le stock de son activité
- ✅ La quantité ne pourra pas devenir négative
- ✅ Seule la quantité peut diminuer (pas d'augmentation)

