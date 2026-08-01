// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Panjabi Punjabi (`pa`).
class AppLocalizationsPa extends AppLocalizations {
  AppLocalizationsPa([String locale = 'pa']) : super(locale);

  @override
  String get appTitle => 'BrisConnect+';

  @override
  String get welcome => 'ਸਵਾਗਤ ਹੈ';

  @override
  String get signIn => 'ਸਾਈਨ ਇਨ';

  @override
  String get signUp => 'ਸਾਈਨ ਅਪ';

  @override
  String get signOut => 'ਸਾਈਨ ਆਊਟ';

  @override
  String get email => 'ਈ-ਮੇਲ';

  @override
  String get password => 'ਪਾਸਵਰਡ';

  @override
  String get phone => 'ਫ਼ੋਨ';

  @override
  String get name => 'ਨਾਮ';

  @override
  String get save => 'ਸੰਭਾਲੋ';

  @override
  String get cancel => 'ਰੱਦ ਕਰੋ';

  @override
  String get editProfile => 'ਪ੍ਰੋਫਾਇਲ ਸੰਪਾਦਿਤ ਕਰੋ';

  @override
  String get profileInfo => 'ਪ੍ਰੋਫਾਇਲ ਜਾਣਕਾਰੀ';

  @override
  String get preferences => 'ਤਰਜੀਹਾਂ';

  @override
  String get language => 'ਭਾਸ਼ਾ';

  @override
  String get locationRadius => 'ਸਥਾਨ ਦੀ ਰੇਡੀਅਸ';

  @override
  String get appearanceSettings => 'ਦਿੱਖ ਸੈਟਿੰਗਜ਼';

  @override
  String get feedback => 'ਪ੍ਰਤੀਕਿਰਿਆ';

  @override
  String get myFeedback => 'ਮੇਰੀ ਪ੍ਰਤੀਕਿਰਿਆ';

  @override
  String get helpAndSupport => 'ਮਦਦ ਅਤੇ ਸਹਾਇਤਾ';

  @override
  String get discover => 'ਖੋਜ';

  @override
  String get community => 'ਸਮਾਜ';

  @override
  String get map => 'ਨਕਸ਼ਾ';

  @override
  String get saved => 'ਸੰਭਾਲਿਆ';

  @override
  String get profile => 'ਪ੍ਰੋਫਾਇਲ';

  @override
  String get food => 'ਖਾਣਾ';

  @override
  String get events => 'ਅਨੁ਷ਠਾਨ';

  @override
  String get businesses => 'ਕਾਰੋਬਾਰ';

  @override
  String get promotions => 'ਪ੍ਰਚਾਰ';

  @override
  String get photos => 'ਫ਼ੋਟੋਆਂ';

  @override
  String get newPost => 'ਨਵਾਂ';

  @override
  String get search => 'ਖੋਜ';

  @override
  String get filter => 'ਫਿਲਟਰ';

  @override
  String get clearFilters => 'ਫਿਲਟਰ ਸਾਫ਼ ਕਰੋ';

  @override
  String get noResults => 'ਕੋਈ ਨਤੀਜਾ ਨਹੀਂ ਮਿਲਿਆ';

  @override
  String get loading => 'ਲੋਡ ਕੀਤਾ ਜਾ ਰਿਹਾ ਹੈ...';

  @override
  String get error => 'ਗਲਤੀ';

  @override
  String get success => 'ਸਫਲ';

  @override
  String get profileUpdated => 'ਪ੍ਰੋਫਾਇਲ ਸਫਲਤਾ ਨਾਲ ਅਪਡੇਟ ਹੋ ਗਈ ਹੈ।';

  @override
  String get profileUpdateFailed =>
      'ਪ੍ਰੋਫਾਇਲ ਅਪਡੇਟ ਨਹੀਂ ਹੋ ਸਕਦੀ। ਦੁਬਾਰਾ ਕੋਸ਼ਿਸ਼ ਕਰਿਓ।';

  @override
  String get guestVisitor => 'ਮਹਿਮਾਨ ਮੁਲਾਕਾਤੀ';

  @override
  String get localUser => 'ਸਥਾਨਕ';

  @override
  String get filterEventsTitle => 'ਅਨੁ਷ਠਾਨ ਫਿਲਟਰ ਕਰੋ';

  @override
  String get priceLabel => 'ਮੁੱਲ';

  @override
  String get dateLabel => 'ਮਿਤੀ';

  @override
  String get pickADate => 'ਇੱਕ ਮਿਤੀ ਚੁਣੋ';

  @override
  String get resetButton => 'ਮੁੜ ਨਿਰਧਾਰਤ ਕਰੋ';

  @override
  String get applyButton => 'ਲਾਗੂ ਕਰੋ';

  @override
  String get freeLabel => 'ਮੁਫ਼ਤ';

  @override
  String get paidLabel => 'ਅਦਾ ਕੀਤਾ';

  @override
  String eventSavedToInterested(String eventTitle) {
    return '$eventTitle saved to Interested.';
  }

  @override
  String eventRemovedFromInterested(String eventTitle) {
    return '$eventTitle removed from Interested.';
  }

  @override
  String savedToAttractions(String title) {
    return '$title saved to Saved Attractions.';
  }

  @override
  String removedFromAttractions(String title) {
    return '$title removed from Saved Attractions.';
  }

  @override
  String get pleaseSignInToSaveEvents =>
      'Please log in as a Visitor to save events.';

  @override
  String get pleaseSignInToReview =>
      'Please sign in to write a review or BuzzVote.';

  @override
  String reviewSubmitted(String rating, String buzzRating) {
    return 'Review submitted\\! ⭐ $rating / Buzz ⚡ $buzzRating';
  }

  @override
  String reviewSubmitFailed(String error) {
    return 'Could not submit review: $error';
  }

  @override
  String get noExternalLink => 'No external link available for this item yet.';

  @override
  String get unableToOpenLink => 'Unable to open the event link right now.';

  @override
  String shareTitle(String title) {
    return 'Share: $title';
  }

  @override
  String get reportEvent => 'Report Event';

  @override
  String get reviewsOnlyForFood => 'Reviews are only available for food items';

  @override
  String get chooseFromGallery => 'Choose from gallery';

  @override
  String get takeAPhoto => 'Take a photo';

  @override
  String get pleaseLoginVisitor => 'Please log in as a Visitor first.';

  @override
  String get onlyJpgPng => 'Only JPG and PNG images are supported.';

  @override
  String get imageTooLarge =>
      'Image is too large. Please choose a smaller image.';

  @override
  String get profilePictureUpdated => 'Profile picture updated successfully.';

  @override
  String get profilePictureUpdateFailed =>
      'Could not update profile picture. Please try again.';

  @override
  String get enterYourName => 'ਆਪਣਾ ਨਾਮ ਦਰਜ ਕਰੋ';

  @override
  String get phoneHint => 'e.g. 04xxxxxxxx';

  @override
  String get nameCannotBeEmpty => 'Name cannot be empty.';

  @override
  String get nameMinLength => 'Name must be at least 2 characters.';

  @override
  String get enterValidPhone => 'Enter a valid phone number.';

  @override
  String get changeProfilePicture => 'Change profile picture';

  @override
  String get uploadProfilePicture => 'Upload profile picture';

  @override
  String get areYouSureSignOut => 'Are you sure you want to sign out?';

  @override
  String get returnWelcome => 'Return to the welcome screen';

  @override
  String get setHowFarRecommendations => 'Set how far recommendations can be';

  @override
  String get themeTextSizeFeedback => 'Theme, text size & feedback';

  @override
  String get faqsContactAppInfo => 'FAQs, contact us & app info';

  @override
  String get viewSubmittedFeedback =>
      'View your submitted feedback and admin responses';

  @override
  String get discoverSubtitle => 'Discover local food and experiences';

  @override
  String get searchHintLocalFood => 'Search local food businesses...';

  @override
  String get homeLabel => 'ਘਰ';

  @override
  String get recommendedForYou => 'Recommended For You';

  @override
  String get seeAll => 'See All';

  @override
  String get categories => 'Categories';

  @override
  String get nearby => 'ਨੇੜੇ';

  @override
  String get noFoodPlacesFound => 'No food places found';

  @override
  String get noFoodPlacesSubtitle =>
      'Try changing your search or filter selections.';

  @override
  String get localFoodBusinesses => 'Local Food Businesses';

  @override
  String get localFoodSubtitle =>
      'Support small & medium Brisbane food enterprises';

  @override
  String get exploreReviewFoodBusinesses => 'Explore & Review Food Businesses';

  @override
  String get noSavedItemsTitle => 'No saved items yet';

  @override
  String get noSavedItemsSubtitle =>
      'Tap the heart icon on food business cards or the bookmark on a business profile to save them here.';

  @override
  String get savedEvents => 'Saved Events';

  @override
  String get savedEventsSubtitle => 'Your event reminders and plans';

  @override
  String get savedAttractions => 'Saved Attractions';

  @override
  String get savedAttractionsSubtitle =>
      'Places to visit independently of events';

  @override
  String get savedBusinesses => 'Saved Businesses';

  @override
  String get savedBusinessesSubtitle => 'Food businesses you have bookmarked';

  @override
  String get savedItemsUnavailableTitle => 'Saved items unavailable';

  @override
  String get savedItemsUnavailableSubtitle =>
      'Some saved items are no longer published in discovery feed.';

  @override
  String get retryAction => 'ਮੁੜ ਕੋਸ਼ਿਸ਼ ਕਰੋ';

  @override
  String get unableToLoadDiscover =>
      'Unable to load discover items right now. Please try again.';

  @override
  String get unableToLoadSaved =>
      'Unable to load saved items right now. Please try again.';

  @override
  String get dateTBA => 'Date TBA';

  @override
  String get timeTBA => 'Time TBA';

  @override
  String get untitledEvent => 'Untitled Event';

  @override
  String get locationTBA => 'Location TBA';

  @override
  String get priceTBA => 'Price TBA';

  @override
  String get placeFallback => 'Place';

  @override
  String get foodExperienceFallback => 'Food Experience';

  @override
  String get stadiumFallback => 'Stadium';

  @override
  String get eventFallback => 'Event';

  @override
  String get attractionFallback => 'Attraction';

  @override
  String ratingReviewsCount(String rating, String count) {
    return '$rating · $count reviews';
  }

  @override
  String get approved => 'ਮਨਜ਼ੂਰ';

  @override
  String get audience => 'ਦਰਸ਼ਕ';

  @override
  String get businessLabel => 'Business';

  @override
  String get controlDistance => 'Control distance for nearby opportunities';

  @override
  String get dashboard => 'ਡੈਸ਼ਬੋਰਡ';

  @override
  String get delete => 'ਮਿਟਾਓ';

  @override
  String get deleteEvent => 'Delete Event';

  @override
  String get deletingEvent => 'Deleting event...';

  @override
  String get displayName => 'Display name';

  @override
  String errorDeletingEvent(String error) {
    return 'Error deleting event: $error';
  }

  @override
  String errorLoadingMap(String error) {
    return 'Error loading map: $error';
  }

  @override
  String eventDeleted(String title) {
    return 'Event \"$title\" has been deleted.';
  }

  @override
  String get failedToDeleteEvent => 'Failed to delete event. Please try again.';

  @override
  String get feed => 'Feed';

  @override
  String get localBusinessPortal => 'Local business portal';

  @override
  String get pending => 'ਬਕਾਇਾ';

  @override
  String get phoneNumber => 'ਫ਼ੋਨ ਨੰਬਰ';

  @override
  String get pleaseLoginLocal => 'Please log in as a Local user first.';

  @override
  String get pleaseLoginToDelete => 'Please log in to delete events.';

  @override
  String get pushAlerts => 'Push alerts for your business';

  @override
  String get rejected => 'ਅਸਵੀਕਾਰ';

  @override
  String get reviews => 'ਸਮੀਖਿਆਵਾਂ';

  @override
  String get saveChanges => 'Save Changes';

  @override
  String get searchHintEvents => 'Search events, bookings...';

  @override
  String get suburb => 'Suburb';

  @override
  String get thisLinkUnavailable => 'This link is not available right now.';

  @override
  String get total => 'Total';

  @override
  String get couldNotSaveSettings =>
      'Could not save settings. Please try again.';

  @override
  String get locationAccessDisabled =>
      'Location access disabled for app features.';

  @override
  String get locationPermissionGranted => 'Location permission granted.';

  @override
  String get openSettings => 'Open Settings';

  @override
  String get themeDark => 'ਹਨੇਰਾ';

  @override
  String get themeLight => 'ਹਲਕਾ';

  @override
  String get themeSystem => 'ਸਿਸਟਮ';

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
  String get languageEnglish => 'ਅੰਗਰੇਜ਼ੀ';

  @override
  String get languageSpanish => 'ਸਪੇਨੀ';

  @override
  String get languageFrench => 'ਫਰਾਂਸੀਸੀ';

  @override
  String get languageGerman => 'ਜਰਮਨ';

  @override
  String get languageChinese => 'ਚੀਨੀ';

  @override
  String get languageArabic => 'ਅਰਬੀ';

  @override
  String get languageHindi => 'ਹਿੰਦੀ';

  @override
  String get languageItalian => 'ਇਤਾਲਵੀ';

  @override
  String get languageJapanese => 'ਜਾਪਾਨੀ';

  @override
  String get languageKorean => 'ਕੋਰੀਆਈ';

  @override
  String get languagePortuguese => 'ਪੁਰਤਗਾਲੀ';

  @override
  String get languageRussian => 'ਰੂਸੀ';

  @override
  String get languageVietnamese => 'ਵੀਅਤਨਾਮੀ';

  @override
  String get languageGreek => 'ਗ੍ਰੀਕ';

  @override
  String get languagePunjabi => 'ਪੰਜਾਬੀ';

  @override
  String get discoverTitle => 'ਸਥਾਨਕ ਖਾਣਾ ਖੋਜੋ';

  @override
  String get openSourceLink => 'Open Source Link';

  @override
  String get pendingApproval => 'Pending Approval';

  @override
  String deleteEventConfirmation(String title) {
    return 'Are you sure you want to delete \"$title\"? This action cannot be undone.';
  }

  @override
  String get myActivity => 'My Activity';

  @override
  String get businessNotifications => 'Business Notifications';

  @override
  String get about => 'ਬਾਰੇ';

  @override
  String get aboutDescription =>
      'BrisConnect+ is a smart city guide that helps visitors and locals discover events, explore attractions, and capture their Brisbane experiences in one connected platform.';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get locationPermissions => 'Location Permissions';

  @override
  String get enableLocationAccess => 'Enable Location Access';

  @override
  String get allowNearbyMapFeatures =>
      'Allow nearby recommendations and map-aware features.';

  @override
  String get locationSettings => 'Location Settings';

  @override
  String get setSearchRadius =>
      'Set your search radius for events and attractions.';

  @override
  String get pleaseLoginToViewSettings => 'Please log in to view settings.';

  @override
  String get locationPermissionNotGranted =>
      'Location permission was not granted. You can enable it in system settings.';

  @override
  String get theme => 'ਥੀਮ';

  @override
  String get appTheme => 'App Theme';

  @override
  String get chooseHowAppLooks => 'Choose how the app looks.';

  @override
  String get textSize => 'Text Size';

  @override
  String get adjustTextSize => 'Adjust text size across the app.';

  @override
  String get smaller => 'Smaller';

  @override
  String get larger => 'Larger';

  @override
  String get support => 'ਸਹਾਇਤਾ';

  @override
  String get sendAppFeedback => 'Send App Feedback';

  @override
  String get reportBugsImprovements =>
      'Report bugs, misleading information, or improvement suggestions.';

  @override
  String get noFeedbackYet => 'You have not submitted any feedback yet.';

  @override
  String get adminResponse => 'Admin Response';

  @override
  String get awaitingAdminResponse => 'Awaiting admin response...';

  @override
  String get statusPending => 'ਬਕਾਇਾ';

  @override
  String get statusInProgress => 'In Progress';

  @override
  String get statusResolved => 'Resolved';

  @override
  String get statusWontFix => 'Won\'t Fix';

  @override
  String get foodBusinessDetails => 'Business Details';

  @override
  String get aboutThisFoodExperience => 'About this Food Experience';

  @override
  String get highlights => 'Highlights';

  @override
  String get contactAndLinks => 'Contact & Links';

  @override
  String get gallery => 'ਗੈਲਰੀ';

  @override
  String get openingHours => 'ਖੁੱਲ੍ਹਣ ਦੇ ਸਮੇਂ';

  @override
  String get menu => 'ਮੇਨੂ';

  @override
  String get menuFallback => 'ਮੇਨੂ';

  @override
  String get call => 'ਕਾਲ ਕਰੋ';

  @override
  String get website => 'ਵੈੱਬਸਾਈਟ';

  @override
  String get orderOnline => 'Order Online';

  @override
  String get viewOnMap => 'View on Map';

  @override
  String get foodDiscoveryGuide => 'ਖਾਣੇ ਦੀ ਖੋਜ ਗਾਈਡ';

  @override
  String get foodDiscoveryGuideHelper =>
      'Tap play to hear your Food Discovery Guide describe this food spot and its highlights.';

  @override
  String get stop => 'Stop';

  @override
  String get unableToStartNarration =>
      'Unable to start Food Discovery Guide narration right now.';

  @override
  String get unableToCallNumber => 'Unable to call this number right now.';

  @override
  String get unableToSendEmail => 'Unable to send email right now.';

  @override
  String get foodSpotCannotBeShared =>
      'This food spot cannot be shared right now.';

  @override
  String foodDescriptionIntro(String title, String cuisine, String location) {
    return 'Step into $title, a $cuisine destination in the heart of $location.';
  }

  @override
  String foodDescriptionRating(String rating) {
    return 'Loved by locals and visitors alike, it holds a $rating-star rating.';
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
    return 'Whether you are after a relaxed brunch, a business lunch, or a lively dinner, $title offers a welcoming atmosphere and flavours that capture Brisbane\'s dining scene.';
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
