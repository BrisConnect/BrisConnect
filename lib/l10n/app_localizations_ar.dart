// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appTitle => 'BrisConnect+';

  @override
  String get welcome => 'مرحباً';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signUp => 'التسجيل';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get phone => 'الهاتف';

  @override
  String get name => 'الاسم';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get editProfile => 'تعديل الملف الشخصي';

  @override
  String get profileInfo => 'معلومات الملف الشخصي';

  @override
  String get preferences => 'التفضيلات';

  @override
  String get language => 'اللغة';

  @override
  String get locationRadius => 'نطاق الموقع';

  @override
  String get appearanceSettings => 'إعدادات المظهر';

  @override
  String get feedback => 'الملاحظات';

  @override
  String get myFeedback => 'ملاحظاتي';

  @override
  String get helpAndSupport => 'المساعدة والدعم';

  @override
  String get discover => 'استكشف';

  @override
  String get community => 'المجتمع';

  @override
  String get map => 'الخريطة';

  @override
  String get saved => 'المحفوظات';

  @override
  String get profile => 'الملف الشخصي';

  @override
  String get food => 'طعام';

  @override
  String get events => 'فعاليات';

  @override
  String get businesses => 'أعمال';

  @override
  String get promotions => 'عروض';

  @override
  String get photos => 'صور';

  @override
  String get newPost => 'جديد';

  @override
  String get search => 'بحث';

  @override
  String get filter => 'تصفية';

  @override
  String get clearFilters => 'مسح التصفية';

  @override
  String get noResults => 'لم يتم العثور على نتائج';

  @override
  String get loading => 'جارٍ التحميل...';

  @override
  String get error => 'خطأ';

  @override
  String get success => 'نجاح';

  @override
  String get profileUpdated => 'تم تحديث الملف الشخصي بنجاح.';

  @override
  String get profileUpdateFailed =>
      'تعذر تحديث الملف الشخصي. يرجى المحاولة مرة أخرى.';

  @override
  String get guestVisitor => 'زائر ضيف';

  @override
  String get localUser => 'محلي';

  @override
  String get filterEventsTitle => 'تصفية الأحداث';

  @override
  String get priceLabel => 'السعر';

  @override
  String get dateLabel => 'التاريخ';

  @override
  String get pickADate => 'اختر موعدًا';

  @override
  String get resetButton => 'إعادة تعيين';

  @override
  String get applyButton => 'تطبيق';

  @override
  String get freeLabel => 'مجاني';

  @override
  String get paidLabel => 'مدفوعة';

  @override
  String eventSavedToInterested(String eventTitle) {
    return '$eventTitle تم الحفظ لدى المهتمين.';
  }

  @override
  String eventRemovedFromInterested(String eventTitle) {
    return 'تمت إزالة $eventTitle من مهتم.';
  }

  @override
  String savedToAttractions(String title) {
    return '$title تم الحفظ في مناطق الجذب المحفوظة.';
  }

  @override
  String removedFromAttractions(String title) {
    return 'تمت إزالة $title من مناطق الجذب المحفوظة.';
  }

  @override
  String get pleaseSignInToSaveEvents =>
      'الرجاء تسجيل الدخول كزائر لحفظ الأحداث.';

  @override
  String get pleaseSignInToReview =>
      'الرجاء تسجيل الدخول لكتابة مراجعة أو BuzzVote.';

  @override
  String reviewSubmitted(String rating, String buzzRating) {
    return 'تم إرسال المراجعة\\! ⭐ $rating / نبضات ⚡ $buzzRating';
  }

  @override
  String reviewSubmitFailed(String error) {
    return 'تعذر إرسال المراجعة: $error';
  }

  @override
  String get noExternalLink => 'لا يوجد رابط خارجي متاح لهذا البند حتى الآن.';

  @override
  String get unableToOpenLink => 'غير قادر على فتح رابط الحدث الآن.';

  @override
  String shareTitle(String title) {
    return 'مشاركة: $title';
  }

  @override
  String get reportEvent => 'الإبلاغ عن الحدث';

  @override
  String get reviewsOnlyForFood => 'التقييمات متاحة فقط للمواد الغذائية';

  @override
  String get chooseFromGallery => 'اختر من المعرض';

  @override
  String get takeAPhoto => 'التقط صورة';

  @override
  String get pleaseLoginVisitor => 'الرجاء تسجيل الدخول كزائر أولا.';

  @override
  String get onlyJpgPng => 'يتم دعم صور JPG وPNG فقط.';

  @override
  String get imageTooLarge => 'الصورة كبيرة جدًا. الرجاء اختيار صورة أصغر.';

  @override
  String get profilePictureUpdated => 'تم تحديث الصورة الشخصية بنجاح.';

  @override
  String get profilePictureUpdateFailed =>
      'لا يمكن تحديث صورة الملف الشخصي. يرجى المحاولة مرة أخرى.';

  @override
  String get enterYourName => 'أدخل اسمك';

  @override
  String get phoneHint => 'على سبيل المثال 04xxxxxxxxxx';

  @override
  String get nameCannotBeEmpty => 'لا يمكن أن يكون الاسم فارغًا.';

  @override
  String get nameMinLength => 'يجب أن يتكون الاسم من حرفين على الأقل.';

  @override
  String get enterValidPhone => 'أدخل رقم هاتف صالحًا.';

  @override
  String get changeProfilePicture => 'تغيير الصورة الشخصية';

  @override
  String get uploadProfilePicture => 'تحميل الصورة الشخصية';

  @override
  String get areYouSureSignOut => 'هل أنت متأكد أنك تريد تسجيل الخروج؟';

  @override
  String get returnWelcome => 'العودة إلى شاشة الترحيب';

  @override
  String get setHowFarRecommendations =>
      'تحديد المدى الذي يمكن أن تصل إليه التوصيات';

  @override
  String get themeTextSizeFeedback => 'الموضوع وحجم النص والتعليقات';

  @override
  String get faqsContactAppInfo => 'الأسئلة الشائعة، اتصل بنا ومعلومات التطبيق';

  @override
  String get viewSubmittedFeedback => 'عرض ملاحظاتك المقدمة واستجابات المشرف';

  @override
  String get discoverSubtitle => 'اكتشف الأطعمة والتجارب المحلية';

  @override
  String get searchHintLocalFood => 'البحث عن شركات الأغذية المحلية...';

  @override
  String get homeLabel => 'الصفحة الرئيسية';

  @override
  String get recommendedForYou => 'موصى به لك';

  @override
  String get seeAll => 'رؤية الكل';

  @override
  String get categories => 'الفئات';

  @override
  String get nearby => 'قريب';

  @override
  String get noFoodPlacesFound => 'لم يتم العثور على أماكن الطعام';

  @override
  String get noFoodPlacesSubtitle => 'حاول تغيير اختيارات البحث أو التصفية.';

  @override
  String get localFoodBusinesses => 'شركات الأغذية المحلية';

  @override
  String get localFoodSubtitle =>
      'دعم المؤسسات الغذائية الصغيرة والمتوسطة في بريسبان';

  @override
  String get exploreReviewFoodBusinesses => 'استكشاف ومراجعة الشركات الغذائية';

  @override
  String get noSavedItemsTitle => 'لا توجد عناصر محفوظة حتى الآن';

  @override
  String get noSavedItemsSubtitle =>
      'اضغط على أيقونة القلب الموجودة على بطاقات العمل الخاصة بالأطعمة أو الإشارة المرجعية الموجودة في ملف تعريف العمل لحفظها هنا.';

  @override
  String get savedEvents => 'الأحداث المحفوظة';

  @override
  String get savedEventsSubtitle => 'تذكيرات وخطط الحدث الخاص بك';

  @override
  String get savedAttractions => 'المعالم المحفوظة';

  @override
  String get savedAttractionsSubtitle => 'أماكن للزيارة بشكل مستقل عن الأحداث';

  @override
  String get savedBusinesses => 'الأعمال المحفوظة';

  @override
  String get savedBusinessesSubtitle =>
      'الشركات الغذائية التي قمت بوضع إشارة مرجعية عليها';

  @override
  String get savedItemsUnavailableTitle => 'العناصر المحفوظة غير متوفرة';

  @override
  String get savedItemsUnavailableSubtitle =>
      'لم تعد بعض العناصر المحفوظة منشورة في موجز الاكتشاف.';

  @override
  String get retryAction => 'أعد المحاولة';

  @override
  String get unableToLoadDiscover =>
      'غير قادر على تحميل اكتشاف العناصر الآن. يرجى المحاولة مرة أخرى.';

  @override
  String get unableToLoadSaved =>
      'غير قادر على تحميل العناصر المحفوظة الآن. يرجى المحاولة مرة أخرى.';

  @override
  String get dateTBA => 'التاريخ سيتم تحديده';

  @override
  String get timeTBA => 'الوقت سيتم تحديده';

  @override
  String get untitledEvent => 'حدث بلا عنوان';

  @override
  String get locationTBA => 'الموقع سيتم تحديده';

  @override
  String get priceTBA => 'السعر يحدد لاحقا';

  @override
  String get placeFallback => 'مكان';

  @override
  String get foodExperienceFallback => 'تجربة الغذاء';

  @override
  String get stadiumFallback => 'الملعب';

  @override
  String get eventFallback => 'حدث';

  @override
  String get attractionFallback => 'الجذب';

  @override
  String ratingReviewsCount(String rating, String count) {
    return '$rating · $count المراجعات';
  }

  @override
  String get approved => 'تمت الموافقة عليه';

  @override
  String get audience => 'الجمهور';

  @override
  String get businessLabel => 'الأعمال';

  @override
  String get controlDistance => 'التحكم في المسافة للفرص القريبة';

  @override
  String get dashboard => 'لوحة القيادة';

  @override
  String get delete => 'حذف';

  @override
  String get deleteEvent => 'حذف الحدث';

  @override
  String get deletingEvent => 'جارٍ حذف الحدث...';

  @override
  String get displayName => 'اسم العرض';

  @override
  String errorDeletingEvent(String error) {
    return 'حدث خطأ أثناء حذف الحدث: $error';
  }

  @override
  String errorLoadingMap(String error) {
    return 'خطأ في تحميل الخريطة: $error';
  }

  @override
  String eventDeleted(String title) {
    return 'تم حذف الحدث \"$title\".';
  }

  @override
  String get failedToDeleteEvent => 'فشل في حذف الحدث. يرجى المحاولة مرة أخرى.';

  @override
  String get feed => 'تغذية';

  @override
  String get localBusinessPortal => 'بوابة الأعمال المحلية';

  @override
  String get pending => 'في انتظار';

  @override
  String get phoneNumber => 'رقم الهاتف';

  @override
  String get pleaseLoginLocal => 'الرجاء تسجيل الدخول كمستخدم محلي أولاً.';

  @override
  String get pleaseLoginToDelete => 'الرجاء تسجيل الدخول لحذف الأحداث.';

  @override
  String get pushAlerts => 'دفع التنبيهات لعملك';

  @override
  String get rejected => 'مرفوض';

  @override
  String get reviews => 'التعليقات';

  @override
  String get saveChanges => 'حفظ التغييرات';

  @override
  String get searchHintEvents => 'البحث عن الأحداث والحجوزات...';

  @override
  String get suburb => 'ضاحية';

  @override
  String get thisLinkUnavailable => 'هذا الرابط غير متوفر حاليا.';

  @override
  String get total => 'المجموع';

  @override
  String get couldNotSaveSettings =>
      'لا يمكن حفظ الإعدادات. يرجى المحاولة مرة أخرى.';

  @override
  String get locationAccessDisabled =>
      'تم تعطيل الوصول إلى الموقع بسبب ميزات التطبيق.';

  @override
  String get locationPermissionGranted => 'تم منح إذن الموقع.';

  @override
  String get openSettings => 'افتح الإعدادات';

  @override
  String get themeDark => 'الظلام';

  @override
  String get themeLight => 'ضوء';

  @override
  String get themeSystem => 'النظام';

  @override
  String textScalePercent(String value) {
    return '$value%';
  }

  @override
  String categoryLabel(String category) {
    return 'الفئة: $category';
  }

  @override
  String severityLabel(String severity) {
    return 'الخطورة: $severity';
  }

  @override
  String get languageEnglish => 'الإنجليزية';

  @override
  String get languageSpanish => 'الاسبانية';

  @override
  String get languageFrench => 'الفرنسية';

  @override
  String get languageGerman => 'الألمانية';

  @override
  String get languageChinese => 'صيني';

  @override
  String get languageArabic => 'العربية';

  @override
  String get languageHindi => 'الهندية';

  @override
  String get languageItalian => 'ايطالي';

  @override
  String get languageJapanese => 'اليابانية';

  @override
  String get languageKorean => 'الكورية';

  @override
  String get languagePortuguese => 'البرتغالية';

  @override
  String get languageRussian => 'الروسية';

  @override
  String get languageVietnamese => 'الفيتنامية';

  @override
  String get languageGreek => 'اليونانية';

  @override
  String get discoverTitle => 'اكتشف الأطعمة المحلية';

  @override
  String get openSourceLink => 'رابط مفتوح المصدر';

  @override
  String get pendingApproval => 'في انتظار الموافقة';

  @override
  String deleteEventConfirmation(String title) {
    return 'هل أنت متأكد أنك تريد حذف \"$title\"؟ ';
  }

  @override
  String get myActivity => 'نشاطي';

  @override
  String get businessNotifications => 'إشعارات الأعمال';

  @override
  String get about => 'عن';

  @override
  String get aboutDescription =>
      'BrisConnect+ هو دليل للمدينة الذكية يساعد الزوار والسكان المحليين على اكتشاف الأحداث واستكشاف المعالم السياحية والتقاط تجاربهم في بريسبان في منصة واحدة متصلة.';

  @override
  String versionLabel(String version) {
    return 'الإصدار $version';
  }

  @override
  String get locationPermissions => 'أذونات الموقع';

  @override
  String get enableLocationAccess => 'تمكين الوصول إلى الموقع';

  @override
  String get allowNearbyMapFeatures =>
      'السماح بالتوصيات القريبة والميزات المدركة للخريطة.';

  @override
  String get locationSettings => 'إعدادات الموقع';

  @override
  String get setSearchRadius =>
      'قم بتعيين نطاق البحث الخاص بك للأحداث والمعالم السياحية.';

  @override
  String get pleaseLoginToViewSettings => 'الرجاء تسجيل الدخول لعرض الإعدادات.';

  @override
  String get locationPermissionNotGranted =>
      'لم يتم منح إذن تحديد الموقع. يمكنك تمكينه في إعدادات النظام.';

  @override
  String get theme => 'سمة';

  @override
  String get appTheme => 'موضوع التطبيق';

  @override
  String get chooseHowAppLooks => 'اختر كيف يبدو التطبيق.';

  @override
  String get textSize => 'حجم النص';

  @override
  String get adjustTextSize => 'ضبط حجم النص عبر التطبيق.';

  @override
  String get smaller => 'الأصغر';

  @override
  String get larger => 'أكبر';

  @override
  String get support => 'يدعم';

  @override
  String get sendAppFeedback => 'إرسال تعليقات التطبيق';

  @override
  String get reportBugsImprovements =>
      'الإبلاغ عن الأخطاء أو المعلومات المضللة أو اقتراحات التحسين.';

  @override
  String get noFeedbackYet => 'لم ترسل أي تعليقات حتى الآن.';

  @override
  String get adminResponse => 'رد المشرف';

  @override
  String get awaitingAdminResponse => 'في انتظار رد الإدارة...';

  @override
  String get statusPending => 'قيد الانتظار';

  @override
  String get statusInProgress => 'في تَقَدم';

  @override
  String get statusResolved => 'تم الحل';

  @override
  String get statusWontFix => 'لن يتم إصلاحه';

  @override
  String get foodBusinessDetails => 'تفاصيل العمل';

  @override
  String get aboutThisFoodExperience => 'عن هذه التجربة الغذائية';

  @override
  String get highlights => 'أبرز المعالم';

  @override
  String get contactAndLinks => 'جهات الاتصال والروابط';

  @override
  String get gallery => 'المعرض';

  @override
  String get openingHours => 'ساعات العمل';

  @override
  String get menu => 'القائمة';

  @override
  String get menuFallback => 'القائمة';

  @override
  String get call => 'اتصال';

  @override
  String get website => 'الموقع الإلكتروني';

  @override
  String get orderOnline => 'اطلب عبر الإنترنت';

  @override
  String get viewOnMap => 'عرض على الخريطة';

  @override
  String get foodDiscoveryGuide => 'دليل اكتشاف الطعام';

  @override
  String get foodDiscoveryGuideHelper =>
      'اضغط على التشغيل لسماع دليل اكتشاف الطعام يصف لك هذا المكان ونقاطه البارزة.';

  @override
  String get stop => 'إيقاف';

  @override
  String get unableToStartNarration =>
      'تعذر بدء الرواية الصوتية لدليل اكتشاف الطعام الآن.';

  @override
  String get unableToCallNumber => 'تعذر الاتصال بهذا الرقم الآن.';

  @override
  String get unableToSendEmail => 'تعذر إرسال البريد الإلكتروني الآن.';

  @override
  String get foodSpotCannotBeShared =>
      'لا يمكن مشاركة هذا المكان الغذائي الآن.';

  @override
  String foodDescriptionIntro(String title, String cuisine, String location) {
    return 'تفضل بزيارة $title، وجهة $cuisine في قلب $location.';
  }

  @override
  String foodDescriptionRating(String rating) {
    return 'يحظى بإعجاب السكان المحليين والزوار على حد سواء، ويحمل تصنيفًا بقدر $rating نجوم.';
  }

  @override
  String foodDescriptionCategories(String categories) {
    return 'تتباهى القائمة بـ $categories، المُحضَّرة بمكونات طازجة ومُصنَّعة محليًا.';
  }

  @override
  String foodDescriptionPrice(String price) {
    return 'توقع تجربة $price التي توازن بين الجودة والقيمة.';
  }

  @override
  String foodDescriptionOutro(String title) {
    return 'سواء كنت تبحث عن فطور هادئ أو غداء عمل أو عشاء حيوي، يقدم لك $title أجواءً ترحيبية ونكهات تعكس مشهد الطعام في بريزبان.';
  }

  @override
  String foodNarrationWelcome(String title) {
    return 'مرحبًا بك في $title';
  }

  @override
  String foodNarrationBadge(String badge) {
    return 'هذه محطة $badge تستحق الإضافة إلى مسار الطعام في بريزبان';
  }

  @override
  String foodNarrationCuisine(String cuisine) {
    return 'يشتهر بـ $cuisine';
  }

  @override
  String foodNarrationLocation(String location) {
    return 'ستجده في $location، حيث تنبض مشهد الطعام المحلي بالحياة';
  }

  @override
  String foodNarrationDateTime(String dateTime) {
    return 'عادةً ما يمكنك الزيارة خلال $dateTime';
  }

  @override
  String foodNarrationDescription(String description) {
    return 'إليك شعور هذه التجربة. $description';
  }

  @override
  String get foodNarrationPriceFree =>
      'لا توجد تكلفة دخول لاستكشاف هذا المكان الغذائي';

  @override
  String foodNarrationPrice(String price) {
    return 'السعر مدرج بأنه $price';
  }

  @override
  String foodNarrationRating(String rating) {
    return 'يصنفه الزوار حاليًا بـ $rating من أصل 5';
  }

  @override
  String foodNarrationCategories(String categories) {
    return 'توقع مزيجًا من $categories';
  }
}
