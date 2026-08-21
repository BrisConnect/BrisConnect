// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'BrisConnect+';

  @override
  String get welcome => 'Bienvenue';

  @override
  String get signIn => 'Se connecter';

  @override
  String get signUp => 'S\'inscrire';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Mot de passe';

  @override
  String get phone => 'Téléphone';

  @override
  String get name => 'Nom';

  @override
  String get save => 'Enregistrer';

  @override
  String get cancel => 'Annuler';

  @override
  String get editProfile => 'Modifier le profil';

  @override
  String get profileInfo => 'Informations du profil';

  @override
  String get preferences => 'Préférences';

  @override
  String get language => 'Langue';

  @override
  String get locationRadius => 'Rayon de localisation';

  @override
  String get appearanceSettings => 'Apparence';

  @override
  String get feedback => 'Commentaires';

  @override
  String get myFeedback => 'Mes commentaires';

  @override
  String get helpAndSupport => 'Aide et support';

  @override
  String get discover => 'Découvrir';

  @override
  String get community => 'Communauté';

  @override
  String get map => 'Carte';

  @override
  String get saved => 'Enregistré';

  @override
  String get profile => 'Profil';

  @override
  String get food => 'Nourriture';

  @override
  String get events => 'Événements';

  @override
  String get businesses => 'Entreprises';

  @override
  String get promotions => 'Promotions';

  @override
  String get photos => 'Photos';

  @override
  String get newPost => 'Nouveau';

  @override
  String get search => 'Rechercher';

  @override
  String get filter => 'Filtrer';

  @override
  String get clearFilters => 'Effacer les filtres';

  @override
  String get noResults => 'Aucun résultat trouvé';

  @override
  String get loading => 'Chargement...';

  @override
  String get error => 'Erreur';

  @override
  String get success => 'Succès';

  @override
  String get profileUpdated => 'Profil mis à jour avec succès.';

  @override
  String get profileUpdateFailed =>
      'Impossible de mettre à jour le profil. Veuillez réessayer.';

  @override
  String get guestVisitor => 'Visiteur invité';

  @override
  String get localUser => 'Locale';

  @override
  String get filterEventsTitle => 'Filtrer les événements';

  @override
  String get priceLabel => 'Prix';

  @override
  String get dateLabel => 'Date';

  @override
  String get pickADate => 'Choisissez une date';

  @override
  String get resetButton => 'Réinitialiser';

  @override
  String get applyButton => 'Postuler';

  @override
  String get freeLabel => 'Gratuit';

  @override
  String get paidLabel => 'Payé';

  @override
  String eventSavedToInterested(String eventTitle) {
    return '$eventTitle enregistré dans Intéressé.';
  }

  @override
  String eventRemovedFromInterested(String eventTitle) {
    return '$eventTitle supprimé de Intéressé.';
  }

  @override
  String savedToAttractions(String title) {
    return '$title enregistré dans les attractions enregistrées.';
  }

  @override
  String removedFromAttractions(String title) {
    return '$title supprimé des attractions enregistrées.';
  }

  @override
  String get pleaseSignInToSaveEvents =>
      'Veuillez vous connecter en tant que visiteur pour enregistrer les événements.';

  @override
  String get pleaseSignInToReview =>
      'Veuillez vous connecter pour rédiger un avis ou BuzzVote.';

  @override
  String reviewSubmitted(String rating, String buzzRating) {
    return 'Avis soumis\\! ⭐ $rating / Buzz ⚡ $buzzRating';
  }

  @override
  String reviewSubmitFailed(String error) {
    return 'Impossible d\'envoyer l\'avis : $error';
  }

  @override
  String get noExternalLink =>
      'Aucun lien externe disponible pour cet article pour le moment.';

  @override
  String get unableToOpenLink =>
      'Impossible d\'ouvrir le lien de l\'événement pour le moment.';

  @override
  String shareTitle(String title) {
    return 'Partager : $title';
  }

  @override
  String get reportEvent => 'Signaler un événement';

  @override
  String get reviewsOnlyForFood =>
      'Les avis ne sont disponibles que pour les produits alimentaires';

  @override
  String get chooseFromGallery => 'Choisissez dans la galerie';

  @override
  String get takeAPhoto => 'Prendre une photo';

  @override
  String get pleaseLoginVisitor =>
      'Veuillez d\'abord vous connecter en tant que visiteur.';

  @override
  String get onlyJpgPng =>
      'Seules les images JPG et PNG sont prises en charge.';

  @override
  String get imageTooLarge =>
      'L\'image est trop grande. Veuillez choisir une image plus petite.';

  @override
  String get profilePictureUpdated =>
      'Photo de profil mise à jour avec succès.';

  @override
  String get profilePictureUpdateFailed =>
      'Impossible de mettre à jour la photo de profil. Veuillez réessayer.';

  @override
  String get enterYourName => 'Entrez votre nom';

  @override
  String get phoneHint => 'par ex. 04xxxxxxxxx';

  @override
  String get nameCannotBeEmpty => 'Le nom ne peut pas être vide.';

  @override
  String get nameMinLength => 'Le nom doit comporter au moins 2 caractères.';

  @override
  String get enterValidPhone => 'Entrez un numéro de téléphone valide.';

  @override
  String get changeProfilePicture => 'Changer la photo de profil';

  @override
  String get uploadProfilePicture => 'Télécharger une photo de profil';

  @override
  String get areYouSureSignOut => 'Êtes-vous sûr de vouloir vous déconnecter ?';

  @override
  String get returnWelcome => 'Retour à l\'écran d\'accueil';

  @override
  String get setHowFarRecommendations =>
      'Définir jusqu\'où les recommandations peuvent aller';

  @override
  String get themeTextSizeFeedback => 'Thème, taille du texte et commentaires';

  @override
  String get faqsContactAppInfo =>
      'FAQ, contactez-nous et informations sur l\'application';

  @override
  String get viewSubmittedFeedback =>
      'Afficher vos commentaires soumis et les réponses de l\'administrateur';

  @override
  String get discoverSubtitle =>
      'Découvrez la cuisine et les expériences locales';

  @override
  String get searchHintLocalFood =>
      'Recherchez des entreprises alimentaires locales...';

  @override
  String get homeLabel => 'Accueil';

  @override
  String get recommendedForYou => 'Recommandé pour vous';

  @override
  String get seeAll => 'Tout voir';

  @override
  String get categories => 'Catégories';

  @override
  String get nearby => 'À proximité';

  @override
  String get noFoodPlacesFound => 'Aucun lieu de restauration trouvé';

  @override
  String get noFoodPlacesSubtitle =>
      'Essayez de modifier votre recherche ou vos sélections de filtres.';

  @override
  String get localFoodBusinesses => 'Entreprises alimentaires locales';

  @override
  String get localFoodSubtitle =>
      'Soutenir les petites et moyennes entreprises alimentaires de Brisbane';

  @override
  String get exploreReviewFoodBusinesses =>
      'Explorez et examinez les entreprises alimentaires';

  @override
  String get noSavedItemsTitle => 'Aucun élément enregistré pour l\'instant';

  @override
  String get noSavedItemsSubtitle =>
      'Appuyez sur l\'icône en forme de cœur sur les cartes de visite alimentaires ou sur le signet d\'un profil d\'entreprise pour les enregistrer ici.';

  @override
  String get savedEvents => 'Événements enregistrés';

  @override
  String get savedEventsSubtitle => 'Vos rappels et projets d\'événements';

  @override
  String get savedAttractions => 'Attractions enregistrées';

  @override
  String get savedAttractionsSubtitle =>
      'Lieux à visiter indépendamment des événements';

  @override
  String get savedBusinesses => 'Entreprises sauvegardées';

  @override
  String get savedBusinessesSubtitle =>
      'Entreprises alimentaires que vous avez mises en favoris';

  @override
  String get savedItemsUnavailableTitle => 'Éléments enregistrés indisponibles';

  @override
  String get savedItemsUnavailableSubtitle =>
      'Certains éléments enregistrés ne sont plus publiés dans le fil de découverte.';

  @override
  String get retryAction => 'Réessayer';

  @override
  String get unableToLoadDiscover =>
      'Impossible de charger les éléments de découverte pour le moment. Veuillez réessayer.';

  @override
  String get unableToLoadSaved =>
      'Impossible de charger les éléments enregistrés pour le moment. Veuillez réessayer.';

  @override
  String get dateTBA => 'Date à déterminer';

  @override
  String get timeTBA => 'Temps à déterminer';

  @override
  String get untitledEvent => 'Événement sans titre';

  @override
  String get locationTBA => 'Emplacement à déterminer';

  @override
  String get priceTBA => 'Prix à déterminer';

  @override
  String get placeFallback => 'Lieu';

  @override
  String get foodExperienceFallback => 'Expérience culinaire';

  @override
  String get stadiumFallback => 'Stade';

  @override
  String get eventFallback => 'Événement';

  @override
  String get attractionFallback => 'Attirance';

  @override
  String ratingReviewsCount(String rating, String count) {
    return '$rating · $count avis';
  }

  @override
  String get approved => 'Approuvé';

  @override
  String get audience => 'Public';

  @override
  String get businessLabel => 'Affaires';

  @override
  String get controlDistance =>
      'Distance de contrôle pour les opportunités à proximité';

  @override
  String get dashboard => 'Tableau de bord';

  @override
  String get delete => 'Supprimer';

  @override
  String get deleteEvent => 'Supprimer l\'événement';

  @override
  String get deletingEvent => 'Suppression d\'un événement...';

  @override
  String get displayName => 'Nom d\'affichage';

  @override
  String errorDeletingEvent(String error) {
    return 'Erreur lors de la suppression de l\'événement : $error';
  }

  @override
  String errorLoadingMap(String error) {
    return 'Erreur de chargement de la carte : $error';
  }

  @override
  String eventDeleted(String title) {
    return 'L\'événement \"$title\" a été supprimé.';
  }

  @override
  String get failedToDeleteEvent =>
      'Échec de la suppression de l\'événement. Veuillez réessayer.';

  @override
  String get feed => 'Nourrir';

  @override
  String get localBusinessPortal => 'Portail des entreprises locales';

  @override
  String get pending => 'En attente';

  @override
  String get phoneNumber => 'Numéro de téléphone';

  @override
  String get pleaseLoginLocal =>
      'Veuillez d\'abord vous connecter en tant qu\'utilisateur local.';

  @override
  String get pleaseLoginToDelete =>
      'Veuillez vous connecter pour supprimer des événements.';

  @override
  String get pushAlerts => 'Alertes push pour votre entreprise';

  @override
  String get rejected => 'Rejeté';

  @override
  String get reviews => 'Avis';

  @override
  String get saveChanges => 'Enregistrer les modifications';

  @override
  String get searchHintEvents =>
      'Rechercher des événements, des réservations...';

  @override
  String get suburb => 'Banlieue';

  @override
  String get thisLinkUnavailable =>
      'Ce lien n\'est pas disponible pour le moment.';

  @override
  String get total => 'Total';

  @override
  String get couldNotSaveSettings =>
      'Impossible d\'enregistrer les paramètres. Veuillez réessayer.';

  @override
  String get locationAccessDisabled =>
      'Accès à la localisation désactivé pour les fonctionnalités de l\'application.';

  @override
  String get locationPermissionGranted =>
      'Autorisation de localisation accordée.';

  @override
  String get openSettings => 'Ouvrir les paramètres';

  @override
  String get themeDark => 'Sombre';

  @override
  String get themeLight => 'Lumière';

  @override
  String get themeSystem => 'Système';

  @override
  String textScalePercent(String value) {
    return '$value%';
  }

  @override
  String categoryLabel(String category) {
    return 'Category: $category';
  }

  @override
  String severityLabel(String severity) {
    return 'Severity: $severity';
  }

  @override
  String get languageEnglish => 'Anglais';

  @override
  String get languageSpanish => 'Espagnol';

  @override
  String get languageFrench => 'Français';

  @override
  String get languageGerman => 'Allemand';

  @override
  String get languageChinese => 'Chinois';

  @override
  String get languageArabic => 'arabe';

  @override
  String get languageHindi => 'hindi';

  @override
  String get languageItalian => 'Italien';

  @override
  String get languageJapanese => 'Japonais';

  @override
  String get languageKorean => 'Coréen';

  @override
  String get languagePortuguese => 'Portugais';

  @override
  String get languageRussian => 'russe';

  @override
  String get languageVietnamese => 'Vietnamien';

  @override
  String get languageGreek => 'grec';

  @override
  String get languagePunjabi => 'Punjabi';

  @override
  String get discoverTitle => 'Découvrez la cuisine locale';

  @override
  String get openSourceLink => 'Lien Open Source';

  @override
  String get pendingApproval => 'En attente d\'approbation';

  @override
  String deleteEventConfirmation(String title) {
    return 'Etes-vous sûr de vouloir supprimer « $title » ? ';
  }

  @override
  String get myActivity => 'Mon activité';

  @override
  String get businessNotifications => 'Notifications professionnelles';

  @override
  String get about => 'À propos';

  @override
  String get aboutDescription =>
      'BrisConnect+ est un guide de ville intelligente qui aide les visiteurs et les habitants à découvrir des événements, à explorer des attractions et à capturer leurs expériences à Brisbane sur une seule plateforme connectée.';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get locationPermissions => 'Autorisations de localisation';

  @override
  String get enableLocationAccess => 'Activer l\'accès à l\'emplacement';

  @override
  String get allowNearbyMapFeatures =>
      'Autorisez les recommandations à proximité et les fonctionnalités adaptées à la carte.';

  @override
  String get locationSettings => 'Paramètres de localisation';

  @override
  String get setSearchRadius =>
      'Définissez votre rayon de recherche pour les événements et les attractions.';

  @override
  String get pleaseLoginToViewSettings =>
      'Veuillez vous connecter pour afficher les paramètres.';

  @override
  String get locationPermissionNotGranted =>
      'L\'autorisation de localisation n\'a pas été accordée. Vous pouvez l\'activer dans les paramètres système.';

  @override
  String get theme => 'Thème';

  @override
  String get appTheme => 'Thème de l\'application';

  @override
  String get chooseHowAppLooks => 'Choisissez l\'apparence de l\'application.';

  @override
  String get textSize => 'Taille du texte';

  @override
  String get adjustTextSize => 'Ajustez la taille du texte dans l’application.';

  @override
  String get smaller => 'Plus petit';

  @override
  String get larger => 'Plus grand';

  @override
  String get support => 'Soutien';

  @override
  String get sendAppFeedback => 'Envoyer des commentaires sur l\'application';

  @override
  String get reportBugsImprovements =>
      'Signalez des bogues, des informations trompeuses ou des suggestions d’amélioration.';

  @override
  String get noFeedbackYet => 'Vous n\'avez pas encore soumis de commentaires.';

  @override
  String get adminResponse => 'Réponse de l\'administrateur';

  @override
  String get awaitingAdminResponse =>
      'En attente de réponse de l\'administrateur...';

  @override
  String get statusPending => 'En attente';

  @override
  String get statusInProgress => 'En cours';

  @override
  String get statusResolved => 'Résolu';

  @override
  String get statusWontFix => 'Ne résoudra pas';

  @override
  String get foodBusinessDetails => 'Détails de l\'entreprise';

  @override
  String get aboutThisFoodExperience =>
      'À propos de cette expérience culinaire';

  @override
  String get highlights => 'Points forts';

  @override
  String get contactAndLinks => 'Contact et liens';

  @override
  String get gallery => 'Galerie';

  @override
  String get openingHours => 'Heures d\'ouverture';

  @override
  String get menu => 'Menu';

  @override
  String get menuFallback => 'Menu';

  @override
  String get call => 'Appeler';

  @override
  String get website => 'Site Web';

  @override
  String get orderOnline => 'Commander en ligne';

  @override
  String get viewOnMap => 'Voir sur la carte';

  @override
  String get foodDiscoveryGuide => 'Guide de découverte culinaire';

  @override
  String get foodDiscoveryGuideHelper =>
      'Appuyez sur lecture pour entendre votre guide de découverte culinaire décrire ce lieu et ses points forts.';

  @override
  String get stop => 'Arrêter';

  @override
  String get unableToStartNarration =>
      'Impossible de démarrer la narration du guide de découverte culinaire pour le moment.';

  @override
  String get unableToCallNumber =>
      'Impossible d\'appeler ce numéro pour le moment.';

  @override
  String get unableToSendEmail =>
      'Impossible d\'envoyer un e-mail pour le moment.';

  @override
  String get foodSpotCannotBeShared =>
      'Ce lieu gastronomique ne peut pas être partagé pour le moment.';

  @override
  String foodDescriptionIntro(String title, String cuisine, String location) {
    return 'Step into $title, a $cuisine destination in the heart of $location.';
  }

  @override
  String foodDescriptionRating(String rating) {
    return 'Apprécié des locaux comme des visiteurs, il détient une note de $rating étoiles.';
  }

  @override
  String foodDescriptionCategories(String categories) {
    return 'The menu celebrates $categories, crafted with fresh, locally sourced ingredients.';
  }

  @override
  String foodDescriptionPrice(String price) {
    return 'Expect a $price experience that balances quality and value.';
  }

  @override
  String foodDescriptionOutro(String title) {
    return 'Que vous recherchiez un brunch décontracté, un déjeuner d\'affaires ou un dîner animé, $title offre une atmosphère chaleureuse et des saveurs qui reflètent la scène culinaire de Brisbane.';
  }

  @override
  String foodNarrationWelcome(String title) {
    return 'Welcome to $title';
  }

  @override
  String foodNarrationBadge(String badge) {
    return 'This is a $badge stop worth adding to your Brisbane food trail';
  }

  @override
  String foodNarrationCuisine(String cuisine) {
    return 'It is best known for $cuisine';
  }

  @override
  String foodNarrationLocation(String location) {
    return 'You will find it in $location, where the local dining scene comes alive';
  }

  @override
  String foodNarrationDateTime(String dateTime) {
    return 'You can usually visit during $dateTime';
  }

  @override
  String foodNarrationDescription(String description) {
    return 'Here\'s what the experience feels like. $description';
  }

  @override
  String get foodNarrationPriceFree =>
      'There is no entry cost to explore this food spot';

  @override
  String foodNarrationPrice(String price) {
    return 'Pricing is listed as $price';
  }

  @override
  String foodNarrationRating(String rating) {
    return 'Visitors currently rate it $rating out of 5';
  }

  @override
  String foodNarrationCategories(String categories) {
    return 'Expect a mix of $categories';
  }
}
