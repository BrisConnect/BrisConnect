// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Modern Greek (`el`).
class AppLocalizationsEl extends AppLocalizations {
  AppLocalizationsEl([String locale = 'el']) : super(locale);

  @override
  String get appTitle => 'BrisConnect+';

  @override
  String get welcome => 'Καλώς ήρθατε';

  @override
  String get signIn => 'Σύνδεση';

  @override
  String get signUp => 'Εγγραφή';

  @override
  String get signOut => 'Αποσύνδεση';

  @override
  String get email => 'Email';

  @override
  String get password => 'Κωδικός πρόσβασης';

  @override
  String get phone => 'Τηλέφωνο';

  @override
  String get name => 'Όνομα';

  @override
  String get save => 'Αποθήκευση';

  @override
  String get cancel => 'Ακύρωση';

  @override
  String get editProfile => 'Επεξεργασία προφίλ';

  @override
  String get profileInfo => 'Πληροφορίες προφίλ';

  @override
  String get preferences => 'Προτιμήσεις';

  @override
  String get language => 'Γλώσσα';

  @override
  String get locationRadius => 'Ακτίνα τοποθεσίας';

  @override
  String get appearanceSettings => 'Ρυθμίσεις εμφάνισης';

  @override
  String get feedback => 'Σχόλια';

  @override
  String get myFeedback => 'Τα σχόλιά μου';

  @override
  String get helpAndSupport => 'Βοήθεια και υποστήριξη';

  @override
  String get discover => 'Ανακαλύψτε';

  @override
  String get community => 'Κοινότητα';

  @override
  String get map => 'Χάρτης';

  @override
  String get saved => 'Αποθηκευμένα';

  @override
  String get profile => 'Προφίλ';

  @override
  String get food => 'Φαγητό';

  @override
  String get events => 'Εκδηλώσεις';

  @override
  String get businesses => 'Επιχειρήσεις';

  @override
  String get promotions => 'Προσφορές';

  @override
  String get photos => 'Φωτογραφίες';

  @override
  String get newPost => 'Νέο';

  @override
  String get search => 'Αναζήτηση';

  @override
  String get filter => 'Φίλτρο';

  @override
  String get clearFilters => 'Καθαρισμός φίλτρων';

  @override
  String get noResults => 'Δεν βρέθηκαν αποτελέσματα';

  @override
  String get loading => 'Φόρτωση...';

  @override
  String get error => 'Σφάλμα';

  @override
  String get success => 'Επιτυχία';

  @override
  String get profileUpdated => 'Το προφίλ ενημερώθηκε με επιτυχία.';

  @override
  String get profileUpdateFailed =>
      'Δεν ήταν δυνατή η ενημέρωση του προφίλ. Προσπαθήστε ξανά.';

  @override
  String get guestVisitor => 'Επισκέπτης';

  @override
  String get localUser => 'Τοπικός';

  @override
  String get filterEventsTitle => 'Φιλτράρισμα συμβάντων';

  @override
  String get priceLabel => 'Τιμή';

  @override
  String get dateLabel => 'Ημερομηνία';

  @override
  String get pickADate => 'Επιλέξτε μια ημερομηνία';

  @override
  String get resetButton => 'Επαναφορά';

  @override
  String get applyButton => 'Εφαρμόστε';

  @override
  String get freeLabel => 'Δωρεάν';

  @override
  String get paidLabel => 'Πληρωμένη';

  @override
  String eventSavedToInterested(String eventTitle) {
    return 'Το $eventTitle αποθηκεύτηκε στους Ενδιαφερόμενους.';
  }

  @override
  String eventRemovedFromInterested(String eventTitle) {
    return 'Το $eventTitle καταργήθηκε από το στοιχείο Ενδιαφέρομαι.';
  }

  @override
  String savedToAttractions(String title) {
    return 'Το $title αποθηκεύτηκε στα Αποθηκευμένα αξιοθέατα.';
  }

  @override
  String removedFromAttractions(String title) {
    return 'Το $title καταργήθηκε από τα αποθηκευμένα αξιοθέατα.';
  }

  @override
  String get pleaseSignInToSaveEvents =>
      'Παρακαλούμε συνδεθείτε ως επισκέπτης για να αποθηκεύσετε συμβάντα.';

  @override
  String get pleaseSignInToReview =>
      'Συνδεθείτε για να γράψετε μια κριτική ή το BuzzVote.';

  @override
  String reviewSubmitted(String rating, String buzzRating) {
    return 'Η κριτική υποβλήθηκε\\! ⭐ $rating / Buzz ⚡ $buzzRating';
  }

  @override
  String reviewSubmitFailed(String error) {
    return 'Δεν ήταν δυνατή η υποβολή κριτικής: $error';
  }

  @override
  String get noExternalLink =>
      'Δεν υπάρχει ακόμη διαθέσιμος εξωτερικός σύνδεσμος για αυτό το αντικείμενο.';

  @override
  String get unableToOpenLink =>
      'Δεν είναι δυνατό το άνοιγμα του συνδέσμου της εκδήλωσης αυτήν τη στιγμή.';

  @override
  String shareTitle(String title) {
    return 'Κοινή χρήση: $title';
  }

  @override
  String get reportEvent => 'Αναφορά συμβάντος';

  @override
  String get reviewsOnlyForFood =>
      'Οι κριτικές είναι διαθέσιμες μόνο για τρόφιμα';

  @override
  String get chooseFromGallery => 'Επιλέξτε από τη συλλογή';

  @override
  String get takeAPhoto => 'Βγάλε μια φωτογραφία';

  @override
  String get pleaseLoginVisitor => 'Συνδεθείτε πρώτα ως Επισκέπτης.';

  @override
  String get onlyJpgPng => 'Υποστηρίζονται μόνο εικόνες JPG και PNG.';

  @override
  String get imageTooLarge =>
      'Η εικόνα είναι πολύ μεγάλη. Επιλέξτε μια μικρότερη εικόνα.';

  @override
  String get profilePictureUpdated =>
      'Η εικόνα προφίλ ενημερώθηκε με επιτυχία.';

  @override
  String get profilePictureUpdateFailed =>
      'Δεν ήταν δυνατή η ενημέρωση της εικόνας προφίλ. Δοκιμάστε ξανά.';

  @override
  String get enterYourName => 'Εισαγάγετε το όνομά σας';

  @override
  String get phoneHint => 'π.χ. 04χχχχχχχχ';

  @override
  String get nameCannotBeEmpty => 'Το όνομα δεν μπορεί να είναι κενό.';

  @override
  String get nameMinLength =>
      'Το όνομα πρέπει να αποτελείται από τουλάχιστον 2 χαρακτήρες.';

  @override
  String get enterValidPhone => 'Εισαγάγετε έναν έγκυρο αριθμό τηλεφώνου.';

  @override
  String get changeProfilePicture => 'Αλλαγή εικόνας προφίλ';

  @override
  String get uploadProfilePicture => 'Μεταφόρτωση φωτογραφίας προφίλ';

  @override
  String get areYouSureSignOut => 'Είστε βέβαιοι ότι θέλετε να αποσυνδεθείτε;';

  @override
  String get returnWelcome => 'Επιστρέψτε στην οθόνη καλωσορίσματος';

  @override
  String get setHowFarRecommendations =>
      'Ορίστε πόσο μακριά μπορούν να είναι οι συστάσεις';

  @override
  String get themeTextSizeFeedback => 'Θέμα, μέγεθος κειμένου και σχόλια';

  @override
  String get faqsContactAppInfo =>
      'Συχνές ερωτήσεις, επικοινωνήστε μαζί μας και πληροφορίες εφαρμογής';

  @override
  String get viewSubmittedFeedback =>
      'Δείτε τα σχόλια που υποβάλατε και τις απαντήσεις του διαχειριστή';

  @override
  String get discoverSubtitle => 'Ανακαλύψτε τοπικό φαγητό και εμπειρίες';

  @override
  String get searchHintLocalFood =>
      'Αναζήτηση τοπικών επιχειρήσεων τροφίμων...';

  @override
  String get homeLabel => 'Σπίτι';

  @override
  String get recommendedForYou => 'Προτείνεται για εσάς';

  @override
  String get seeAll => 'Δείτε όλα';

  @override
  String get categories => 'Κατηγορίες';

  @override
  String get nearby => 'Κοντά';

  @override
  String get noFoodPlacesFound => 'Δεν βρέθηκαν μέρη για φαγητό';

  @override
  String get noFoodPlacesSubtitle =>
      'Δοκιμάστε να αλλάξετε τις επιλογές αναζήτησης ή φίλτρου.';

  @override
  String get localFoodBusinesses => 'Τοπικές Επιχειρήσεις Τροφίμων';

  @override
  String get localFoodSubtitle =>
      'Υποστηρίξτε τις μικρές και μεσαίες επιχειρήσεις τροφίμων του Μπρίσμπεϊν';

  @override
  String get exploreReviewFoodBusinesses =>
      'Εξερευνήστε και αναθεωρήστε επιχειρήσεις τροφίμων';

  @override
  String get noSavedItemsTitle => 'Δεν υπάρχουν ακόμα αποθηκευμένα στοιχεία';

  @override
  String get noSavedItemsSubtitle =>
      'Πατήστε το εικονίδιο της καρδιάς στις επαγγελματικές κάρτες τροφίμων ή τον σελιδοδείκτη σε ένα επαγγελματικό προφίλ για να τις αποθηκεύσετε εδώ.';

  @override
  String get savedEvents => 'Αποθηκευμένα συμβάντα';

  @override
  String get savedEventsSubtitle =>
      'Οι υπενθυμίσεις και τα σχέδιά σας για εκδηλώσεις';

  @override
  String get savedAttractions => 'Αποθηκευμένα αξιοθέατα';

  @override
  String get savedAttractionsSubtitle =>
      'Μέρη για επίσκεψη ανεξάρτητα από εκδηλώσεις';

  @override
  String get savedBusinesses => 'Αποθηκευμένες Επιχειρήσεις';

  @override
  String get savedBusinessesSubtitle =>
      'Επιχειρήσεις τροφίμων που έχετε προσθέσει σελιδοδείκτη';

  @override
  String get savedItemsUnavailableTitle =>
      'Τα αποθηκευμένα στοιχεία δεν είναι διαθέσιμα';

  @override
  String get savedItemsUnavailableSubtitle =>
      'Ορισμένα αποθηκευμένα στοιχεία δεν δημοσιεύονται πλέον στη ροή εντοπισμού.';

  @override
  String get retryAction => 'Επανάληψη';

  @override
  String get unableToLoadDiscover =>
      'Δεν είναι δυνατή η φόρτωση στοιχείων εντοπισμού αυτήν τη στιγμή. Δοκιμάστε ξανά.';

  @override
  String get unableToLoadSaved =>
      'Δεν είναι δυνατή η φόρτωση αποθηκευμένων στοιχείων αυτήν τη στιγμή. Δοκιμάστε ξανά.';

  @override
  String get dateTBA => 'Ημερομηνία TBA';

  @override
  String get timeTBA => 'Χρόνος TBA';

  @override
  String get untitledEvent => 'Εκδήλωση χωρίς τίτλο';

  @override
  String get locationTBA => 'Τοποθεσία TBA';

  @override
  String get priceTBA => 'Τιμή TBA';

  @override
  String get placeFallback => 'Τόπος';

  @override
  String get foodExperienceFallback => 'Διατροφική Εμπειρία';

  @override
  String get stadiumFallback => 'Γήπεδο';

  @override
  String get eventFallback => 'Εκδήλωση';

  @override
  String get attractionFallback => 'Έλξη';

  @override
  String ratingReviewsCount(String rating, String count) {
    return '$rating · $count κριτικές';
  }

  @override
  String get approved => 'Εγκρίθηκε';

  @override
  String get audience => 'Κοινό';

  @override
  String get businessLabel => 'Επιχειρήσεις';

  @override
  String get controlDistance => 'Ελέγξτε την απόσταση για κοντινές ευκαιρίες';

  @override
  String get dashboard => 'Ταμπλό';

  @override
  String get delete => 'Διαγραφή';

  @override
  String get deleteEvent => 'Διαγραφή συμβάντος';

  @override
  String get deletingEvent => 'Διαγραφή συμβάντος...';

  @override
  String get displayName => 'Εμφανιζόμενο όνομα';

  @override
  String errorDeletingEvent(String error) {
    return 'Σφάλμα κατά τη διαγραφή συμβάντος: $error';
  }

  @override
  String errorLoadingMap(String error) {
    return 'Σφάλμα κατά τη φόρτωση χάρτη: $error';
  }

  @override
  String eventDeleted(String title) {
    return 'Το συμβάν \"$title\" έχει διαγραφεί.';
  }

  @override
  String get failedToDeleteEvent =>
      'Αποτυχία διαγραφής συμβάντος. Δοκιμάστε ξανά.';

  @override
  String get feed => 'Τροφοδοσία';

  @override
  String get localBusinessPortal => 'Τοπική επιχειρηματική πύλη';

  @override
  String get pending => 'Σε εκκρεμότητα';

  @override
  String get phoneNumber => 'Αριθμός τηλεφώνου';

  @override
  String get pleaseLoginLocal => 'Συνδεθείτε πρώτα ως Τοπικός χρήστης.';

  @override
  String get pleaseLoginToDelete =>
      'Παρακαλούμε συνδεθείτε για να διαγράψετε συμβάντα.';

  @override
  String get pushAlerts => 'Push ειδοποιήσεις για την επιχείρησή σας';

  @override
  String get rejected => 'Απορρίφθηκε';

  @override
  String get reviews => 'Κριτικές';

  @override
  String get saveChanges => 'Αποθήκευση αλλαγών';

  @override
  String get searchHintEvents => 'Αναζήτηση εκδηλώσεων, κρατήσεων...';

  @override
  String get suburb => 'Προάστιο';

  @override
  String get thisLinkUnavailable =>
      'Αυτός ο σύνδεσμος δεν είναι διαθέσιμος αυτήν τη στιγμή.';

  @override
  String get total => 'Σύνολο';

  @override
  String get couldNotSaveSettings =>
      'Δεν ήταν δυνατή η αποθήκευση των ρυθμίσεων. Δοκιμάστε ξανά.';

  @override
  String get locationAccessDisabled =>
      'Η πρόσβαση τοποθεσίας απενεργοποιήθηκε για τις λειτουργίες της εφαρμογής.';

  @override
  String get locationPermissionGranted => 'Χορηγήθηκε άδεια τοποθεσίας.';

  @override
  String get openSettings => 'Ανοίξτε τις Ρυθμίσεις';

  @override
  String get themeDark => 'Σκοτεινό';

  @override
  String get themeLight => 'Φως';

  @override
  String get themeSystem => 'Σύστημα';

  @override
  String textScalePercent(String value) {
    return '$value%';
  }

  @override
  String categoryLabel(String category) {
    return 'Κατηγορία: $category';
  }

  @override
  String severityLabel(String severity) {
    return 'Σοβαρότητα: $severity';
  }

  @override
  String get languageEnglish => 'Αγγλικά';

  @override
  String get languageSpanish => 'Ισπανικά';

  @override
  String get languageFrench => 'Γαλλικά';

  @override
  String get languageGerman => 'Γερμανός';

  @override
  String get languageChinese => 'κινέζικα';

  @override
  String get languageArabic => 'αραβικά';

  @override
  String get languageHindi => 'Χίντι';

  @override
  String get languageItalian => 'ιταλική';

  @override
  String get languageJapanese => 'Ιαπωνικά';

  @override
  String get languageKorean => 'κορεάτικα';

  @override
  String get languagePortuguese => 'Πορτογαλικά';

  @override
  String get languageRussian => 'Ρωσική';

  @override
  String get languageVietnamese => 'Βιετναμέζικο';

  @override
  String get languageGreek => 'Έλληνας';

  @override
  String get discoverTitle => 'Ανακαλύψτε το τοπικό φαγητό';

  @override
  String get openSourceLink => 'Σύνδεσμος ανοιχτού κώδικα';

  @override
  String get pendingApproval => 'Έγκριση σε εκκρεμότητα';

  @override
  String deleteEventConfirmation(String title) {
    return 'Είστε βέβαιοι ότι θέλετε να διαγράψετε το \"$title\"; ';
  }

  @override
  String get myActivity => 'Η δραστηριότητά μου';

  @override
  String get businessNotifications => 'Ειδοποιήσεις επιχειρήσεων';

  @override
  String get about => 'Για';

  @override
  String get aboutDescription =>
      'Το BrisConnect+ είναι ένας έξυπνος οδηγός πόλης που βοηθά τους επισκέπτες και τους ντόπιους να ανακαλύψουν εκδηλώσεις, να εξερευνήσουν αξιοθέατα και να αποτυπώσουν τις εμπειρίες τους στο Brisbane σε μια συνδεδεμένη πλατφόρμα.';

  @override
  String versionLabel(String version) {
    return 'Έκδοση $version';
  }

  @override
  String get locationPermissions => 'Δικαιώματα τοποθεσίας';

  @override
  String get enableLocationAccess => 'Ενεργοποίηση Πρόσβασης τοποθεσίας';

  @override
  String get allowNearbyMapFeatures =>
      'Να επιτρέπονται οι κοντινές προτάσεις και οι λειτουργίες που έχουν επίγνωση χάρτη.';

  @override
  String get locationSettings => 'Ρυθμίσεις τοποθεσίας';

  @override
  String get setSearchRadius =>
      'Ορίστε την ακτίνα αναζήτησής σας για εκδηλώσεις και αξιοθέατα.';

  @override
  String get pleaseLoginToViewSettings =>
      'Παρακαλούμε συνδεθείτε για να δείτε τις ρυθμίσεις.';

  @override
  String get locationPermissionNotGranted =>
      'Δεν χορηγήθηκε άδεια τοποθεσίας. Μπορείτε να το ενεργοποιήσετε στις ρυθμίσεις συστήματος.';

  @override
  String get theme => 'Θέμα';

  @override
  String get appTheme => 'Θέμα εφαρμογής';

  @override
  String get chooseHowAppLooks => 'Επιλέξτε πώς φαίνεται η εφαρμογή.';

  @override
  String get textSize => 'Μέγεθος κειμένου';

  @override
  String get adjustTextSize =>
      'Προσαρμόστε το μέγεθος του κειμένου σε όλη την εφαρμογή.';

  @override
  String get smaller => 'Μικρότερος';

  @override
  String get larger => 'Μεγαλύτερος';

  @override
  String get support => 'Υποστήριξη';

  @override
  String get sendAppFeedback => 'Αποστολή σχολίων εφαρμογής';

  @override
  String get reportBugsImprovements =>
      'Αναφέρετε σφάλματα, παραπλανητικές πληροφορίες ή προτάσεις βελτίωσης.';

  @override
  String get noFeedbackYet => 'Δεν έχετε υποβάλει ακόμη σχόλια.';

  @override
  String get adminResponse => 'Απάντηση διαχειριστή';

  @override
  String get awaitingAdminResponse => 'Αναμένεται απάντηση διαχειριστή...';

  @override
  String get statusPending => 'Εκκρεμής';

  @override
  String get statusInProgress => 'Σε εξέλιξη';

  @override
  String get statusResolved => 'Αποφασισμένος';

  @override
  String get statusWontFix => 'Δεν θα διορθωθεί';
}
