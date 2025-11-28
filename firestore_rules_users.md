# Règles Firestore pour la collection users - Version modifiée

```javascript
// --- users collection ---
match /users/{userId} {
  
  // Fonction helper pour vérifier si l'utilisateur est manager ou admin
  function isManagerOrAdmin() {
    return isAuth() && (
      isAdmin() || 
      isManager() ||
      // Permettre la création si le document n'existe pas encore (nouvel utilisateur)
      // ET que l'email correspond à l'utilisateur connecté
      (!exists(/databases/$(database)/documents/users/$(request.auth.uid)) &&
       request.resource.data.email == request.auth.token.email)
    );
  }

  allow create: if isManagerOrAdmin() 
    // Validation des champs requis
    && request.resource.data.email is string
    && request.resource.data.fullName is string
    && request.resource.data.role is string
    && request.resource.data.role in ['cashier', 'mainCashier', 'stockManager', 'manager']
    && request.resource.data.profileCompleted is bool
    // Si c'est un caissier, activityId et activityName doivent être présents
    && (request.resource.data.role != 'cashier' || 
        (request.resource.data.activityId is string && 
         request.resource.data.activityName is string))
    // L'email doit correspondre à l'utilisateur connecté si c'est une auto-création
    && (isAdmin() || isManager() || request.resource.data.email == request.auth.token.email);

  allow read: if isAuth() && (
    request.auth.uid == userId || 
    isAdmin() || 
    isManager()
  );

  allow update: if isAuth() && (
    request.auth.uid == userId || 
    isAdmin() || 
    isManager()
  );

  allow delete: if isAdmin();
}
```

## Explication

La règle modifiée permet la création dans deux cas :

1. **Cas normal** : Un admin ou manager (connecté) crée un utilisateur
   - Vérifie que l'utilisateur connecté a le rôle admin ou manager dans son document users

2. **Cas auto-création** : Un nouvel utilisateur crée son propre document
   - Vérifie que le document users de l'utilisateur connecté n'existe pas encore
   - Vérifie que l'email dans les données correspond à l'email de l'utilisateur connecté
   - Cela permet au nouvel utilisateur créé par `createUserWithEmailAndPassword` de créer son propre document

## Note importante

Cette approche fonctionne car :
- `createUserWithEmailAndPassword` connecte automatiquement le nouvel utilisateur
- Le nouvel utilisateur n'a pas encore de document users (donc `!exists(...)` retourne true)
- L'email dans les données correspond à l'email de l'utilisateur connecté
- Les validations garantissent que seuls les rôles autorisés peuvent être créés




