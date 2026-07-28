// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'BrisConnect+';

  @override
  String get welcome => 'Willkommen';

  @override
  String get signIn => 'Anmelden';

  @override
  String get signUp => 'Registrieren';

  @override
  String get signOut => 'Abmelden';

  @override
  String get email => 'E-Mail';

  @override
  String get password => 'Passwort';

  @override
  String get phone => 'Telefon';

  @override
  String get name => 'Name';

  @override
  String get save => 'Speichern';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get editProfile => 'Profil bearbeiten';

  @override
  String get profileInfo => 'Profilinformationen';

  @override
  String get preferences => 'Einstellungen';

  @override
  String get language => 'Sprache';

  @override
  String get locationRadius => 'Standortradius';

  @override
  String get appearanceSettings => 'Erscheinungsbild';

  @override
  String get feedback => 'Feedback';

  @override
  String get myFeedback => 'Mein Feedback';

  @override
  String get helpAndSupport => 'Hilfe & Support';

  @override
  String get discover => 'Entdecken';

  @override
  String get community => 'Community';

  @override
  String get map => 'Karte';

  @override
  String get saved => 'Gespeichert';

  @override
  String get profile => 'Profil';

  @override
  String get food => 'Essen';

  @override
  String get events => 'Veranstaltungen';

  @override
  String get businesses => 'Unternehmen';

  @override
  String get promotions => 'Aktionen';

  @override
  String get photos => 'Fotos';

  @override
  String get newPost => 'Neu';

  @override
  String get search => 'Suchen';

  @override
  String get filter => 'Filter';

  @override
  String get clearFilters => 'Filter löschen';

  @override
  String get noResults => 'Keine Ergebnisse gefunden';

  @override
  String get loading => 'Wird geladen...';

  @override
  String get error => 'Fehler';

  @override
  String get success => 'Erfolg';

  @override
  String get profileUpdated => 'Profil erfolgreich aktualisiert.';

  @override
  String get profileUpdateFailed =>
      'Profil konnte nicht aktualisiert werden. Bitte versuche es erneut.';

  @override
  String get guestVisitor => 'Gastbesucher';

  @override
  String get localUser => 'Lokal';

  @override
  String get filterEventsTitle => 'Ereignisse filtern';

  @override
  String get priceLabel => 'Preis';

  @override
  String get dateLabel => 'Datum';

  @override
  String get pickADate => 'Wählen Sie ein Datum';

  @override
  String get resetButton => 'Zurücksetzen';

  @override
  String get applyButton => 'Bewerben';

  @override
  String get freeLabel => 'Kostenlos';

  @override
  String get paidLabel => 'Bezahlt';

  @override
  String eventSavedToInterested(String eventTitle) {
    return '$eventTitle wurde unter „Interessiert“ gespeichert.';
  }

  @override
  String eventRemovedFromInterested(String eventTitle) {
    return '$eventTitle aus „Interessiert“ entfernt.';
  }

  @override
  String savedToAttractions(String title) {
    return '$title wurde unter „Gespeicherte Attraktionen“ gespeichert.';
  }

  @override
  String removedFromAttractions(String title) {
    return '$title aus den gespeicherten Attraktionen entfernt.';
  }

  @override
  String get pleaseSignInToSaveEvents =>
      'Bitte melden Sie sich als Besucher an, um Ereignisse zu speichern.';

  @override
  String get pleaseSignInToReview =>
      'Bitte melden Sie sich an, um eine Bewertung oder BuzzVote zu schreiben.';

  @override
  String reviewSubmitted(String rating, String buzzRating) {
    return 'Bewertung abgegeben\\! ⭐ $rating / Buzz ⚡ $buzzRating';
  }

  @override
  String reviewSubmitFailed(String error) {
    return 'Bewertung konnte nicht eingereicht werden: $error';
  }

  @override
  String get noExternalLink =>
      'Für diesen Artikel ist noch kein externer Link verfügbar.';

  @override
  String get unableToOpenLink =>
      'Der Veranstaltungslink kann derzeit nicht geöffnet werden.';

  @override
  String shareTitle(String title) {
    return 'Teilen: $title';
  }

  @override
  String get reportEvent => 'Ereignis melden';

  @override
  String get reviewsOnlyForFood =>
      'Bewertungen sind nur für Lebensmittel verfügbar';

  @override
  String get chooseFromGallery => 'Wählen Sie aus der Galerie';

  @override
  String get takeAPhoto => 'Machen Sie ein Foto';

  @override
  String get pleaseLoginVisitor =>
      'Bitte loggen Sie sich zunächst als Besucher ein.';

  @override
  String get onlyJpgPng => 'Es werden nur JPG- und PNG-Bilder unterstützt.';

  @override
  String get imageTooLarge =>
      'Bild ist zu groß. Bitte wählen Sie ein kleineres Bild.';

  @override
  String get profilePictureUpdated => 'Profilbild erfolgreich aktualisiert.';

  @override
  String get profilePictureUpdateFailed =>
      'Profilbild konnte nicht aktualisiert werden. Bitte versuchen Sie es erneut.';

  @override
  String get enterYourName => 'Geben Sie Ihren Namen ein';

  @override
  String get phoneHint => 'z.B. 04xxxxxxxx';

  @override
  String get nameCannotBeEmpty => 'Der Name darf nicht leer sein.';

  @override
  String get nameMinLength => 'Der Name muss mindestens 2 Zeichen lang sein.';

  @override
  String get enterValidPhone => 'Geben Sie eine gültige Telefonnummer ein.';

  @override
  String get changeProfilePicture => 'Profilbild ändern';

  @override
  String get uploadProfilePicture => 'Profilbild hochladen';

  @override
  String get areYouSureSignOut =>
      'Sind Sie sicher, dass Sie sich abmelden möchten?';

  @override
  String get returnWelcome => 'Kehren Sie zum Begrüßungsbildschirm zurück';

  @override
  String get setHowFarRecommendations =>
      'Legen Sie fest, wie weit Empfehlungen gehen können';

  @override
  String get themeTextSizeFeedback => 'Thema, Textgröße und Feedback';

  @override
  String get faqsContactAppInfo => 'FAQs, Kontakt und App-Infos';

  @override
  String get viewSubmittedFeedback =>
      'Sehen Sie sich Ihre eingereichten Rückmeldungen und Administratorantworten an';

  @override
  String get discoverSubtitle => 'Entdecken Sie lokale Speisen und Erlebnisse';

  @override
  String get searchHintLocalFood =>
      'Lokale Lebensmittelunternehmen durchsuchen...';

  @override
  String get homeLabel => 'Zuhause';

  @override
  String get recommendedForYou => 'Für Sie empfohlen';

  @override
  String get seeAll => 'Alle anzeigen';

  @override
  String get categories => 'Kategorien';

  @override
  String get nearby => 'In der Nähe';

  @override
  String get noFoodPlacesFound => 'Keine Essensmöglichkeiten gefunden';

  @override
  String get noFoodPlacesSubtitle =>
      'Versuchen Sie, Ihre Such- oder Filterauswahl zu ändern.';

  @override
  String get localFoodBusinesses => 'Lokale Lebensmittelunternehmen';

  @override
  String get localFoodSubtitle =>
      'Unterstützen Sie kleine und mittlere Lebensmittelunternehmen in Brisbane';

  @override
  String get exploreReviewFoodBusinesses =>
      'Entdecken und bewerten Sie Lebensmittelunternehmen';

  @override
  String get noSavedItemsTitle => 'Noch keine gespeicherten Artikel';

  @override
  String get noSavedItemsSubtitle =>
      'Tippen Sie auf das Herzsymbol auf Lebensmittel-Visitenkarten oder auf das Lesezeichen in einem Unternehmensprofil, um sie hier zu speichern.';

  @override
  String get savedEvents => 'Gespeicherte Ereignisse';

  @override
  String get savedEventsSubtitle =>
      'Ihre Veranstaltungserinnerungen und -pläne';

  @override
  String get savedAttractions => 'Gespeicherte Attraktionen';

  @override
  String get savedAttractionsSubtitle =>
      'Orte, die Sie unabhängig von Veranstaltungen besuchen können';

  @override
  String get savedBusinesses => 'Gerettete Unternehmen';

  @override
  String get savedBusinessesSubtitle =>
      'Lebensmittelunternehmen, die Sie markiert haben';

  @override
  String get savedItemsUnavailableTitle =>
      'Gespeicherte Artikel nicht verfügbar';

  @override
  String get savedItemsUnavailableSubtitle =>
      'Einige gespeicherte Elemente werden nicht mehr im Discovery-Feed veröffentlicht.';

  @override
  String get retryAction => 'Versuchen Sie es noch einmal';

  @override
  String get unableToLoadDiscover =>
      'Die Discovery-Elemente können derzeit nicht geladen werden. Bitte versuchen Sie es erneut.';

  @override
  String get unableToLoadSaved =>
      'Gespeicherte Elemente können derzeit nicht geladen werden. Bitte versuchen Sie es erneut.';

  @override
  String get dateTBA => 'Datum wird noch bekannt gegeben';

  @override
  String get timeTBA => 'Zeit wird noch bekannt gegeben';

  @override
  String get untitledEvent => 'Veranstaltung ohne Titel';

  @override
  String get locationTBA => 'Standort wird noch bekannt gegeben';

  @override
  String get priceTBA => 'Preis wird noch bekannt gegeben';

  @override
  String get placeFallback => 'Platz';

  @override
  String get foodExperienceFallback => 'Essenserlebnis';

  @override
  String get stadiumFallback => 'Stadion';

  @override
  String get eventFallback => 'Veranstaltung';

  @override
  String get attractionFallback => 'Attraktion';

  @override
  String ratingReviewsCount(String rating, String count) {
    return '$rating · $count Bewertungen';
  }

  @override
  String get approved => 'Genehmigt';

  @override
  String get audience => 'Publikum';

  @override
  String get businessLabel => 'Geschäft';

  @override
  String get controlDistance =>
      'Kontrollieren Sie die Entfernung für Gelegenheiten in der Nähe';

  @override
  String get dashboard => 'Armaturenbrett';

  @override
  String get delete => 'Löschen';

  @override
  String get deleteEvent => 'Ereignis löschen';

  @override
  String get deletingEvent => 'Veranstaltung wird gelöscht...';

  @override
  String get displayName => 'Anzeigename';

  @override
  String errorDeletingEvent(String error) {
    return 'Fehler beim Löschen des Ereignisses: $error';
  }

  @override
  String errorLoadingMap(String error) {
    return 'Fehler beim Laden der Karte: $error';
  }

  @override
  String eventDeleted(String title) {
    return 'Ereignis „$title“ wurde gelöscht.';
  }

  @override
  String get failedToDeleteEvent =>
      'Ereignis konnte nicht gelöscht werden. Bitte versuchen Sie es erneut.';

  @override
  String get feed => 'Futter';

  @override
  String get localBusinessPortal => 'Lokales Unternehmensportal';

  @override
  String get pending => 'Ausstehend';

  @override
  String get phoneNumber => 'Telefonnummer';

  @override
  String get pleaseLoginLocal =>
      'Bitte melden Sie sich zunächst als lokaler Benutzer an.';

  @override
  String get pleaseLoginToDelete =>
      'Bitte melden Sie sich an, um Ereignisse zu löschen.';

  @override
  String get pushAlerts => 'Push-Benachrichtigungen für Ihr Unternehmen';

  @override
  String get rejected => 'Abgelehnt';

  @override
  String get reviews => 'Rezensionen';

  @override
  String get saveChanges => 'Änderungen speichern';

  @override
  String get searchHintEvents =>
      'Suchen Sie nach Veranstaltungen, Buchungen...';

  @override
  String get suburb => 'Vorort';

  @override
  String get thisLinkUnavailable => 'Dieser Link ist derzeit nicht verfügbar.';

  @override
  String get total => 'Insgesamt';

  @override
  String get couldNotSaveSettings =>
      'Die Einstellungen konnten nicht gespeichert werden. Bitte versuchen Sie es erneut.';

  @override
  String get locationAccessDisabled =>
      'Standortzugriff für App-Funktionen deaktiviert.';

  @override
  String get locationPermissionGranted => 'Standortgenehmigung erteilt.';

  @override
  String get openSettings => 'Öffnen Sie Einstellungen';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get themeLight => 'Licht';

  @override
  String get themeSystem => 'System';

  @override
  String textScalePercent(String value) {
    return '$value%';
  }

  @override
  String categoryLabel(String category) {
    return 'Kategorie: $category';
  }

  @override
  String severityLabel(String severity) {
    return 'Schweregrad: $severity';
  }

  @override
  String get languageEnglish => 'Englisch';

  @override
  String get languageSpanish => 'Spanisch';

  @override
  String get languageFrench => 'Französisch';

  @override
  String get languageGerman => 'Deutsch';

  @override
  String get languageChinese => 'Chinesisch';

  @override
  String get languageArabic => 'Arabisch';

  @override
  String get languageHindi => 'Hindi';

  @override
  String get languageItalian => 'Italienisch';

  @override
  String get languageJapanese => 'Japanisch';

  @override
  String get languageKorean => 'Koreanisch';

  @override
  String get languagePortuguese => 'Portugiesisch';

  @override
  String get languageRussian => 'Russisch';

  @override
  String get languageVietnamese => 'Vietnamesisch';

  @override
  String get languageGreek => 'Griechisch';

  @override
  String get discoverTitle => 'Entdecken Sie lokales Essen';

  @override
  String get openSourceLink => 'Open-Source-Link';

  @override
  String get pendingApproval => 'Ausstehende Genehmigung';

  @override
  String deleteEventConfirmation(String title) {
    return 'Sind Sie sicher, dass Sie „$title“ löschen möchten? ';
  }

  @override
  String get myActivity => 'Meine Aktivität';

  @override
  String get businessNotifications => 'Geschäftsbenachrichtigungen';

  @override
  String get about => 'Um';

  @override
  String get aboutDescription =>
      'BrisConnect+ ist ein intelligenter Stadtführer, der Besuchern und Einheimischen dabei hilft, Veranstaltungen zu entdecken, Sehenswürdigkeiten zu erkunden und ihre Brisbane-Erlebnisse auf einer vernetzten Plattform festzuhalten.';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get locationPermissions => 'Standortberechtigungen';

  @override
  String get enableLocationAccess => 'Aktivieren Sie den Standortzugriff';

  @override
  String get allowNearbyMapFeatures =>
      'Erlauben Sie Empfehlungen in der Nähe und kartenbasierte Funktionen.';

  @override
  String get locationSettings => 'Standorteinstellungen';

  @override
  String get setSearchRadius =>
      'Legen Sie Ihren Suchradius für Veranstaltungen und Attraktionen fest.';

  @override
  String get pleaseLoginToViewSettings =>
      'Bitte melden Sie sich an, um die Einstellungen anzuzeigen.';

  @override
  String get locationPermissionNotGranted =>
      'Die Standortgenehmigung wurde nicht erteilt. Sie können es in den Systemeinstellungen aktivieren.';

  @override
  String get theme => 'Thema';

  @override
  String get appTheme => 'App-Theme';

  @override
  String get chooseHowAppLooks => 'Wählen Sie, wie die App aussehen soll.';

  @override
  String get textSize => 'Textgröße';

  @override
  String get adjustTextSize =>
      'Passen Sie die Textgröße in der gesamten App an.';

  @override
  String get smaller => 'Kleiner';

  @override
  String get larger => 'Größer';

  @override
  String get support => 'Unterstützung';

  @override
  String get sendAppFeedback => 'App-Feedback senden';

  @override
  String get reportBugsImprovements =>
      'Melden Sie Fehler, irreführende Informationen oder Verbesserungsvorschläge.';

  @override
  String get noFeedbackYet => 'Sie haben noch kein Feedback abgegeben.';

  @override
  String get adminResponse => 'Antwort des Administrators';

  @override
  String get awaitingAdminResponse => 'Warte auf Antwort des Administrators...';

  @override
  String get statusPending => 'Ausstehend';

  @override
  String get statusInProgress => 'Im Gange';

  @override
  String get statusResolved => 'Gelöst';

  @override
  String get statusWontFix => 'Wird nicht repariert';
}
