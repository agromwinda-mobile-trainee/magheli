# Correction de la syntaxe Firestore Rules

## ❌ Problème : Syntaxe JavaScript non supportée

Firestore Rules **ne supporte pas** les blocs `if` avec accolades comme en JavaScript standard.

### Code incorrect (ne fonctionne pas)

```javascript
function isSameActivity() {
  let user = get(...).data;
  let currentStock = resource.data;
  
  // ❌ ERREUR : Syntaxe non supportée
  if (!("activityName" in user) || user.activityName == null) {
    return false;
  }
  
  if (!("activity" in currentStock) || currentStock.activity == null) {
    return false;
  }
  
  return user.activityName == currentStock.activity;
}
```

**Erreurs générées :**
- `Unexpected 'if'`
- `Unexpected 'return'`

---

## ✅ Solution : Utiliser des opérateurs logiques

Firestore Rules utilise des **expressions conditionnelles** avec des opérateurs logiques (`&&`, `||`).

### Code correct

```javascript
function isSameActivity() {
  let user = get(/databases/$(database)/documents/users/$(request.auth.uid)).data;
  let currentStock = resource.data;
  
  // ✅ CORRECT : Utilisation d'opérateurs logiques
  return ("activityName" in user) 
         && user.activityName != null
         && ("activity" in currentStock)
         && currentStock.activity != null
         && user.activityName == currentStock.activity;
}
```

**Logique équivalente :**
- Si `activityName` n'existe pas dans `user` → retourne `false` (via `&&`)
- Si `activityName` est `null` → retourne `false` (via `&&`)
- Si `activity` n'existe pas dans `currentStock` → retourne `false` (via `&&`)
- Si `activity` est `null` → retourne `false` (via `&&`)
- Sinon, compare les valeurs

---

## 📋 Règles de syntaxe Firestore

### ✅ Autorisé

```javascript
// Opérateurs logiques
return condition1 && condition2;
return condition1 || condition2;
return !condition;

// Opérateurs de comparaison
return value1 == value2;
return value1 != value2;
return value1 < value2;
return value1 >= value2;

// Vérification d'existence
return "field" in data;
return data.field != null;
```

### ❌ Non autorisé

```javascript
// Blocs if/else
if (condition) {
  return true;
} else {
  return false;
}

// Boucles
for (item in list) { ... }
while (condition) { ... }

// Try/catch
try { ... } catch { ... }
```

---

## 🎯 Fichier corrigé

Le fichier `REGLES_FIRESTORE_STOCK_CORRIGEES.txt` contient maintenant :
- ✅ Toutes les fonctions helper (isAuth, isAdmin, isManager, isCashier)
- ✅ Fonction `isSameActivity()` avec syntaxe correcte (opérateurs logiques)
- ✅ Fonctions `isStockDecreaseOnly()` et `notGoingNegative()` (déjà correctes)
- ✅ Règles `match` avec syntaxe corrigée

**Prêt à être copié dans Firebase Console !**



