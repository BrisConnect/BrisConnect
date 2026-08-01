import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_el.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_pa.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ru.dart';
import 'app_localizations_vi.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('el'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('hi'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('pa'),
    Locale('pt'),
    Locale('ru'),
    Locale('vi'),
    Locale('zh')
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'BrisConnect+'**
  String get appTitle;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @profileInfo.
  ///
  /// In en, this message translates to:
  /// **'Profile Info'**
  String get profileInfo;

  /// No description provided for @preferences.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferences;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @locationRadius.
  ///
  /// In en, this message translates to:
  /// **'Location Radius'**
  String get locationRadius;

  /// No description provided for @appearanceSettings.
  ///
  /// In en, this message translates to:
  /// **'Appearance Settings'**
  String get appearanceSettings;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// No description provided for @myFeedback.
  ///
  /// In en, this message translates to:
  /// **'My Feedback'**
  String get myFeedback;

  /// No description provided for @helpAndSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpAndSupport;

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @community.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get community;

  /// No description provided for @map.
  ///
  /// In en, this message translates to:
  /// **'Map'**
  String get map;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @food.
  ///
  /// In en, this message translates to:
  /// **'Food'**
  String get food;

  /// No description provided for @events.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get events;

  /// No description provided for @businesses.
  ///
  /// In en, this message translates to:
  /// **'Businesses'**
  String get businesses;

  /// No description provided for @promotions.
  ///
  /// In en, this message translates to:
  /// **'Promotions'**
  String get promotions;

  /// No description provided for @photos.
  ///
  /// In en, this message translates to:
  /// **'Photos'**
  String get photos;

  /// No description provided for @newPost.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newPost;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @clearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get clearFilters;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully.'**
  String get profileUpdated;

  /// No description provided for @profileUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update profile. Please try again.'**
  String get profileUpdateFailed;

  /// No description provided for @guestVisitor.
  ///
  /// In en, this message translates to:
  /// **'Guest Visitor'**
  String get guestVisitor;

  /// No description provided for @localUser.
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get localUser;

  /// No description provided for @filterEventsTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter Events'**
  String get filterEventsTitle;

  /// No description provided for @priceLabel.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get priceLabel;

  /// No description provided for @dateLabel.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get dateLabel;

  /// No description provided for @pickADate.
  ///
  /// In en, this message translates to:
  /// **'Pick a date'**
  String get pickADate;

  /// No description provided for @resetButton.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetButton;

  /// No description provided for @applyButton.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyButton;

  /// No description provided for @freeLabel.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get freeLabel;

  /// No description provided for @paidLabel.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get paidLabel;

  /// No description provided for @eventSavedToInterested.
  ///
  /// In en, this message translates to:
  /// **'{eventTitle} saved to Interested.'**
  String eventSavedToInterested(String eventTitle);

  /// No description provided for @eventRemovedFromInterested.
  ///
  /// In en, this message translates to:
  /// **'{eventTitle} removed from Interested.'**
  String eventRemovedFromInterested(String eventTitle);

  /// No description provided for @savedToAttractions.
  ///
  /// In en, this message translates to:
  /// **'{title} saved to Saved Attractions.'**
  String savedToAttractions(String title);

  /// No description provided for @removedFromAttractions.
  ///
  /// In en, this message translates to:
  /// **'{title} removed from Saved Attractions.'**
  String removedFromAttractions(String title);

  /// No description provided for @pleaseSignInToSaveEvents.
  ///
  /// In en, this message translates to:
  /// **'Please log in as a Visitor to save events.'**
  String get pleaseSignInToSaveEvents;

  /// No description provided for @pleaseSignInToReview.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to write a review or BuzzVote.'**
  String get pleaseSignInToReview;

  /// No description provided for @reviewSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Review submitted\\! ⭐ {rating} / Buzz ⚡ {buzzRating}'**
  String reviewSubmitted(String rating, String buzzRating);

  /// No description provided for @reviewSubmitFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not submit review: {error}'**
  String reviewSubmitFailed(String error);

  /// No description provided for @noExternalLink.
  ///
  /// In en, this message translates to:
  /// **'No external link available for this item yet.'**
  String get noExternalLink;

  /// No description provided for @unableToOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Unable to open the event link right now.'**
  String get unableToOpenLink;

  /// No description provided for @shareTitle.
  ///
  /// In en, this message translates to:
  /// **'Share: {title}'**
  String shareTitle(String title);

  /// No description provided for @reportEvent.
  ///
  /// In en, this message translates to:
  /// **'Report Event'**
  String get reportEvent;

  /// No description provided for @reviewsOnlyForFood.
  ///
  /// In en, this message translates to:
  /// **'Reviews are only available for food items'**
  String get reviewsOnlyForFood;

  /// No description provided for @chooseFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get chooseFromGallery;

  /// No description provided for @takeAPhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get takeAPhoto;

  /// No description provided for @pleaseLoginVisitor.
  ///
  /// In en, this message translates to:
  /// **'Please log in as a Visitor first.'**
  String get pleaseLoginVisitor;

  /// No description provided for @onlyJpgPng.
  ///
  /// In en, this message translates to:
  /// **'Only JPG and PNG images are supported.'**
  String get onlyJpgPng;

  /// No description provided for @imageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'Image is too large. Please choose a smaller image.'**
  String get imageTooLarge;

  /// No description provided for @profilePictureUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile picture updated successfully.'**
  String get profilePictureUpdated;

  /// No description provided for @profilePictureUpdateFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not update profile picture. Please try again.'**
  String get profilePictureUpdateFailed;

  /// No description provided for @enterYourName.
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enterYourName;

  /// No description provided for @phoneHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 04xxxxxxxx'**
  String get phoneHint;

  /// No description provided for @nameCannotBeEmpty.
  ///
  /// In en, this message translates to:
  /// **'Name cannot be empty.'**
  String get nameCannotBeEmpty;

  /// No description provided for @nameMinLength.
  ///
  /// In en, this message translates to:
  /// **'Name must be at least 2 characters.'**
  String get nameMinLength;

  /// No description provided for @enterValidPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid phone number.'**
  String get enterValidPhone;

  /// No description provided for @changeProfilePicture.
  ///
  /// In en, this message translates to:
  /// **'Change profile picture'**
  String get changeProfilePicture;

  /// No description provided for @uploadProfilePicture.
  ///
  /// In en, this message translates to:
  /// **'Upload profile picture'**
  String get uploadProfilePicture;

  /// No description provided for @areYouSureSignOut.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get areYouSureSignOut;

  /// No description provided for @returnWelcome.
  ///
  /// In en, this message translates to:
  /// **'Return to the welcome screen'**
  String get returnWelcome;

  /// No description provided for @setHowFarRecommendations.
  ///
  /// In en, this message translates to:
  /// **'Set how far recommendations can be'**
  String get setHowFarRecommendations;

  /// No description provided for @themeTextSizeFeedback.
  ///
  /// In en, this message translates to:
  /// **'Theme, text size & feedback'**
  String get themeTextSizeFeedback;

  /// No description provided for @faqsContactAppInfo.
  ///
  /// In en, this message translates to:
  /// **'FAQs, contact us & app info'**
  String get faqsContactAppInfo;

  /// No description provided for @viewSubmittedFeedback.
  ///
  /// In en, this message translates to:
  /// **'View your submitted feedback and admin responses'**
  String get viewSubmittedFeedback;

  /// No description provided for @discoverSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Discover local food and experiences'**
  String get discoverSubtitle;

  /// No description provided for @searchHintLocalFood.
  ///
  /// In en, this message translates to:
  /// **'Search local food businesses...'**
  String get searchHintLocalFood;

  /// No description provided for @homeLabel.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get homeLabel;

  /// No description provided for @recommendedForYou.
  ///
  /// In en, this message translates to:
  /// **'Recommended For You'**
  String get recommendedForYou;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get seeAll;

  /// No description provided for @categories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get categories;

  /// No description provided for @nearby.
  ///
  /// In en, this message translates to:
  /// **'Nearby'**
  String get nearby;

  /// No description provided for @noFoodPlacesFound.
  ///
  /// In en, this message translates to:
  /// **'No food places found'**
  String get noFoodPlacesFound;

  /// No description provided for @noFoodPlacesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try changing your search or filter selections.'**
  String get noFoodPlacesSubtitle;

  /// No description provided for @localFoodBusinesses.
  ///
  /// In en, this message translates to:
  /// **'Local Food Businesses'**
  String get localFoodBusinesses;

  /// No description provided for @localFoodSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Support small & medium Brisbane food enterprises'**
  String get localFoodSubtitle;

  /// No description provided for @exploreReviewFoodBusinesses.
  ///
  /// In en, this message translates to:
  /// **'Explore & Review Food Businesses'**
  String get exploreReviewFoodBusinesses;

  /// No description provided for @noSavedItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'No saved items yet'**
  String get noSavedItemsTitle;

  /// No description provided for @noSavedItemsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tap the heart icon on food business cards or the bookmark on a business profile to save them here.'**
  String get noSavedItemsSubtitle;

  /// No description provided for @savedEvents.
  ///
  /// In en, this message translates to:
  /// **'Saved Events'**
  String get savedEvents;

  /// No description provided for @savedEventsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your event reminders and plans'**
  String get savedEventsSubtitle;

  /// No description provided for @savedAttractions.
  ///
  /// In en, this message translates to:
  /// **'Saved Attractions'**
  String get savedAttractions;

  /// No description provided for @savedAttractionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Places to visit independently of events'**
  String get savedAttractionsSubtitle;

  /// No description provided for @savedBusinesses.
  ///
  /// In en, this message translates to:
  /// **'Saved Businesses'**
  String get savedBusinesses;

  /// No description provided for @savedBusinessesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Food businesses you have bookmarked'**
  String get savedBusinessesSubtitle;

  /// No description provided for @savedItemsUnavailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Saved items unavailable'**
  String get savedItemsUnavailableTitle;

  /// No description provided for @savedItemsUnavailableSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Some saved items are no longer published in discovery feed.'**
  String get savedItemsUnavailableSubtitle;

  /// No description provided for @retryAction.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retryAction;

  /// No description provided for @unableToLoadDiscover.
  ///
  /// In en, this message translates to:
  /// **'Unable to load discover items right now. Please try again.'**
  String get unableToLoadDiscover;

  /// No description provided for @unableToLoadSaved.
  ///
  /// In en, this message translates to:
  /// **'Unable to load saved items right now. Please try again.'**
  String get unableToLoadSaved;

  /// No description provided for @dateTBA.
  ///
  /// In en, this message translates to:
  /// **'Date TBA'**
  String get dateTBA;

  /// No description provided for @timeTBA.
  ///
  /// In en, this message translates to:
  /// **'Time TBA'**
  String get timeTBA;

  /// No description provided for @untitledEvent.
  ///
  /// In en, this message translates to:
  /// **'Untitled Event'**
  String get untitledEvent;

  /// No description provided for @locationTBA.
  ///
  /// In en, this message translates to:
  /// **'Location TBA'**
  String get locationTBA;

  /// No description provided for @priceTBA.
  ///
  /// In en, this message translates to:
  /// **'Price TBA'**
  String get priceTBA;

  /// No description provided for @placeFallback.
  ///
  /// In en, this message translates to:
  /// **'Place'**
  String get placeFallback;

  /// No description provided for @foodExperienceFallback.
  ///
  /// In en, this message translates to:
  /// **'Food Experience'**
  String get foodExperienceFallback;

  /// No description provided for @stadiumFallback.
  ///
  /// In en, this message translates to:
  /// **'Stadium'**
  String get stadiumFallback;

  /// No description provided for @eventFallback.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get eventFallback;

  /// No description provided for @attractionFallback.
  ///
  /// In en, this message translates to:
  /// **'Attraction'**
  String get attractionFallback;

  /// No description provided for @ratingReviewsCount.
  ///
  /// In en, this message translates to:
  /// **'{rating} · {count} reviews'**
  String ratingReviewsCount(String rating, String count);

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @audience.
  ///
  /// In en, this message translates to:
  /// **'Audience'**
  String get audience;

  /// No description provided for @businessLabel.
  ///
  /// In en, this message translates to:
  /// **'Business'**
  String get businessLabel;

  /// No description provided for @controlDistance.
  ///
  /// In en, this message translates to:
  /// **'Control distance for nearby opportunities'**
  String get controlDistance;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteEvent.
  ///
  /// In en, this message translates to:
  /// **'Delete Event'**
  String get deleteEvent;

  /// No description provided for @deletingEvent.
  ///
  /// In en, this message translates to:
  /// **'Deleting event...'**
  String get deletingEvent;

  /// No description provided for @displayName.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayName;

  /// No description provided for @errorDeletingEvent.
  ///
  /// In en, this message translates to:
  /// **'Error deleting event: {error}'**
  String errorDeletingEvent(String error);

  /// No description provided for @errorLoadingMap.
  ///
  /// In en, this message translates to:
  /// **'Error loading map: {error}'**
  String errorLoadingMap(String error);

  /// No description provided for @eventDeleted.
  ///
  /// In en, this message translates to:
  /// **'Event \"{title}\" has been deleted.'**
  String eventDeleted(String title);

  /// No description provided for @failedToDeleteEvent.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete event. Please try again.'**
  String get failedToDeleteEvent;

  /// No description provided for @feed.
  ///
  /// In en, this message translates to:
  /// **'Feed'**
  String get feed;

  /// No description provided for @localBusinessPortal.
  ///
  /// In en, this message translates to:
  /// **'Local business portal'**
  String get localBusinessPortal;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone number'**
  String get phoneNumber;

  /// No description provided for @pleaseLoginLocal.
  ///
  /// In en, this message translates to:
  /// **'Please log in as a Local user first.'**
  String get pleaseLoginLocal;

  /// No description provided for @pleaseLoginToDelete.
  ///
  /// In en, this message translates to:
  /// **'Please log in to delete events.'**
  String get pleaseLoginToDelete;

  /// No description provided for @pushAlerts.
  ///
  /// In en, this message translates to:
  /// **'Push alerts for your business'**
  String get pushAlerts;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save Changes'**
  String get saveChanges;

  /// No description provided for @searchHintEvents.
  ///
  /// In en, this message translates to:
  /// **'Search events, bookings...'**
  String get searchHintEvents;

  /// No description provided for @suburb.
  ///
  /// In en, this message translates to:
  /// **'Suburb'**
  String get suburb;

  /// No description provided for @thisLinkUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This link is not available right now.'**
  String get thisLinkUnavailable;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @couldNotSaveSettings.
  ///
  /// In en, this message translates to:
  /// **'Could not save settings. Please try again.'**
  String get couldNotSaveSettings;

  /// No description provided for @locationAccessDisabled.
  ///
  /// In en, this message translates to:
  /// **'Location access disabled for app features.'**
  String get locationAccessDisabled;

  /// No description provided for @locationPermissionGranted.
  ///
  /// In en, this message translates to:
  /// **'Location permission granted.'**
  String get locationPermissionGranted;

  /// No description provided for @openSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get openSettings;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @textScalePercent.
  ///
  /// In en, this message translates to:
  /// **'{value}%'**
  String textScalePercent(String value);

  /// No description provided for @categoryLabel.
  ///
  /// In en, this message translates to:
  /// **'Category: {category}'**
  String categoryLabel(String category);

  /// No description provided for @severityLabel.
  ///
  /// In en, this message translates to:
  /// **'Severity: {severity}'**
  String severityLabel(String severity);

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageSpanish.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageSpanish;

  /// No description provided for @languageFrench.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageFrench;

  /// No description provided for @languageGerman.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageGerman;

  /// No description provided for @languageChinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get languageChinese;

  /// No description provided for @languageArabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get languageArabic;

  /// No description provided for @languageHindi.
  ///
  /// In en, this message translates to:
  /// **'Hindi'**
  String get languageHindi;

  /// No description provided for @languageItalian.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get languageItalian;

  /// No description provided for @languageJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get languageJapanese;

  /// No description provided for @languageKorean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get languageKorean;

  /// No description provided for @languagePortuguese.
  ///
  /// In en, this message translates to:
  /// **'Portuguese'**
  String get languagePortuguese;

  /// No description provided for @languageRussian.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageRussian;

  /// No description provided for @languageVietnamese.
  ///
  /// In en, this message translates to:
  /// **'Vietnamese'**
  String get languageVietnamese;

  /// No description provided for @languageGreek.
  ///
  /// In en, this message translates to:
  /// **'Greek'**
  String get languageGreek;

  /// No description provided for @languagePunjabi.
  ///
  /// In en, this message translates to:
  /// **'Punjabi'**
  String get languagePunjabi;

  /// No description provided for @discoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Discover Local Food'**
  String get discoverTitle;

  /// No description provided for @openSourceLink.
  ///
  /// In en, this message translates to:
  /// **'Open Source Link'**
  String get openSourceLink;

  /// No description provided for @pendingApproval.
  ///
  /// In en, this message translates to:
  /// **'Pending Approval'**
  String get pendingApproval;

  /// No description provided for @deleteEventConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete \"{title}\"? This action cannot be undone.'**
  String deleteEventConfirmation(String title);

  /// No description provided for @myActivity.
  ///
  /// In en, this message translates to:
  /// **'My Activity'**
  String get myActivity;

  /// No description provided for @businessNotifications.
  ///
  /// In en, this message translates to:
  /// **'Business Notifications'**
  String get businessNotifications;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'BrisConnect+ is a smart city guide that helps visitors and locals discover events, explore attractions, and capture their Brisbane experiences in one connected platform.'**
  String get aboutDescription;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(String version);

  /// No description provided for @locationPermissions.
  ///
  /// In en, this message translates to:
  /// **'Location Permissions'**
  String get locationPermissions;

  /// No description provided for @enableLocationAccess.
  ///
  /// In en, this message translates to:
  /// **'Enable Location Access'**
  String get enableLocationAccess;

  /// No description provided for @allowNearbyMapFeatures.
  ///
  /// In en, this message translates to:
  /// **'Allow nearby recommendations and map-aware features.'**
  String get allowNearbyMapFeatures;

  /// No description provided for @locationSettings.
  ///
  /// In en, this message translates to:
  /// **'Location Settings'**
  String get locationSettings;

  /// No description provided for @setSearchRadius.
  ///
  /// In en, this message translates to:
  /// **'Set your search radius for events and attractions.'**
  String get setSearchRadius;

  /// No description provided for @pleaseLoginToViewSettings.
  ///
  /// In en, this message translates to:
  /// **'Please log in to view settings.'**
  String get pleaseLoginToViewSettings;

  /// No description provided for @locationPermissionNotGranted.
  ///
  /// In en, this message translates to:
  /// **'Location permission was not granted. You can enable it in system settings.'**
  String get locationPermissionNotGranted;

  /// No description provided for @theme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// No description provided for @appTheme.
  ///
  /// In en, this message translates to:
  /// **'App Theme'**
  String get appTheme;

  /// No description provided for @chooseHowAppLooks.
  ///
  /// In en, this message translates to:
  /// **'Choose how the app looks.'**
  String get chooseHowAppLooks;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text Size'**
  String get textSize;

  /// No description provided for @adjustTextSize.
  ///
  /// In en, this message translates to:
  /// **'Adjust text size across the app.'**
  String get adjustTextSize;

  /// No description provided for @smaller.
  ///
  /// In en, this message translates to:
  /// **'Smaller'**
  String get smaller;

  /// No description provided for @larger.
  ///
  /// In en, this message translates to:
  /// **'Larger'**
  String get larger;

  /// No description provided for @support.
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get support;

  /// No description provided for @sendAppFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send App Feedback'**
  String get sendAppFeedback;

  /// No description provided for @reportBugsImprovements.
  ///
  /// In en, this message translates to:
  /// **'Report bugs, misleading information, or improvement suggestions.'**
  String get reportBugsImprovements;

  /// No description provided for @noFeedbackYet.
  ///
  /// In en, this message translates to:
  /// **'You have not submitted any feedback yet.'**
  String get noFeedbackYet;

  /// No description provided for @adminResponse.
  ///
  /// In en, this message translates to:
  /// **'Admin Response'**
  String get adminResponse;

  /// No description provided for @awaitingAdminResponse.
  ///
  /// In en, this message translates to:
  /// **'Awaiting admin response...'**
  String get awaitingAdminResponse;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusInProgress.
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get statusInProgress;

  /// No description provided for @statusResolved.
  ///
  /// In en, this message translates to:
  /// **'Resolved'**
  String get statusResolved;

  /// No description provided for @statusWontFix.
  ///
  /// In en, this message translates to:
  /// **'Won\'t Fix'**
  String get statusWontFix;

  /// No description provided for @foodBusinessDetails.
  ///
  /// In en, this message translates to:
  /// **'Business Details'**
  String get foodBusinessDetails;

  /// No description provided for @aboutThisFoodExperience.
  ///
  /// In en, this message translates to:
  /// **'About this Food Experience'**
  String get aboutThisFoodExperience;

  /// No description provided for @highlights.
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get highlights;

  /// No description provided for @contactAndLinks.
  ///
  /// In en, this message translates to:
  /// **'Contact & Links'**
  String get contactAndLinks;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @openingHours.
  ///
  /// In en, this message translates to:
  /// **'Opening Hours'**
  String get openingHours;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @menuFallback.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menuFallback;

  /// No description provided for @call.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get call;

  /// No description provided for @website.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @orderOnline.
  ///
  /// In en, this message translates to:
  /// **'Order Online'**
  String get orderOnline;

  /// No description provided for @viewOnMap.
  ///
  /// In en, this message translates to:
  /// **'View on Map'**
  String get viewOnMap;

  /// No description provided for @foodDiscoveryGuide.
  ///
  /// In en, this message translates to:
  /// **'Food Discovery Guide'**
  String get foodDiscoveryGuide;

  /// No description provided for @foodDiscoveryGuideHelper.
  ///
  /// In en, this message translates to:
  /// **'Tap play to hear your Food Discovery Guide describe this food spot and its highlights.'**
  String get foodDiscoveryGuideHelper;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @unableToStartNarration.
  ///
  /// In en, this message translates to:
  /// **'Unable to start Food Discovery Guide narration right now.'**
  String get unableToStartNarration;

  /// No description provided for @unableToCallNumber.
  ///
  /// In en, this message translates to:
  /// **'Unable to call this number right now.'**
  String get unableToCallNumber;

  /// No description provided for @unableToSendEmail.
  ///
  /// In en, this message translates to:
  /// **'Unable to send email right now.'**
  String get unableToSendEmail;

  /// No description provided for @foodSpotCannotBeShared.
  ///
  /// In en, this message translates to:
  /// **'This food spot cannot be shared right now.'**
  String get foodSpotCannotBeShared;

  /// No description provided for @foodDescriptionIntro.
  ///
  /// In en, this message translates to:
  /// **'Step into {title}, a {cuisine} destination in the heart of {location}.'**
  String foodDescriptionIntro(String title, String cuisine, String location);

  /// No description provided for @foodDescriptionRating.
  ///
  /// In en, this message translates to:
  /// **'Loved by locals and visitors alike, it holds a {rating}-star rating.'**
  String foodDescriptionRating(String rating);

  /// No description provided for @foodDescriptionCategories.
  ///
  /// In en, this message translates to:
  /// **'The menu celebrates {categories}, crafted with fresh, locally sourced ingredients.'**
  String foodDescriptionCategories(String categories);

  /// No description provided for @foodDescriptionPrice.
  ///
  /// In en, this message translates to:
  /// **'Expect a {price} experience that balances quality and value.'**
  String foodDescriptionPrice(String price);

  /// No description provided for @foodDescriptionOutro.
  ///
  /// In en, this message translates to:
  /// **'Whether you are after a relaxed brunch, a business lunch, or a lively dinner, {title} offers a welcoming atmosphere and flavours that capture Brisbane\'s dining scene.'**
  String foodDescriptionOutro(String title);

  /// No description provided for @foodNarrationWelcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome to {title}'**
  String foodNarrationWelcome(String title);

  /// No description provided for @foodNarrationBadge.
  ///
  /// In en, this message translates to:
  /// **'This is a {badge} stop worth adding to your Brisbane food trail'**
  String foodNarrationBadge(String badge);

  /// No description provided for @foodNarrationCuisine.
  ///
  /// In en, this message translates to:
  /// **'It is best known for {cuisine}'**
  String foodNarrationCuisine(String cuisine);

  /// No description provided for @foodNarrationLocation.
  ///
  /// In en, this message translates to:
  /// **'You will find it in {location}, where the local dining scene comes alive'**
  String foodNarrationLocation(String location);

  /// No description provided for @foodNarrationDateTime.
  ///
  /// In en, this message translates to:
  /// **'You can usually visit during {dateTime}'**
  String foodNarrationDateTime(String dateTime);

  /// No description provided for @foodNarrationDescription.
  ///
  /// In en, this message translates to:
  /// **'Here\'s what the experience feels like. {description}'**
  String foodNarrationDescription(String description);

  /// No description provided for @foodNarrationPriceFree.
  ///
  /// In en, this message translates to:
  /// **'There is no entry cost to explore this food spot'**
  String get foodNarrationPriceFree;

  /// No description provided for @foodNarrationPrice.
  ///
  /// In en, this message translates to:
  /// **'Pricing is listed as {price}'**
  String foodNarrationPrice(String price);

  /// No description provided for @foodNarrationRating.
  ///
  /// In en, this message translates to:
  /// **'Visitors currently rate it {rating} out of 5'**
  String foodNarrationRating(String rating);

  /// No description provided for @foodNarrationCategories.
  ///
  /// In en, this message translates to:
  /// **'Expect a mix of {categories}'**
  String foodNarrationCategories(String categories);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
        'ar',
        'de',
        'el',
        'en',
        'es',
        'fr',
        'hi',
        'it',
        'ja',
        'ko',
        'pa',
        'pt',
        'ru',
        'vi',
        'zh'
      ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'el':
      return AppLocalizationsEl();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'hi':
      return AppLocalizationsHi();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'pa':
      return AppLocalizationsPa();
    case 'pt':
      return AppLocalizationsPt();
    case 'ru':
      return AppLocalizationsRu();
    case 'vi':
      return AppLocalizationsVi();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
