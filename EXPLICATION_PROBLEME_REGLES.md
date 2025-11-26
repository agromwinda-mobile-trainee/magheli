# 🔴 Problème identifié dans les règles Firestore

## ❌ Erreur de syntaxe dans la règle `allow update`

### Code actuel (INCORRECT)

```javascript
allow update: if isManager() || isCashier()
              && isSameActivity()
              && isStockDecreaseOnly()
              && notGoingNegative();
```

### 🔍 Pourquoi c'est incorrect ?

En JavaScript/Firestore Rules, l'opérateur `&&` a une **priorité plus élevée** que `||`. 

Donc votre règle est évaluée comme ceci :

```javascript
isManager() || (isCashier() && isSameActivity() && isStockDecreaseOnly() && notGoingNegative())
```

**Conséquence :**
- ✅ Un **manager** peut modifier n'importe quel stock **SANS vérifier** `isSameActivity()`, `isStockDecreaseOnly()`, ou `notGoingNegative()`
- ✅ Un **caissier** doit respecter toutes les conditions

**Problème :** Cela permet à un manager de :
- Augmenter la quantité (violation de `isStockDecreaseOnly()`)
- Mettre une quantité négative (violation de `notGoingNegative()`)
- Modifier le stock d'une autre activité (violation de `isSameActivity()`)

---

## ✅ Solution 1 : Ajouter des parenthèses (Recommandé)

```javascript
allow update: if (isManager() || isCashier())
              && isStockDecreaseOnly()
              && notGoingNegative()
              && (isManager() || isSameActivity());
```

**Logique :**
- ✅ Manager OU Caissier peut modifier
- ✅ La quantité doit diminuer (pour tous)
- ✅ La quantité ne peut pas être négative (pour tous)
- ✅ Si c'est un manager → pas de vérification d'activité
- ✅ Si c'est un caissier → doit être de la même activité

---

## ✅ Solution 2 : Si vous voulez que même les managers respectent l'activité

```javascript
allow update: if (isManager() || isCashier())
              && isSameActivity()
              && isStockDecreaseOnly()
              && notGoingNegative();
```

**Logique :**
- ✅ Manager OU Caissier peut modifier
- ✅ Tous doivent respecter la même activité
- ✅ La quantité doit diminuer
- ✅ La quantité ne peut pas être négative

---

## ✅ Solution 3 : Séparer les règles (Plus claire)

```javascript
allow update: if isManager() && isStockDecreaseOnly() && notGoingNegative();
allow update: if isCashier() 
              && isSameActivity()
              && isStockDecreaseOnly()
              && notGoingNegative();
```

**Logique :**
- ✅ Manager : peut modifier n'importe quel stock, mais doit respecter diminution et non-négatif
- ✅ Caissier : peut modifier seulement son activité, avec diminution et non-négatif

---

## 🎯 Recommandation

**Utilisez la Solution 1** car elle :
- ✅ Permet aux managers de gérer tous les stocks (logique métier)
- ✅ Force les caissiers à respecter leur activité (sécurité)
- ✅ Garantit que personne ne peut augmenter le stock ou le rendre négatif
- ✅ Est plus concise que la Solution 3

---

## 📋 Vérification du code Flutter

Le code Flutter est **✅ compatible** avec toutes ces solutions car :

1. ✅ Il modifie seulement `quantity` et `updatedAt`
2. ✅ Il vérifie que `newQty < currentQty` avant la mise à jour
3. ✅ Il vérifie que `newQty >= 0` avant la mise à jour
4. ✅ Il utilise `widget.activityName` qui correspond à `user.activityName`

**Le problème vient uniquement des règles Firestore, pas du code Flutter.**



