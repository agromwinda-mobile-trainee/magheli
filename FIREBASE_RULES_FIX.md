# Correction des règles Firestore pour le stock

## Problème identifié

Les règles Firestore pour le stock utilisent :
```javascript
function isSameActivity() {
  let user = get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
  let currentStock = resource.data;
  return user.activityId == currentStock.activityId;
}
```

Mais dans le code :
- Le stock utilise le champ `activity` (nom de l'activité, String)
- L'utilisateur a `activityId` (ID de l'activité) et `activityName` (nom de l'activité)

**Résultat** : La comparaison échoue car `currentStock.activityId` n'existe pas.

## Solution proposée : Modifier les règles Firestore

### Option 1 : Comparer les noms d'activité (Recommandé)

```javascript
// L'utilisateur ne peut toucher que le stock de sa propre activité
function isSameActivity() {
  let user = get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
  let currentStock = resource.data;
  // Comparer le nom de l'activité au lieu de l'ID
  return user.activityName == currentStock.activity;
}
```

**Avantages** :
- Fonctionne avec la structure actuelle du stock
- Pas besoin de migration des données existantes
- Plus simple et cohérent

### Option 2 : Ajouter activityId au stock (Alternative)

Si vous préférez garder la comparaison par ID, il faut :
1. Ajouter `activityId` lors de la création du stock (déjà fait dans le code)
2. Modifier les règles pour permettre l'ajout d'`activityId` si manquant lors de la mise à jour
3. Créer un script de migration pour les stocks existants

```javascript
// Vérifie que la mise à jour DIMINUE la quantité OU ajoute activityId si manquant
function isStockDecreaseOnly() {
  let allowedKeys = ["quantity", "updatedAt"];
  // Permettre l'ajout d'activityId si manquant
  if (!("activityId" in resource.data) && "activityId" in request.resource.data) {
    allowedKeys = allowedKeys.concat(["activityId"]);
  }
  return request.resource.data.keys().hasOnly(allowedKeys)
         && request.resource.data.quantity < resource.data.quantity;
}
```

## Recommandation

Je recommande **l'Option 1** car elle est plus simple et fonctionne immédiatement avec la structure actuelle des données.

## ✅ Solution implémentée

Les règles Firestore ont été corrigées pour utiliser la comparaison par nom d'activité. 

**Fichier créé** : `firestore_rules_stock_fixed.txt`

### Changement principal

La fonction `isSameActivity()` a été modifiée pour comparer :
- `user.activityName` (nom de l'activité du caissier)
- `currentStock.activity` (nom de l'activité du stock)

Au lieu de comparer les IDs qui n'existent pas dans le stock.

### Instructions

1. Copiez le contenu de `firestore_rules_stock_fixed.txt`
2. Remplacez la fonction `isSameActivity()` dans vos règles Firestore
3. Déployez les nouvelles règles dans Firebase Console

Après ce changement, les caissiers pourront créer des tickets et déduire le stock de leur activité.

