// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'BrisConnect+';

  @override
  String get welcome => 'Benvenuto';

  @override
  String get signIn => 'Accedi';

  @override
  String get signUp => 'Registrati';

  @override
  String get signOut => 'Esci';

  @override
  String get email => 'E-mail';

  @override
  String get password => 'Password';

  @override
  String get phone => 'Telefono';

  @override
  String get name => 'Nome';

  @override
  String get save => 'Salva';

  @override
  String get cancel => 'Annulla';

  @override
  String get editProfile => 'Modifica profilo';

  @override
  String get profileInfo => 'Informazioni profilo';

  @override
  String get preferences => 'Preferenze';

  @override
  String get language => 'Lingua';

  @override
  String get locationRadius => 'Raggio di posizione';

  @override
  String get appearanceSettings => 'Aspetto';

  @override
  String get feedback => 'Feedback';

  @override
  String get myFeedback => 'I miei feedback';

  @override
  String get helpAndSupport => 'Aiuto e supporto';

  @override
  String get discover => 'Scopri';

  @override
  String get community => 'Comunità';

  @override
  String get map => 'Mappa';

  @override
  String get saved => 'Salvato';

  @override
  String get profile => 'Profilo';

  @override
  String get food => 'Cibo';

  @override
  String get events => 'Eventi';

  @override
  String get businesses => 'Attività';

  @override
  String get promotions => 'Promozioni';

  @override
  String get photos => 'Foto';

  @override
  String get newPost => 'Nuovo';

  @override
  String get search => 'Cerca';

  @override
  String get filter => 'Filtra';

  @override
  String get clearFilters => 'Cancella filtri';

  @override
  String get noResults => 'Nessun risultato trovato';

  @override
  String get loading => 'Caricamento...';

  @override
  String get error => 'Errore';

  @override
  String get success => 'Successo';

  @override
  String get profileUpdated => 'Profilo aggiornato con successo.';

  @override
  String get profileUpdateFailed =>
      'Impossibile aggiornare il profilo. Riprova.';

  @override
  String get guestVisitor => 'Visitatore ospite';

  @override
  String get localUser => 'Locale';

  @override
  String get filterEventsTitle => 'Filtra eventi';

  @override
  String get priceLabel => 'Prezzo';

  @override
  String get dateLabel => 'Data';

  @override
  String get pickADate => 'Scegli una data';

  @override
  String get resetButton => 'Ripristina';

  @override
  String get applyButton => 'Applicare';

  @override
  String get freeLabel => 'Gratuito';

  @override
  String get paidLabel => 'Pagato';

  @override
  String eventSavedToInterested(String eventTitle) {
    return '$eventTitle salvato in Interessato.';
  }

  @override
  String eventRemovedFromInterested(String eventTitle) {
    return '$eventTitle rimosso da Interessato.';
  }

  @override
  String savedToAttractions(String title) {
    return '$title salvato in Attrazioni salvate.';
  }

  @override
  String removedFromAttractions(String title) {
    return '$title rimosso dalle attrazioni salvate.';
  }

  @override
  String get pleaseSignInToSaveEvents =>
      'Accedi come visitatore per salvare gli eventi.';

  @override
  String get pleaseSignInToReview =>
      'Accedi per scrivere una recensione o BuzzVote.';

  @override
  String reviewSubmitted(String rating, String buzzRating) {
    return 'Recensione inviata\\! ⭐ $rating / Ronzio ⚡ $buzzRating';
  }

  @override
  String reviewSubmitFailed(String error) {
    return 'Impossibile inviare la recensione: $error';
  }

  @override
  String get noExternalLink =>
      'Nessun collegamento esterno ancora disponibile per questo articolo.';

  @override
  String get unableToOpenLink =>
      'Impossibile aprire il collegamento all\'evento in questo momento.';

  @override
  String shareTitle(String title) {
    return 'Condividi: $title';
  }

  @override
  String get reportEvent => 'Segnala evento';

  @override
  String get reviewsOnlyForFood =>
      'Le recensioni sono disponibili solo per i prodotti alimentari';

  @override
  String get chooseFromGallery => 'Scegli dalla galleria';

  @override
  String get takeAPhoto => 'Scatta una foto';

  @override
  String get pleaseLoginVisitor => 'Effettua prima l\'accesso come visitatore.';

  @override
  String get onlyJpgPng => 'Sono supportate solo le immagini JPG e PNG.';

  @override
  String get imageTooLarge =>
      'L\'immagine è troppo grande. Scegli un\'immagine più piccola.';

  @override
  String get profilePictureUpdated =>
      'Immagine del profilo aggiornata correttamente.';

  @override
  String get profilePictureUpdateFailed =>
      'Impossibile aggiornare l\'immagine del profilo. Per favore riprova.';

  @override
  String get enterYourName => 'Inserisci il tuo nome';

  @override
  String get phoneHint => 'ad es. 04xxxxxxxxx';

  @override
  String get nameCannotBeEmpty => 'Il nome non può essere vuoto.';

  @override
  String get nameMinLength => 'Il nome deve contenere almeno 2 caratteri.';

  @override
  String get enterValidPhone => 'Inserisci un numero di telefono valido.';

  @override
  String get changeProfilePicture => 'Cambia l\'immagine del profilo';

  @override
  String get uploadProfilePicture => 'Carica l\'immagine del profilo';

  @override
  String get areYouSureSignOut => 'Sei sicuro di voler uscire?';

  @override
  String get returnWelcome => 'Ritorna alla schermata di benvenuto';

  @override
  String get setHowFarRecommendations =>
      'Imposta quanto lontano possono essere i consigli';

  @override
  String get themeTextSizeFeedback => 'Tema, dimensione del testo e feedback';

  @override
  String get faqsContactAppInfo =>
      'Domande frequenti, contatti e informazioni sull\'app';

  @override
  String get viewSubmittedFeedback =>
      'Visualizza il feedback inviato e le risposte dell\'amministratore';

  @override
  String get discoverSubtitle => 'Scopri il cibo e le esperienze locali';

  @override
  String get searchHintLocalFood => 'Cerca aziende alimentari locali...';

  @override
  String get homeLabel => 'Casa';

  @override
  String get recommendedForYou => 'Consigliato per te';

  @override
  String get seeAll => 'Vedi tutto';

  @override
  String get categories => 'Categorie';

  @override
  String get nearby => 'Nelle vicinanze';

  @override
  String get noFoodPlacesFound => 'Nessun posto dove mangiare trovato';

  @override
  String get noFoodPlacesSubtitle =>
      'Prova a modificare la ricerca o le selezioni dei filtri.';

  @override
  String get localFoodBusinesses => 'Imprese alimentari locali';

  @override
  String get localFoodSubtitle =>
      'Sostieni le piccole e medie imprese alimentari di Brisbane';

  @override
  String get exploreReviewFoodBusinesses =>
      'Esplora e recensisci le aziende alimentari';

  @override
  String get noSavedItemsTitle => 'Nessun elemento salvato ancora';

  @override
  String get noSavedItemsSubtitle =>
      'Tocca l\'icona del cuore sui biglietti da visita del settore alimentare o il segnalibro su un profilo aziendale per salvarli qui.';

  @override
  String get savedEvents => 'Eventi salvati';

  @override
  String get savedEventsSubtitle => 'Promemoria e piani dei tuoi eventi';

  @override
  String get savedAttractions => 'Attrazioni salvate';

  @override
  String get savedAttractionsSubtitle =>
      'Luoghi da visitare indipendentemente dagli eventi';

  @override
  String get savedBusinesses => 'Imprese salvate';

  @override
  String get savedBusinessesSubtitle =>
      'Aziende alimentari che hai aggiunto ai segnalibri';

  @override
  String get savedItemsUnavailableTitle => 'Articoli salvati non disponibili';

  @override
  String get savedItemsUnavailableSubtitle =>
      'Alcuni elementi salvati non vengono più pubblicati nel feed di scoperta.';

  @override
  String get retryAction => 'Riprova';

  @override
  String get unableToLoadDiscover =>
      'Impossibile caricare gli elementi da scoprire in questo momento. Per favore riprova.';

  @override
  String get unableToLoadSaved =>
      'Impossibile caricare gli elementi salvati in questo momento. Per favore riprova.';

  @override
  String get dateTBA => 'Data da definire';

  @override
  String get timeTBA => 'Tempo da definire';

  @override
  String get untitledEvent => 'Evento senza titolo';

  @override
  String get locationTBA => 'Posizione da definire';

  @override
  String get priceTBA => 'Prezzo da definire';

  @override
  String get placeFallback => 'Luogo';

  @override
  String get foodExperienceFallback => 'Esperienza gastronomica';

  @override
  String get stadiumFallback => 'Stadio';

  @override
  String get eventFallback => 'Evento';

  @override
  String get attractionFallback => 'Attrazione';

  @override
  String ratingReviewsCount(String rating, String count) {
    return '$rating · $count recensioni';
  }

  @override
  String get approved => 'Approvato';

  @override
  String get audience => 'Pubblico';

  @override
  String get businessLabel => 'Affari';

  @override
  String get controlDistance =>
      'Controlla la distanza per le opportunità vicine';

  @override
  String get dashboard => 'Cruscotto';

  @override
  String get delete => 'Elimina';

  @override
  String get deleteEvent => 'Elimina evento';

  @override
  String get deletingEvent => 'Eliminazione evento...';

  @override
  String get displayName => 'Nome visualizzato';

  @override
  String errorDeletingEvent(String error) {
    return 'Errore durante l\'eliminazione dell\'evento: $error';
  }

  @override
  String errorLoadingMap(String error) {
    return 'Errore durante il caricamento della mappa: $error';
  }

  @override
  String eventDeleted(String title) {
    return 'L\'evento \"$title\" è stato eliminato.';
  }

  @override
  String get failedToDeleteEvent =>
      'Impossibile eliminare l\'evento. Per favore riprova.';

  @override
  String get feed => 'Nutrire';

  @override
  String get localBusinessPortal => 'Portale delle imprese locali';

  @override
  String get pending => 'In sospeso';

  @override
  String get phoneNumber => 'Numero di telefono';

  @override
  String get pleaseLoginLocal => 'Accedi prima come utente locale.';

  @override
  String get pleaseLoginToDelete =>
      'Effettua il login per eliminare gli eventi.';

  @override
  String get pushAlerts => 'Avvisi push per la tua attività';

  @override
  String get rejected => 'Rifiutato';

  @override
  String get reviews => 'Recensioni';

  @override
  String get saveChanges => 'Salva modifiche';

  @override
  String get searchHintEvents => 'Cerca eventi, prenotazioni...';

  @override
  String get suburb => 'Sobborgo';

  @override
  String get thisLinkUnavailable =>
      'Questo collegamento non è disponibile al momento.';

  @override
  String get total => 'Totale';

  @override
  String get couldNotSaveSettings =>
      'Impossibile salvare le impostazioni. Per favore riprova.';

  @override
  String get locationAccessDisabled =>
      'Accesso alla posizione disabilitato per le funzionalità dell\'app.';

  @override
  String get locationPermissionGranted =>
      'Autorizzazione alla posizione concessa.';

  @override
  String get openSettings => 'Apri Impostazioni';

  @override
  String get themeDark => 'Buio';

  @override
  String get themeLight => 'Luce';

  @override
  String get themeSystem => 'Sistema';

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
  String get languageEnglish => 'Inglese';

  @override
  String get languageSpanish => 'spagnolo';

  @override
  String get languageFrench => 'francese';

  @override
  String get languageGerman => 'tedesco';

  @override
  String get languageChinese => 'Cinese';

  @override
  String get languageArabic => 'Arabo';

  @override
  String get languageHindi => 'Hindi';

  @override
  String get languageItalian => 'italiano';

  @override
  String get languageJapanese => 'giapponese';

  @override
  String get languageKorean => 'Coreano';

  @override
  String get languagePortuguese => 'Portoghese';

  @override
  String get languageRussian => 'Russo';

  @override
  String get languageVietnamese => 'Vietnamita';

  @override
  String get languageGreek => 'greco';

  @override
  String get languagePunjabi => 'Punjabi';

  @override
  String get discoverTitle => 'Scopri il cibo locale';

  @override
  String get openSourceLink => 'Collegamento open source';

  @override
  String get pendingApproval => 'In attesa di approvazione';

  @override
  String deleteEventConfirmation(String title) {
    return 'Sei sicuro di voler eliminare \"$title\"? ';
  }

  @override
  String get myActivity => 'La mia attività';

  @override
  String get businessNotifications => 'Notifiche aziendali';

  @override
  String get about => 'Di';

  @override
  String get aboutDescription =>
      'BrisConnect+ è una guida intelligente della città che aiuta i visitatori e la gente del posto a scoprire eventi, esplorare attrazioni e catturare le loro esperienze a Brisbane in un\'unica piattaforma connessa.';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get locationPermissions => 'Autorizzazioni di posizione';

  @override
  String get enableLocationAccess => 'Abilita l\'accesso alla posizione';

  @override
  String get allowNearbyMapFeatures =>
      'Consenti consigli nelle vicinanze e funzionalità basate sulla mappa.';

  @override
  String get locationSettings => 'Impostazioni di posizione';

  @override
  String get setSearchRadius =>
      'Imposta il tuo raggio di ricerca per eventi e attrazioni.';

  @override
  String get pleaseLoginToViewSettings =>
      'Effettua il login per visualizzare le impostazioni.';

  @override
  String get locationPermissionNotGranted =>
      'L\'autorizzazione alla posizione non è stata concessa. Puoi abilitarlo nelle impostazioni di sistema.';

  @override
  String get theme => 'Tema';

  @override
  String get appTheme => 'Tema dell\'app';

  @override
  String get chooseHowAppLooks => 'Scegli l\'aspetto dell\'app.';

  @override
  String get textSize => 'Dimensione del testo';

  @override
  String get adjustTextSize => 'Regola la dimensione del testo nell\'app.';

  @override
  String get smaller => 'Più piccolo';

  @override
  String get larger => 'Più grande';

  @override
  String get support => 'Supporto';

  @override
  String get sendAppFeedback => 'Invia feedback sull\'app';

  @override
  String get reportBugsImprovements =>
      'Segnala bug, informazioni fuorvianti o suggerimenti di miglioramento.';

  @override
  String get noFeedbackYet => 'Non hai ancora inviato alcun feedback.';

  @override
  String get adminResponse => 'Risposta dell\'amministratore';

  @override
  String get awaitingAdminResponse =>
      'In attesa della risposta dell\'amministratore...';

  @override
  String get statusPending => 'In attesa di';

  @override
  String get statusInProgress => 'In corso';

  @override
  String get statusResolved => 'Risolto';

  @override
  String get statusWontFix => 'Non risolverà';

  @override
  String get foodBusinessDetails => 'Dettagli aziendali';

  @override
  String get aboutThisFoodExperience =>
      'Informazioni su questa esperienza culinaria';

  @override
  String get highlights => 'Punti salienti';

  @override
  String get contactAndLinks => 'Contatti e link';

  @override
  String get gallery => 'Galleria';

  @override
  String get openingHours => 'Orari di apertura';

  @override
  String get menu => 'Menu';

  @override
  String get menuFallback => 'Menu';

  @override
  String get call => 'Chiamata';

  @override
  String get website => 'Sito web';

  @override
  String get orderOnline => 'Ordina online';

  @override
  String get viewOnMap => 'Visualizza sulla mappa';

  @override
  String get foodDiscoveryGuide => 'Guida alla scoperta del cibo';

  @override
  String get foodDiscoveryGuideHelper =>
      'Tocca play per ascoltare la tua Guida alla Scoperta del Cibo che descrive questo locale e i suoi punti di forza.';

  @override
  String get stop => 'Fermare';

  @override
  String get unableToStartNarration =>
      'Impossibile avviare la narrazione della Guida alla scoperta del cibo in questo momento.';

  @override
  String get unableToCallNumber =>
      'Impossibile chiamare questo numero in questo momento.';

  @override
  String get unableToSendEmail =>
      'Impossibile inviare l&#39;email in questo momento.';

  @override
  String get foodSpotCannotBeShared =>
      'Questo locale non può essere condiviso al momento.';

  @override
  String foodDescriptionIntro(String title, String cuisine, String location) {
    return 'Step into $title, a $cuisine destination in the heart of $location.';
  }

  @override
  String foodDescriptionRating(String rating) {
    return 'Apprezzato sia dai residenti che dai turisti, vanta una valutazione di $rating stelle.';
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
    return 'Che siate alla ricerca di un brunch rilassante, di un pranzo di lavoro o di una cena vivace, $title offre un&#39;atmosfera accogliente e sapori che rispecchiano la scena gastronomica di Brisbane.';
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
