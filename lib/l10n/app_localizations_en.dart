// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'BrisConnect+';

  @override
  String get welcome => 'Welcome';

  @override
  String get signIn => 'Sign In';

  @override
  String get signUp => 'Sign Up';

  @override
  String get signOut => 'Sign Out';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get phone => 'Phone';

  @override
  String get name => 'Name';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get editProfile => 'Edit Profile';

  @override
  String get profileInfo => 'Profile Info';

  @override
  String get preferences => 'Preferences';

  @override
  String get language => 'Language';

  @override
  String get locationRadius => 'Location Radius';

  @override
  String get appearanceSettings => 'Appearance Settings';

  @override
  String get feedback => 'Feedback';

  @override
  String get myFeedback => 'My Feedback';

  @override
  String get helpAndSupport => 'Help & Support';

  @override
  String get discover => 'Discover';

  @override
  String get community => 'Community';

  @override
  String get map => 'Map';

  @override
  String get saved => 'Saved';

  @override
  String get profile => 'Profile';

  @override
  String get food => 'Food';

  @override
  String get events => 'Events';

  @override
  String get businesses => 'Businesses';

  @override
  String get promotions => 'Promotions';

  @override
  String get photos => 'Photos';

  @override
  String get newPost => 'New';

  @override
  String get search => 'Search';

  @override
  String get filter => 'Filter';

  @override
  String get clearFilters => 'Clear filters';

  @override
  String get noResults => 'No results found';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get success => 'Success';

  @override
  String get profileUpdated => 'Profile updated successfully.';

  @override
  String get profileUpdateFailed =>
      'Could not update profile. Please try again.';

  @override
  String get guestVisitor => 'Guest Visitor';

  @override
  String get localUser => 'Local';

  @override
  String get filterEventsTitle => 'Filter Events';

  @override
  String get priceLabel => 'Price';

  @override
  String get dateLabel => 'Date';

  @override
  String get pickADate => 'Pick a date';

  @override
  String get resetButton => 'Reset';

  @override
  String get applyButton => 'Apply';

  @override
  String get freeLabel => 'Free';

  @override
  String get paidLabel => 'Paid';

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
  String get enterYourName => 'Enter your name';

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
  String get homeLabel => 'Home';

  @override
  String get recommendedForYou => 'Recommended For You';

  @override
  String get seeAll => 'See All';

  @override
  String get categories => 'Categories';

  @override
  String get nearby => 'Nearby';

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
  String get retryAction => 'Retry';

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
  String get approved => 'Approved';

  @override
  String get audience => 'Audience';

  @override
  String get businessLabel => 'Business';

  @override
  String get controlDistance => 'Control distance for nearby opportunities';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get delete => 'Delete';

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
  String get pending => 'Pending';

  @override
  String get phoneNumber => 'Phone number';

  @override
  String get pleaseLoginLocal => 'Please log in as a Local user first.';

  @override
  String get pleaseLoginToDelete => 'Please log in to delete events.';

  @override
  String get pushAlerts => 'Push alerts for your business';

  @override
  String get rejected => 'Rejected';

  @override
  String get reviews => 'Reviews';

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
  String get themeDark => 'Dark';

  @override
  String get themeLight => 'Light';

  @override
  String get themeSystem => 'System';

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
  String get languageEnglish => 'English';

  @override
  String get languageSpanish => 'Spanish';

  @override
  String get languageFrench => 'French';

  @override
  String get languageGerman => 'German';

  @override
  String get languageChinese => 'Chinese';

  @override
  String get languageArabic => 'Arabic';

  @override
  String get languageHindi => 'Hindi';

  @override
  String get languageItalian => 'Italian';

  @override
  String get languageJapanese => 'Japanese';

  @override
  String get languageKorean => 'Korean';

  @override
  String get languagePortuguese => 'Portuguese';

  @override
  String get languageRussian => 'Russian';

  @override
  String get languageVietnamese => 'Vietnamese';

  @override
  String get languageGreek => 'Greek';

  @override
  String get discoverTitle => 'Discover Local Food';

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
  String get about => 'About';

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
  String get theme => 'Theme';

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
  String get support => 'Support';

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
  String get statusPending => 'Pending';

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
  String get gallery => 'Gallery';

  @override
  String get openingHours => 'Opening Hours';

  @override
  String get menu => 'Menu';

  @override
  String get menuFallback => 'Menu';

  @override
  String get call => 'Call';

  @override
  String get website => 'Website';

  @override
  String get orderOnline => 'Order Online';

  @override
  String get viewOnMap => 'View on Map';

  @override
  String get foodDiscoveryGuide => 'Food Discovery Guide';

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
