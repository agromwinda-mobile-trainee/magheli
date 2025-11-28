# 💰 Structure de la Caisse Principale - Double Devise (USD + FC)

## 📋 Vue d'ensemble

Le système de caisse principale permet au **caissier principal** de :
- Gérer les **entrées et sorties** par activité avec **double devise** (USD + FC)
- Consulter les **soldes par activité** et le **solde principal** (somme de tous les soldes)
- Consulter l'**historique** avec filtres (jour, semaine, mois)

---

## 🗄️ Structure Firestore

### 1. Collection `activity_balances`
Stocke le solde de chaque activité en double devise.

**Document ID** : `activityName` (nom de l'activité)

**Champs** :
```javascript
{
  activityName: string,      // Nom de l'activité
  balanceUSD: number,        // Solde en USD
  balanceFC: number,         // Solde en FC (Franc Congolais)
  updatedAt: timestamp        // Dernière mise à jour
}
```

### 2. Collection `main_cash_movements`
Enregistre tous les mouvements (entrées et sorties) de la caisse principale.

**Champs** :
```javascript
{
  activityName: string,       // Activité concernée
  amountUSD: number,          // Montant en USD (peut être 0)
  amountFC: number,           // Montant en FC (peut être 0)
  type: string,               // 'deposit' ou 'withdrawal'
  reason: string,             // Raison/description
  cashierId: string,          // ID du caissier principal
  cashierName: string,        // Nom du caissier principal
  date: timestamp             // Date/heure du mouvement
}
```

### 3. Document `main_cash/balance`
Stocke le solde principal (somme de tous les soldes d'activités).

**Champs** :
```javascript
{
  balanceUSD: number,         // Solde total en USD
  balanceFC: number,          // Solde total en FC
  updatedAt: timestamp        // Dernière mise à jour
}
```

**Note** : Le solde principal est **automatiquement recalculé** à chaque mouvement en sommant tous les soldes de `activity_balances`.

---

## 📱 Pages Créées/Modifiées

### 1. `MainCashierEntryPage.dart` (NOUVEAU)
Page pour enregistrer une **entrée** ou **sortie** de caisse.

**Fonctionnalités** :
- Sélection de l'activité (obligatoire)
- Saisie du montant USD (optionnel, peut être 0)
- Saisie du montant FC (optionnel, peut être 0)
- Au moins un montant (USD ou FC) doit être saisi
- Raison/description (obligatoire)
- Mise à jour automatique du solde de l'activité
- Recalcul automatique du solde principal

### 2. `MainCashierHistoryPage.dart` (NOUVEAU)
Page d'historique avec filtres temporels.

**Fonctionnalités** :
- Filtre par période : **Tout**, **Jour**, **Semaine**, **Mois**
- Sélection de date pour le filtre "Jour"
- Affichage des mouvements avec double devise
- Résumé des totaux (entrées/sorties) en USD et FC
- Tri par date décroissante

### 3. `MainCashierDashboard.dart` (MODIFIÉ)
Dashboard principal du caissier.

**Modifications** :
- Affichage du solde principal en **double devise** (USD + FC)
- Bouton "Enregistrer Entrée" → `MainCashierEntryPage(isDeposit: true)`
- Bouton "Enregistrer Sortie" → `MainCashierEntryPage(isDeposit: false)`
- Bouton "Historique" → `MainCashierHistoryPage()`

### 4. `MainCashierBalancePage.dart` (MODIFIÉ)
Page de détails des soldes.

**Modifications** :
- Affichage du **solde principal** en double devise
- Liste des **soldes par activité** avec double devise
- Affichage de la date de mise à jour pour chaque solde
- Bouton pour accéder à l'historique

---

## 🔄 Logique de Calcul

### Mise à jour du solde d'activité
Lors d'un mouvement (entrée ou sortie) :

1. **Lecture** du solde actuel de l'activité depuis `activity_balances`
2. **Calcul** du nouveau solde :
   - **Entrée** : `nouveauSolde = ancienSolde + montant`
   - **Sortie** : `nouveauSolde = ancienSolde - montant`
3. **Vérification** : les soldes ne peuvent pas être négatifs
4. **Mise à jour** du document dans `activity_balances`

### Recalcul du solde principal
Après chaque mise à jour d'un solde d'activité :

1. **Lecture** de tous les documents de `activity_balances`
2. **Somme** de tous les `balanceUSD` → `totalUSD`
3. **Somme** de tous les `balanceFC` → `totalFC`
4. **Mise à jour** du document `main_cash/balance` avec ces totaux

**Formule** :
```
soldePrincipalUSD = Σ(balanceUSD de toutes les activités)
soldePrincipalFC = Σ(balanceFC de toutes les activités)
```

---

## ✅ Validations

### Lors de l'enregistrement d'un mouvement :
- ✅ Activité sélectionnée (obligatoire)
- ✅ Au moins un montant saisi (USD ou FC, ou les deux)
- ✅ Montants >= 0 (pas de valeurs négatives)
- ✅ Raison/description saisie (obligatoire)
- ✅ Vérification que les soldes ne deviennent pas négatifs après la transaction

### Protection contre les soldes négatifs :
Si une sortie ferait passer le solde sous 0, la transaction est **rejetée** avec un message d'erreur.

---

## 📊 Exemple d'utilisation

### Scénario : Enregistrer une entrée
1. Caissier principal ouvre "Enregistrer Entrée"
2. Sélectionne l'activité "Restaurant"
3. Saisit : USD = 100, FC = 50000
4. Saisit la raison : "Dépôt de la journée"
5. Clique sur "Enregistrer"

**Résultat** :
- Document créé dans `main_cash_movements`
- Solde de "Restaurant" mis à jour : `balanceUSD += 100`, `balanceFC += 50000`
- Solde principal recalculé et mis à jour

### Scénario : Consulter l'historique
1. Caissier principal ouvre "Historique"
2. Sélectionne le filtre "Semaine"
3. Voit tous les mouvements de la semaine en cours
4. Voit les totaux d'entrées et sorties en USD et FC

---

## 🔐 Règles Firestore (à ajouter)

Les règles Firestore doivent permettre :
- **Lecture** : Tous les utilisateurs authentifiés peuvent lire
- **Écriture** : Seul le caissier principal (rôle spécifique) peut créer/modifier

**Note** : Les règles exactes dépendent de votre structure de rôles. À adapter selon vos besoins.

---

## 🚀 Prochaines étapes possibles

- [ ] Ajouter un taux de change USD/FC pour conversion automatique
- [ ] Ajouter des rapports PDF pour l'historique
- [ ] Ajouter des notifications pour les soldes faibles
- [ ] Ajouter la possibilité de modifier/supprimer des mouvements (avec traçabilité)

---

## 📝 Notes importantes

1. **Initialisation** : Les soldes d'activités sont créés automatiquement lors du premier mouvement
2. **Synchronisation** : Le solde principal est toujours la somme des soldes d'activités (pas de désynchronisation possible)
3. **Traçabilité** : Tous les mouvements sont enregistrés avec le caissier, la date et la raison
4. **Flexibilité** : Un mouvement peut avoir uniquement USD, uniquement FC, ou les deux


