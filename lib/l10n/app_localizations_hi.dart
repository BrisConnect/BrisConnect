// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get appTitle => 'BrisConnect+';

  @override
  String get welcome => 'स्वागत है';

  @override
  String get signIn => 'साइन इन';

  @override
  String get signUp => 'साइन अप';

  @override
  String get signOut => 'साइन आउट';

  @override
  String get email => 'ईमेल';

  @override
  String get password => 'पासवर्ड';

  @override
  String get phone => 'फ़ोन';

  @override
  String get name => 'नाम';

  @override
  String get save => 'सहेजें';

  @override
  String get cancel => 'रद्द करें';

  @override
  String get editProfile => 'प्रोफ़ाइल संपादित करें';

  @override
  String get profileInfo => 'प्रोफ़ाइल जानकारी';

  @override
  String get preferences => 'प्राथमिकताएँ';

  @override
  String get language => 'भाषा';

  @override
  String get locationRadius => 'स्थान त्रिज्या';

  @override
  String get appearanceSettings => 'उपस्थिति सेटिंग्स';

  @override
  String get feedback => 'फीडबैक';

  @override
  String get myFeedback => 'मेरा फीडबैक';

  @override
  String get helpAndSupport => 'सहायता और समर्थन';

  @override
  String get discover => 'खोजें';

  @override
  String get community => 'समुदाय';

  @override
  String get map => 'नक्शा';

  @override
  String get saved => 'सहेजा गया';

  @override
  String get profile => 'प्रोफ़ाइल';

  @override
  String get food => 'भोजन';

  @override
  String get events => 'आयोजन';

  @override
  String get businesses => 'व्यवसाय';

  @override
  String get promotions => 'प्रचार';

  @override
  String get photos => 'फ़ोटो';

  @override
  String get newPost => 'नया';

  @override
  String get search => 'खोज';

  @override
  String get filter => 'फ़िल्टर';

  @override
  String get clearFilters => 'फ़िल्टर साफ़ करें';

  @override
  String get noResults => 'कोई परिणाम नहीं मिला';

  @override
  String get loading => 'लोड हो रहा है...';

  @override
  String get error => 'त्रुटि';

  @override
  String get success => 'सफल';

  @override
  String get profileUpdated => 'प्रोफ़ाइल सफलतापूर्वक अपडेट की गई।';

  @override
  String get profileUpdateFailed =>
      'प्रोफ़ाइल अपडेट नहीं की जा सकी। कृपया पुनः प्रयास करें।';

  @override
  String get guestVisitor => 'अतिथि आगंतुक';

  @override
  String get localUser => 'स्थानीय';

  @override
  String get filterEventsTitle => 'इवेंट फ़िल्टर करें';

  @override
  String get priceLabel => 'कीमत';

  @override
  String get dateLabel => 'दिनांक';

  @override
  String get pickADate => 'एक तारीख चुनें';

  @override
  String get resetButton => 'रीसेट करें';

  @override
  String get applyButton => 'आवेदन करें';

  @override
  String get freeLabel => 'मुफ़्त';

  @override
  String get paidLabel => 'भुगतान किया गया';

  @override
  String eventSavedToInterested(String eventTitle) {
    return '$eventTitle को इच्छुक में सहेजा गया।';
  }

  @override
  String eventRemovedFromInterested(String eventTitle) {
    return '$eventTitle को इच्छुक से हटा दिया गया।';
  }

  @override
  String savedToAttractions(String title) {
    return '$title को सहेजे गए आकर्षण में सहेजा गया।';
  }

  @override
  String removedFromAttractions(String title) {
    return '$title को सहेजे गए आकर्षणों से हटा दिया गया।';
  }

  @override
  String get pleaseSignInToSaveEvents =>
      'कृपया ईवेंट सहेजने के लिए विज़िटर के रूप में लॉग इन करें।';

  @override
  String get pleaseSignInToReview =>
      'कृपया समीक्षा या बज़वोट लिखने के लिए साइन इन करें।';

  @override
  String reviewSubmitted(String rating, String buzzRating) {
    return 'समीक्षा सबमिट की गई\\! ⭐ $rating / बज़ ⚡ $buzzRating';
  }

  @override
  String reviewSubmitFailed(String error) {
    return 'समीक्षा सबमिट नहीं की जा सकी: $error';
  }

  @override
  String get noExternalLink =>
      'इस आइटम के लिए अभी तक कोई बाहरी लिंक उपलब्ध नहीं है।';

  @override
  String get unableToOpenLink => 'इवेंट लिंक अभी खोलने में असमर्थ.';

  @override
  String shareTitle(String title) {
    return 'साझा करें: $title';
  }

  @override
  String get reportEvent => 'घटना की रिपोर्ट करें';

  @override
  String get reviewsOnlyForFood =>
      'समीक्षाएँ केवल खाद्य पदार्थों के लिए उपलब्ध हैं';

  @override
  String get chooseFromGallery => 'गैलरी से चुनें';

  @override
  String get takeAPhoto => 'एक फोटो लें';

  @override
  String get pleaseLoginVisitor => 'कृपया पहले विज़िटर के रूप में लॉग इन करें।';

  @override
  String get onlyJpgPng => 'केवल JPG और PNG छवियाँ समर्थित हैं।';

  @override
  String get imageTooLarge => 'छवि बहुत बड़ी है. कृपया एक छोटी छवि चुनें.';

  @override
  String get profilePictureUpdated =>
      'प्रोफ़ाइल चित्र सफलतापूर्वक अपडेट किया गया.';

  @override
  String get profilePictureUpdateFailed =>
      'प्रोफ़ाइल चित्र अपडेट नहीं किया जा सका. कृपया पुन: प्रयास करें।';

  @override
  String get enterYourName => 'अपना नाम दर्ज करें';

  @override
  String get phoneHint => 'जैसे 04xxxxxx';

  @override
  String get nameCannotBeEmpty => 'नाम खाली नहीं हो सकता.';

  @override
  String get nameMinLength => 'नाम कम से कम 2 अक्षर का होना चाहिए.';

  @override
  String get enterValidPhone => 'एक वैध फ़ोन नंबर दर्ज करें.';

  @override
  String get changeProfilePicture => 'प्रोफ़ाइल चित्र बदलें';

  @override
  String get uploadProfilePicture => 'प्रोफ़ाइल चित्र अपलोड करें';

  @override
  String get areYouSureSignOut => 'क्या आप वाकई साइन आउट करना चाहते हैं?';

  @override
  String get returnWelcome => 'स्वागत स्क्रीन पर लौटें';

  @override
  String get setHowFarRecommendations =>
      'निर्धारित करें कि सिफ़ारिशें कितनी दूर तक हो सकती हैं';

  @override
  String get themeTextSizeFeedback => 'थीम, पाठ का आकार और प्रतिक्रिया';

  @override
  String get faqsContactAppInfo =>
      'अक्सर पूछे जाने वाले प्रश्न, हमसे संपर्क करें और ऐप की जानकारी';

  @override
  String get viewSubmittedFeedback =>
      'अपनी सबमिट की गई प्रतिक्रिया और व्यवस्थापक प्रतिक्रियाएँ देखें';

  @override
  String get discoverSubtitle => 'स्थानीय भोजन और अनुभवों की खोज करें';

  @override
  String get searchHintLocalFood => 'स्थानीय खाद्य व्यवसाय खोजें...';

  @override
  String get homeLabel => 'घर';

  @override
  String get recommendedForYou => 'आपके लिए अनुशंसित';

  @override
  String get seeAll => 'सभी देखें';

  @override
  String get categories => 'श्रेणियाँ';

  @override
  String get nearby => 'पास में';

  @override
  String get noFoodPlacesFound => 'खाने की कोई जगह नहीं मिली';

  @override
  String get noFoodPlacesSubtitle =>
      'अपनी खोज या फ़िल्टर चयन बदलने का प्रयास करें।';

  @override
  String get localFoodBusinesses => 'स्थानीय खाद्य व्यवसाय';

  @override
  String get localFoodSubtitle =>
      'छोटे और मध्यम ब्रिस्बेन खाद्य उद्यमों का समर्थन करें';

  @override
  String get exploreReviewFoodBusinesses =>
      'खाद्य व्यवसायों का अन्वेषण एवं समीक्षा करें';

  @override
  String get noSavedItemsTitle => 'अभी तक कोई सहेजा गया आइटम नहीं';

  @override
  String get noSavedItemsSubtitle =>
      'उन्हें यहां सहेजने के लिए खाद्य व्यवसाय कार्ड पर दिल आइकन या व्यावसायिक प्रोफ़ाइल पर बुकमार्क पर टैप करें।';

  @override
  String get savedEvents => 'सहेजे गए इवेंट';

  @override
  String get savedEventsSubtitle => 'आपके ईवेंट अनुस्मारक और योजनाएँ';

  @override
  String get savedAttractions => 'सहेजे गए आकर्षण';

  @override
  String get savedAttractionsSubtitle =>
      'घटनाओं से स्वतंत्र रूप से घूमने लायक स्थान';

  @override
  String get savedBusinesses => 'सहेजे गए व्यवसाय';

  @override
  String get savedBusinessesSubtitle =>
      'खाद्य व्यवसाय जिन्हें आपने बुकमार्क किया है';

  @override
  String get savedItemsUnavailableTitle => 'सहेजे गए आइटम अनुपलब्ध हैं';

  @override
  String get savedItemsUnavailableSubtitle =>
      'कुछ सहेजे गए आइटम अब डिस्कवरी फ़ीड में प्रकाशित नहीं किए जाते हैं।';

  @override
  String get retryAction => 'पुनः प्रयास करें';

  @override
  String get unableToLoadDiscover =>
      'अभी खोजे गए आइटम लोड करने में असमर्थ. कृपया पुन: प्रयास करें।';

  @override
  String get unableToLoadSaved =>
      'अभी सहेजे गए आइटम लोड करने में असमर्थ. कृपया पुन: प्रयास करें।';

  @override
  String get dateTBA => 'दिनांक टीबीए';

  @override
  String get timeTBA => 'समय टीबीए';

  @override
  String get untitledEvent => 'शीर्षकहीन घटना';

  @override
  String get locationTBA => 'स्थान टीबीए';

  @override
  String get priceTBA => 'कीमत टीबीए';

  @override
  String get placeFallback => 'जगह';

  @override
  String get foodExperienceFallback => 'भोजन का अनुभव';

  @override
  String get stadiumFallback => 'स्टेडियम';

  @override
  String get eventFallback => 'घटना';

  @override
  String get attractionFallback => 'आकर्षण';

  @override
  String ratingReviewsCount(String rating, String count) {
    return '$rating · $count समीक्षाएँ';
  }

  @override
  String get approved => 'स्वीकृत';

  @override
  String get audience => 'दर्शक';

  @override
  String get businessLabel => 'व्यवसाय';

  @override
  String get controlDistance => 'आस-पास के अवसरों के लिए दूरी नियंत्रित करें';

  @override
  String get dashboard => 'डैशबोर्ड';

  @override
  String get delete => 'हटाएँ';

  @override
  String get deleteEvent => 'ईवेंट हटाएँ';

  @override
  String get deletingEvent => 'ईवेंट हटाया जा रहा है...';

  @override
  String get displayName => 'प्रदर्शन नाम';

  @override
  String errorDeletingEvent(String error) {
    return 'ईवेंट हटाने में त्रुटि: $error';
  }

  @override
  String errorLoadingMap(String error) {
    return 'मानचित्र लोड करने में त्रुटि: $error';
  }

  @override
  String eventDeleted(String title) {
    return 'इवेंट \"$title\" हटा दिया गया है।';
  }

  @override
  String get failedToDeleteEvent =>
      'ईवेंट हटाने में विफल. कृपया पुन: प्रयास करें।';

  @override
  String get feed => 'फ़ीड';

  @override
  String get localBusinessPortal => 'स्थानीय व्यापार पोर्टल';

  @override
  String get pending => 'लंबित';

  @override
  String get phoneNumber => 'फ़ोन नंबर';

  @override
  String get pleaseLoginLocal =>
      'कृपया पहले स्थानीय उपयोगकर्ता के रूप में लॉग इन करें।';

  @override
  String get pleaseLoginToDelete => 'कृपया ईवेंट हटाने के लिए लॉग इन करें।';

  @override
  String get pushAlerts => 'अपने व्यवसाय के लिए अलर्ट पुश करें';

  @override
  String get rejected => 'अस्वीकृत';

  @override
  String get reviews => 'समीक्षाएँ';

  @override
  String get saveChanges => 'परिवर्तन सहेजें';

  @override
  String get searchHintEvents => 'ईवेंट, बुकिंग खोजें...';

  @override
  String get suburb => 'उपनगर';

  @override
  String get thisLinkUnavailable => 'यह लिंक अभी उपलब्ध नहीं है.';

  @override
  String get total => 'कुल';

  @override
  String get couldNotSaveSettings =>
      'सेटिंग्स सहेजी नहीं जा सकीं. कृपया पुन: प्रयास करें।';

  @override
  String get locationAccessDisabled =>
      'ऐप सुविधाओं के लिए स्थान पहुंच अक्षम कर दी गई है.';

  @override
  String get locationPermissionGranted => 'स्थान की अनुमति दी गई.';

  @override
  String get openSettings => 'सेटिंग्स खोलें';

  @override
  String get themeDark => 'अंधेरा';

  @override
  String get themeLight => 'रोशनी';

  @override
  String get themeSystem => 'सिस्टम';

  @override
  String textScalePercent(String value) {
    return '$value%';
  }

  @override
  String categoryLabel(String category) {
    return 'श्रेणी: $category';
  }

  @override
  String severityLabel(String severity) {
    return 'गंभीरता: $severity';
  }

  @override
  String get languageEnglish => 'अंग्रेजी';

  @override
  String get languageSpanish => 'स्पैनिश';

  @override
  String get languageFrench => 'फ़्रेंच';

  @override
  String get languageGerman => 'जर्मन';

  @override
  String get languageChinese => 'चीनी';

  @override
  String get languageArabic => 'अरबी';

  @override
  String get languageHindi => 'हिंदी';

  @override
  String get languageItalian => 'इटालियन';

  @override
  String get languageJapanese => 'जापानी';

  @override
  String get languageKorean => 'कोरियाई';

  @override
  String get languagePortuguese => 'पुर्तगाली';

  @override
  String get languageRussian => 'रूसी';

  @override
  String get languageVietnamese => 'वियतनामी';

  @override
  String get languageGreek => 'यूनानी';

  @override
  String get languagePunjabi => 'Punjabi';

  @override
  String get discoverTitle => 'स्थानीय भोजन की खोज करें';

  @override
  String get openSourceLink => 'ओपन सोर्स लिंक';

  @override
  String get pendingApproval => 'लंबित अनुमोदन';

  @override
  String deleteEventConfirmation(String title) {
    return 'क्या आप वाकई \"$title\" को हटाना चाहते हैं? ';
  }

  @override
  String get myActivity => 'मेरी गतिविधि';

  @override
  String get businessNotifications => 'व्यावसायिक सूचनाएं';

  @override
  String get about => 'के बारे में';

  @override
  String get aboutDescription =>
      'ब्रिसकनेक्ट+ एक स्मार्ट सिटी गाइड है जो आगंतुकों और स्थानीय लोगों को घटनाओं की खोज करने, आकर्षणों का पता लगाने और उनके ब्रिस्बेन अनुभवों को एक कनेक्टेड प्लेटफॉर्म पर कैद करने में मदद करता है।';

  @override
  String versionLabel(String version) {
    return 'संस्करण $version';
  }

  @override
  String get locationPermissions => 'स्थान अनुमतियाँ';

  @override
  String get enableLocationAccess => 'स्थान पहुंच सक्षम करें';

  @override
  String get allowNearbyMapFeatures =>
      'आस-पास की अनुशंसाओं और मानचित्र-जागरूक सुविधाओं को अनुमति दें।';

  @override
  String get locationSettings => 'स्थान सेटिंग्स';

  @override
  String get setSearchRadius =>
      'घटनाओं और आकर्षणों के लिए अपना खोज दायरा निर्धारित करें।';

  @override
  String get pleaseLoginToViewSettings =>
      'सेटिंग्स देखने के लिए कृपया लॉग इन करें।';

  @override
  String get locationPermissionNotGranted =>
      'स्थान की अनुमति नहीं दी गई. आप इसे सिस्टम सेटिंग्स में सक्षम कर सकते हैं।';

  @override
  String get theme => 'विषय';

  @override
  String get appTheme => 'ऐप थीम';

  @override
  String get chooseHowAppLooks => 'चुनें कि ऐप कैसा दिखेगा.';

  @override
  String get textSize => 'टेक्स्ट का साइज़';

  @override
  String get adjustTextSize => 'पूरे ऐप में टेक्स्ट का आकार समायोजित करें।';

  @override
  String get smaller => 'छोटे';

  @override
  String get larger => 'बड़ा';

  @override
  String get support => 'सहायता';

  @override
  String get sendAppFeedback => 'ऐप फीडबैक भेजें';

  @override
  String get reportBugsImprovements =>
      'बग, भ्रामक जानकारी या सुधार सुझावों की रिपोर्ट करें।';

  @override
  String get noFeedbackYet => 'आपने अभी तक कोई प्रतिक्रिया सबमिट नहीं की है.';

  @override
  String get adminResponse => 'व्यवस्थापक प्रतिक्रिया';

  @override
  String get awaitingAdminResponse =>
      'व्यवस्थापक की प्रतिक्रिया की प्रतीक्षा है...';

  @override
  String get statusPending => 'लंबित';

  @override
  String get statusInProgress => 'प्रगति पर है';

  @override
  String get statusResolved => 'हल किया';

  @override
  String get statusWontFix => 'ठीक नहीं होगा';

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
