/// Utilitaire pour gérer les messages d'erreur de manière cohérente
/// Tous les messages sont en français et clairs pour les utilisateurs

class ErrorMessages {
  // Messages d'erreur généraux
  static const String erreurGenerale = 'Une erreur est survenue. Veuillez réessayer.';
  static const String erreurReseau = 'Problème de connexion. Vérifiez votre connexion internet.';
  static const String erreurPermission = 'Vous n\'avez pas les permissions nécessaires pour effectuer cette action.';
  static const String champObligatoire = 'Ce champ est obligatoire.';
  static const String donneesInvalides = 'Les données saisies sont invalides.';

  // Messages d'authentification
  static const String deconnexionEchouee = 'Impossible de vous déconnecter. Veuillez réessayer.';
  static const String connexionRequise = 'Vous devez être connecté pour effectuer cette action.';
  static const String compteIntrouvable = 'Compte introuvable. Veuillez contacter un administrateur.';
  static const String roleNonReconnu = 'Rôle non reconnu. Veuillez contacter un administrateur.';
  static const String connexionEchec = 'Échec de la connexion. Vérifiez vos identifiants et réessayez.';
  static const String emailOuMotDePasseIncorrect = 'Email ou mot de passe incorrect.';

  // Messages de création d'utilisateur
  static String emailDejaUtilise = 'Cet email est déjà utilisé par un autre compte.';
  static String motDePasseFaible = 'Le mot de passe doit contenir au moins 6 caractères.';
  static String emailInvalide = 'L\'adresse email saisie est invalide.';
  static String utilisateurCree = 'Utilisateur créé avec succès. Veuillez vous reconnecter.';
  static String utilisateurNonCree = 'Impossible de créer l\'utilisateur. Vérifiez les informations saisies.';

  // Messages de stock
  static String stockInsuffisant(String produit) => 
      'Stock insuffisant pour "$produit". Vérifiez la quantité disponible.';
  static const String stockNonTrouve = 'Produit introuvable dans le stock.';
  static const String quantiteInvalide = 'La quantité doit être supérieure à 0.';
  static const String quantiteNegative = 'La quantité ne peut pas être négative.';
  static String quantiteNePeutPasAugmenter = 'La quantité ne peut pas augmenter lors d\'une déduction de stock.';
  static String stockChargeEchec = 'Impossible de charger les produits. Vérifiez votre connexion.';
  static String stockSauvegardeEchec = 'Impossible de sauvegarder le stock. Réessayez plus tard.';

  // Messages de tickets
  static const String ticketNonTrouve = 'Ticket introuvable.';
  static const String ticketCreeSucces = 'Ticket créé avec succès.';
  static const String ticketModifieSucces = 'Ticket modifié avec succès.';
  static String ticketSauvegardeEchec = 'Impossible de sauvegarder le ticket. Vérifiez votre connexion.';
  static const String serveurNonSelectionne = 'Veuillez sélectionner un serveur avant de créer le ticket.';
  static const String aucunProduitSelectionne = 'Veuillez ajouter au moins un produit au ticket.';

  // Messages de factures
  static const String factureNonTrouvee = 'Facture introuvable.';
  static const String factureModifieeSucces = 'Facture mise à jour avec succès.';
  static const String factureChargeEchec = 'Impossible de charger la facture. Vérifiez votre connexion.';
  static const String montantInvalide = 'Le montant saisi est invalide.';
  static const String montantSuperieurTotal = 'Le montant payé ne peut pas être supérieur au total.';
  static const String montantNegatif = 'Le montant ne peut pas être négatif.';

  // Messages de paiement
  static const String activiteNonTrouvee = 'Activité introuvable. Contactez un administrateur.';
  static const String serveurNonDefini = 'Serveur non défini. Contactez un administrateur.';
  static const String calculSoldeIncoherent = 'Erreur de calcul. Contactez le support technique.';
  static const String paiementEchec = 'Le paiement a échoué. Vérifiez les informations et réessayez.';

  // Messages de dépôts
  static const String depotEnregistreSucces = 'Dépôt enregistré avec succès.';
  static String depotEchec = 'Impossible d\'enregistrer le dépôt. Vérifiez le montant et réessayez.';
  static const String montantDepotInvalide = 'Le montant du dépôt doit être supérieur à 0.';

  // Messages d'impression
  static const String imprimanteNonSelectionnee = 'Veuillez sélectionner une imprimante.';
  static const String rechercheImprimanteEchec = 'Impossible de rechercher les imprimantes. Vérifiez que le Bluetooth est activé.';
  static const String connexionImprimanteEchec = 'Impossible de se connecter à l\'imprimante. Vérifiez qu\'elle est allumée et à proximité.';
  static const String impressionEchec = 'L\'impression a échoué. Vérifiez la connexion à l\'imprimante.';
  static const String impressionSucces = 'Facture imprimée avec succès.';
  static const String factureDonneesChargeEchec = 'Impossible de charger les données de la facture.';

  // Messages de produits
  static const String produitCreeSucces = 'Produit créé avec succès.';
  static const String produitModifieSucces = 'Produit mis à jour avec succès.';
  static String produitChargeEchec = 'Impossible de charger les produits. Vérifiez votre connexion.';
  static const String produitNonTrouve = 'Produit introuvable.';
  static const String prixInvalide = 'Le prix doit être supérieur à 0.';
  static const String nomProduitObligatoire = 'Le nom du produit est obligatoire.';

  // Messages d'activités
  static const String activiteCreeeSucces = 'Activité créée avec succès.';
  static const String activiteModifieeSucces = 'Activité modifiée avec succès.';
  static String activiteChargeEchec = 'Impossible de charger les activités. Vérifiez votre connexion.';
  static const String activiteNonSelectionnee = 'Veuillez sélectionner une activité.';
  static const String nomActiviteObligatoire = 'Le nom de l\'activité est obligatoire.';

  // Messages de clients
  static const String clientAjouteSucces = 'Client ajouté avec succès.';
  static String clientAjoutEchec = 'Impossible d\'ajouter le client. Vérifiez les informations saisies.';
  static const String nomClientObligatoire = 'Le nom du client est obligatoire.';

  // Messages d'utilisateurs (Admin)
  static const String utilisateurSupprimeSucces = 'Utilisateur supprimé avec succès.';
  static String utilisateurSupprimeEchec = 'Impossible de supprimer l\'utilisateur. Réessayez plus tard.';
  static const String adminNonSupprimable = 'Impossible de supprimer un compte administrateur.';
  static const String roleModifieSucces = 'Rôle modifié avec succès.';
  static String roleModifieEchec = 'Impossible de modifier le rôle. Réessayez plus tard.';

  // Messages de mouvements de caisse
  static const String mouvementEnregistreSucces = 'Mouvement enregistré avec succès.';
  static String mouvementEchec = 'Impossible d\'enregistrer le mouvement. Vérifiez les informations.';
  static const String raisonObligatoire = 'Veuillez saisir une raison pour ce mouvement.';

  // Fonction utilitaire pour obtenir un message d'erreur à partir d'une exception
  static String fromException(dynamic error) {
    final errorString = error.toString().toLowerCase();
    
    // Détecter les erreurs courantes
    if (errorString.contains('permission') || errorString.contains('permission-denied')) {
      return erreurPermission;
    }
    if (errorString.contains('network') || errorString.contains('connection') || errorString.contains('unavailable')) {
      return erreurReseau;
    }
    if (errorString.contains('not-found') || errorString.contains('introuvable')) {
      return 'Élément introuvable.';
    }
    if (errorString.contains('stock insuffisant')) {
      return errorString; // Garder le message original pour le stock
    }
    
    // Message par défaut avec plus de contexte
    return 'Une erreur est survenue. Si le problème persiste, contactez le support technique.';
  }
}

