# 🔐 Instructions pour Ajouter les Règles Firestore - Caisse Principale

## ⚠️ Erreur Actuelle

Vous avez l'erreur suivante :
```
PERMISSION_DENIED: Missing or insufficient permissions
```

Cela signifie que la collection `activity_balances` n'a pas de règles de sécurité définies dans Firestore.

---

## 📋 Solution : Ajouter les Règles

### Étape 1 : Ouvrir Firebase Console

1. Allez sur [Firebase Console](https://console.firebase.google.com/)
2. Sélectionnez votre projet **Maghali**
3. Dans le menu de gauche, cliquez sur **Firestore Database**
4. Cliquez sur l'onglet **Règles** (Rules)

### Étape 2 : Ajouter les Règles

**Option A : Si vous avez déjà des règles existantes**

Ajoutez les règles suivantes **à la fin** de votre fichier de règles (avant le dernier `}`) :

```javascript
// ============================
//      RÈGLES POUR LA CAISSE PRINCIPALE
// ============================

// Fonction helper pour vérifier le rôle mainCashier
function isMainCashier() {
  return isAuth() && get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'mainCashier';
}

// Collection: activity_balances
match /activity_balances/{activityName} {
  allow read: if isAuth();
  allow create: if isMainCashier();
  allow update: if isMainCashier()
                && request.resource.data.balanceUSD >= 0
                && request.resource.data.balanceFC >= 0
                && request.resource.data.activityName == resource.data.activityName;
  allow delete: if false;
}

// Collection: main_cash_movements
match /main_cash_movements/{movementId} {
  allow read: if isAuth();
  allow create: if isMainCashier()
                && (request.resource.data.amountUSD > 0 || request.resource.data.amountFC > 0)
                && request.resource.data.amountUSD >= 0
                && request.resource.data.amountFC >= 0
                && request.resource.data.activityName != null
                && request.resource.data.type in ['deposit', 'withdrawal']
                && request.resource.data.reason != null;
  allow update: if false;
  allow delete: if false;
}

// Document: main_cash/balance
match /main_cash/balance {
  allow read: if isAuth();
  allow create: if isMainCashier();
  allow update: if isMainCashier()
                && request.resource.data.balanceUSD >= 0
                && request.resource.data.balanceFC >= 0;
  allow delete: if false;
}
```

**Option B : Si vous partez de zéro**

Copiez le contenu complet du fichier `REGLES_FIRESTORE_CAISSE_PRINCIPALE.txt` et collez-le dans Firebase Console.

### Étape 3 : Publier les Règles

1. Cliquez sur le bouton **Publier** (Publish) en haut à droite
2. Attendez la confirmation "Rules published successfully"

---

## ✅ Vérification

Après avoir publié les règles :

1. **Redémarrez votre application Flutter** (hot restart ne suffit pas)
2. Essayez d'accéder à la page de caisse principale
3. L'erreur `PERMISSION_DENIED` devrait disparaître

---

## 🔍 Détails des Règles

### `activity_balances`
- **Lecture** : Tous les utilisateurs authentifiés
- **Création/Mise à jour** : Seul le `mainCashier`
- **Protection** : Les soldes ne peuvent pas être négatifs

### `main_cash_movements`
- **Lecture** : Tous les utilisateurs authentifiés
- **Création** : Seul le `mainCashier`
- **Protection** : 
  - Au moins un montant (USD ou FC) doit être > 0
  - Les montants ne peuvent pas être négatifs
  - L'activité doit être spécifiée
  - Le type doit être 'deposit' ou 'withdrawal'
- **Mise à jour/Suppression** : Interdites (immuable)

### `main_cash/balance`
- **Lecture** : Tous les utilisateurs authentifiés
- **Création/Mise à jour** : Seul le `mainCashier`
- **Protection** : Les soldes ne peuvent pas être négatifs

---

## ⚠️ Important : Rôle mainCashier

Assurez-vous que l'utilisateur qui doit gérer la caisse principale a le rôle `mainCashier` dans Firestore :

**Collection** : `users`
**Document** : `{userId}`
**Champ** : `role: "mainCashier"`

Si l'utilisateur n'a pas ce rôle, les règles bloqueront l'accès.

---

## 🐛 Dépannage

### Erreur persiste après avoir ajouté les règles

1. Vérifiez que vous avez bien **publié** les règles (bouton "Publish")
2. Vérifiez que l'utilisateur connecté a le rôle `mainCashier`
3. Vérifiez la console Firebase pour voir les erreurs détaillées
4. Redémarrez complètement l'application

### Comment vérifier le rôle de l'utilisateur

Dans Firebase Console :
1. Allez dans **Firestore Database** → **Data**
2. Ouvrez la collection `users`
3. Trouvez le document de l'utilisateur
4. Vérifiez que le champ `role` contient `"mainCashier"`

---

## 📝 Note

Ces règles sont **sécurisées** et suivent le principe du **moindre privilège** :
- Seul le caissier principal peut modifier les données
- Tous les autres utilisateurs peuvent seulement lire
- Les validations empêchent les données invalides (montants négatifs, etc.)


