# 🔐 Instructions pour Mettre à Jour les Règles Firestore - Collection Deposits

## ⚠️ Erreur Actuelle

Vous avez l'erreur suivante :
```
PERMISSION_DENIED: Missing or insufficient permissions
```

Cela signifie que vos règles Firestore pour la collection `deposits` vérifient encore l'ancien champ `amount`, alors que le code envoie maintenant `amountUSD` et `amountFC`.

---

## 📋 Solution : Mettre à Jour les Règles

### Étape 1 : Ouvrir Firebase Console

1. Allez sur [Firebase Console](https://console.firebase.google.com/)
2. Sélectionnez votre projet **Maghali**
3. Dans le menu de gauche, cliquez sur **Firestore Database**
4. Cliquez sur l'onglet **Règles** (Rules)

### Étape 2 : Remplacer les Règles de Deposits

**Trouvez** la section `match /deposits/{depositId}` dans vos règles et **remplacez-la** par :

```javascript
match /deposits/{depositId} {
  // ➤ Créer un dépôt
  // Support de l'ancien format (amount) et du nouveau (amountUSD/amountFC)
  allow create: if isAuth()
                && request.resource.data.activityName is string
                && request.resource.data.cashierId == request.auth.uid
                && request.resource.data.type == "deposit"
                // Au moins un montant doit être présent (USD ou FC, ou l'ancien format amount)
                && (
                  (request.resource.data.amountUSD is number && request.resource.data.amountUSD >= 0)
                  || (request.resource.data.amountFC is number && request.resource.data.amountFC >= 0)
                  || (request.resource.data.amount is number && request.resource.data.amount >= 0)
                )
                // Si amountUSD est présent, il doit être >= 0
                && (!("amountUSD" in request.resource.data) || request.resource.data.amountUSD >= 0)
                // Si amountFC est présent, il doit être >= 0
                && (!("amountFC" in request.resource.data) || request.resource.data.amountFC >= 0)
                // Si amount (ancien format) est présent, il doit être >= 0
                && (!("amount" in request.resource.data) || request.resource.data.amount >= 0);

  // ➤ Lire les dépôts
  allow read: if isAuth();

  // ❌ Interdire modification et suppression
  allow update, delete: if false;
}
```

### Étape 3 : Publier les Règles

1. Cliquez sur le bouton **Publier** (Publish) en haut à droite
2. Attendez la confirmation "Rules published successfully"

---

## ✅ Vérification

Après avoir publié les règles :

1. **Redémarrez votre application Flutter** (hot restart ne suffit pas)
2. Essayez de créer un nouveau dépôt
3. L'erreur `PERMISSION_DENIED` devrait disparaître

---

## 🔍 Détails des Règles

### Logique de Validation

Les nouvelles règles acceptent **trois formats** pour la compatibilité :

1. **Nouveau format** : `amountUSD` et/ou `amountFC`
2. **Ancien format** : `amount` (en FC)
3. **Mixte** : Les anciens dépôts continuent de fonctionner

### Validations Appliquées

- ✅ Utilisateur authentifié
- ✅ `activityName` est une chaîne
- ✅ `cashierId` correspond à l'utilisateur connecté
- ✅ `type` est "deposit"
- ✅ Au moins un montant est présent (USD, FC, ou amount)
- ✅ Tous les montants présents sont >= 0

### Protection

- ❌ Modification interdite (les dépôts sont immuables)
- ❌ Suppression interdite (traçabilité)

---

## 📝 Note sur la Compatibilité

Les règles sont **rétrocompatibles** :
- Les anciens dépôts avec seulement `amount` continuent de fonctionner
- Les nouveaux dépôts avec `amountUSD` et `amountFC` sont acceptés
- Les deux formats peuvent coexister dans la même collection

---

## 🐛 Dépannage

### Erreur persiste après avoir mis à jour les règles

1. Vérifiez que vous avez bien **publié** les règles (bouton "Publish")
2. Vérifiez que l'utilisateur est bien **authentifié**
3. Vérifiez que le `cashierId` correspond bien à l'utilisateur connecté
4. Redémarrez complètement l'application

### Comment vérifier les données envoyées

Dans votre code Flutter, vous pouvez ajouter un `print` avant la création :

```dart
print('Creating deposit: ${{
  'activityName': widget.activityName,
  'amountUSD': amountUSD,
  'amountFC': amountFC,
  'cashierId': widget.cashierId,
  'type': 'deposit',
}}');
```

Cela vous permettra de voir exactement ce qui est envoyé à Firestore.

