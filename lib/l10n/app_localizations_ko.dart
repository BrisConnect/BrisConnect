// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'BrisConnect+';

  @override
  String get welcome => '환영합니다';

  @override
  String get signIn => '로그인';

  @override
  String get signUp => '회원가입';

  @override
  String get signOut => '로그아웃';

  @override
  String get email => '이메일';

  @override
  String get password => '비밀번호';

  @override
  String get phone => '전화';

  @override
  String get name => '이름';

  @override
  String get save => '저장';

  @override
  String get cancel => '취소';

  @override
  String get editProfile => '프로필 편집';

  @override
  String get profileInfo => '프로필 정보';

  @override
  String get preferences => '설정';

  @override
  String get language => '언어';

  @override
  String get locationRadius => '위치 반경';

  @override
  String get appearanceSettings => '외관 설정';

  @override
  String get feedback => '피드백';

  @override
  String get myFeedback => '내 피드백';

  @override
  String get helpAndSupport => '도움말 및 지원';

  @override
  String get discover => '발견';

  @override
  String get community => '커뮤니티';

  @override
  String get map => '지도';

  @override
  String get saved => '저장됨';

  @override
  String get profile => '프로필';

  @override
  String get food => '음식';

  @override
  String get events => '이벤트';

  @override
  String get businesses => '비즈니스';

  @override
  String get promotions => '프로모션';

  @override
  String get photos => '사진';

  @override
  String get newPost => '신규';

  @override
  String get search => '검색';

  @override
  String get filter => '필터';

  @override
  String get clearFilters => '필터 지우기';

  @override
  String get noResults => '결과를 찾을 수 없음';

  @override
  String get loading => '로딩 중...';

  @override
  String get error => '오류';

  @override
  String get success => '성공';

  @override
  String get profileUpdated => '프로필이 성공적으로 업데이트되었습니다.';

  @override
  String get profileUpdateFailed => '프로필을 업데이트할 수 없습니다. 다시 시도해 주세요.';

  @override
  String get guestVisitor => '게스트 방문자';

  @override
  String get localUser => '현지의';

  @override
  String get filterEventsTitle => '이벤트 필터링';

  @override
  String get priceLabel => '가격';

  @override
  String get dateLabel => '날짜';

  @override
  String get pickADate => '날짜를 선택하세요';

  @override
  String get resetButton => '재설정';

  @override
  String get applyButton => '적용';

  @override
  String get freeLabel => '무료';

  @override
  String get paidLabel => '유료';

  @override
  String eventSavedToInterested(String eventTitle) {
    return '$eventTitle이(가) 관심 있음에 저장되었습니다.';
  }

  @override
  String eventRemovedFromInterested(String eventTitle) {
    return '$eventTitle이(가) 관심 목록에서 삭제되었습니다.';
  }

  @override
  String savedToAttractions(String title) {
    return '$title이(가) 저장된 명소에 저장되었습니다.';
  }

  @override
  String removedFromAttractions(String title) {
    return '$title이(가) 저장된 명소에서 삭제되었습니다.';
  }

  @override
  String get pleaseSignInToSaveEvents => '이벤트를 저장하려면 방문자로 로그인하세요.';

  @override
  String get pleaseSignInToReview => '리뷰를 작성하거나 BuzzVote를 작성하려면 로그인하세요.';

  @override
  String reviewSubmitted(String rating, String buzzRating) {
    return '리뷰가 제출되었습니다\\! ⭐ $rating / 버즈 ⚡ $buzzRating';
  }

  @override
  String reviewSubmitFailed(String error) {
    return '리뷰를 제출할 수 없습니다: $error';
  }

  @override
  String get noExternalLink => '아직 이 항목에 사용할 수 있는 외부 링크가 없습니다.';

  @override
  String get unableToOpenLink => '지금은 이벤트 링크를 열 수 없습니다.';

  @override
  String shareTitle(String title) {
    return '공유: $title';
  }

  @override
  String get reportEvent => '이벤트 보고';

  @override
  String get reviewsOnlyForFood => '리뷰는 식품에만 가능합니다.';

  @override
  String get chooseFromGallery => '갤러리에서 선택';

  @override
  String get takeAPhoto => '사진을 찍으세요';

  @override
  String get pleaseLoginVisitor => '먼저 방문자로 로그인해주세요.';

  @override
  String get onlyJpgPng => 'JPG 및 PNG 이미지만 지원됩니다.';

  @override
  String get imageTooLarge => '이미지가 너무 큽니다. 더 작은 이미지를 선택해 주세요.';

  @override
  String get profilePictureUpdated => '프로필 사진이 업데이트되었습니다.';

  @override
  String get profilePictureUpdateFailed => '프로필 사진을 업데이트할 수 없습니다. 다시 시도해 주세요.';

  @override
  String get enterYourName => '이름을 입력하세요';

  @override
  String get phoneHint => '예를 들어 04xxxxxxxx';

  @override
  String get nameCannotBeEmpty => '이름은 비워둘 수 없습니다.';

  @override
  String get nameMinLength => '이름은 2자 이상이어야 합니다.';

  @override
  String get enterValidPhone => '유효한 전화번호를 입력하세요.';

  @override
  String get changeProfilePicture => '프로필 사진 변경';

  @override
  String get uploadProfilePicture => '프로필 사진 업로드';

  @override
  String get areYouSureSignOut => '정말로 로그아웃하시겠습니까?';

  @override
  String get returnWelcome => '시작 화면으로 돌아가기';

  @override
  String get setHowFarRecommendations => '추천 범위를 설정하세요.';

  @override
  String get themeTextSizeFeedback => '테마, 텍스트 크기 및 피드백';

  @override
  String get faqsContactAppInfo => '자주 묻는 질문(FAQ), 문의하기, 앱 정보';

  @override
  String get viewSubmittedFeedback => '제출된 피드백 및 관리자 응답 보기';

  @override
  String get discoverSubtitle => '현지 음식과 체험을 찾아보세요';

  @override
  String get searchHintLocalFood => '지역 식품업체 검색...';

  @override
  String get homeLabel => '홈';

  @override
  String get recommendedForYou => '당신에게 추천';

  @override
  String get seeAll => '모두 보기';

  @override
  String get categories => '카테고리';

  @override
  String get nearby => '주변';

  @override
  String get noFoodPlacesFound => '음식점을 찾을 수 없습니다.';

  @override
  String get noFoodPlacesSubtitle => '검색 또는 필터 선택을 변경해 보세요.';

  @override
  String get localFoodBusinesses => '지역식품 사업';

  @override
  String get localFoodSubtitle => '브리즈번 중소 식품 기업 지원';

  @override
  String get exploreReviewFoodBusinesses => '식품 사업 탐색 및 검토';

  @override
  String get noSavedItemsTitle => '아직 저장된 항목이 없습니다.';

  @override
  String get noSavedItemsSubtitle =>
      '음식 명함의 하트 아이콘이나 비즈니스 프로필의 북마크를 탭하여 여기에 저장하세요.';

  @override
  String get savedEvents => '저장된 이벤트';

  @override
  String get savedEventsSubtitle => '이벤트 알림 및 계획';

  @override
  String get savedAttractions => '저장된 명소';

  @override
  String get savedAttractionsSubtitle => '행사와 관계없이 방문할 수 있는 장소';

  @override
  String get savedBusinesses => '저장된 업체';

  @override
  String get savedBusinessesSubtitle => '북마크한 식품 업체';

  @override
  String get savedItemsUnavailableTitle => '저장된 항목을 사용할 수 없습니다.';

  @override
  String get savedItemsUnavailableSubtitle =>
      '일부 저장된 항목은 더 이상 검색 피드에 게시되지 않습니다.';

  @override
  String get retryAction => '재시도';

  @override
  String get unableToLoadDiscover => '지금은 검색 항목을 로드할 수 없습니다. 다시 시도해 주세요.';

  @override
  String get unableToLoadSaved => '지금은 저장된 항목을 로드할 수 없습니다. 다시 시도해 주세요.';

  @override
  String get dateTBA => '날짜 미정';

  @override
  String get timeTBA => '시간은 미정';

  @override
  String get untitledEvent => '제목 없는 이벤트';

  @override
  String get locationTBA => '위치 추후 공지';

  @override
  String get priceTBA => '가격 미정';

  @override
  String get placeFallback => '장소';

  @override
  String get foodExperienceFallback => '음식 체험';

  @override
  String get stadiumFallback => '경기장';

  @override
  String get eventFallback => '이벤트';

  @override
  String get attractionFallback => '명소';

  @override
  String ratingReviewsCount(String rating, String count) {
    return '$rating · $count 리뷰';
  }

  @override
  String get approved => '승인됨';

  @override
  String get audience => '청중';

  @override
  String get businessLabel => '비즈니스';

  @override
  String get controlDistance => '가까운 기회에 대한 거리 제어';

  @override
  String get dashboard => '대시보드';

  @override
  String get delete => '삭제';

  @override
  String get deleteEvent => '이벤트 삭제';

  @override
  String get deletingEvent => '일정 삭제 중...';

  @override
  String get displayName => '표시 이름';

  @override
  String errorDeletingEvent(String error) {
    return '일정 삭제 오류: $error';
  }

  @override
  String errorLoadingMap(String error) {
    return '지도 로드 중 오류 발생: $error';
  }

  @override
  String eventDeleted(String title) {
    return '이벤트 \"$title\"이(가) 삭제되었습니다.';
  }

  @override
  String get failedToDeleteEvent => '이벤트를 삭제하지 못했습니다. 다시 시도해 주세요.';

  @override
  String get feed => '피드';

  @override
  String get localBusinessPortal => '지역 비즈니스 포털';

  @override
  String get pending => '보류 중';

  @override
  String get phoneNumber => '전화번호';

  @override
  String get pleaseLoginLocal => '먼저 로컬 사용자로 로그인하세요.';

  @override
  String get pleaseLoginToDelete => '이벤트를 삭제하려면 로그인하세요.';

  @override
  String get pushAlerts => '귀하의 비즈니스에 대한 푸시 알림';

  @override
  String get rejected => '거부됨';

  @override
  String get reviews => '리뷰';

  @override
  String get saveChanges => '변경 사항 저장';

  @override
  String get searchHintEvents => '이벤트, 예약 검색...';

  @override
  String get suburb => '교외';

  @override
  String get thisLinkUnavailable => '이 링크는 현재 사용할 수 없습니다.';

  @override
  String get total => '합계';

  @override
  String get couldNotSaveSettings => '설정을 저장할 수 없습니다. 다시 시도해 주세요.';

  @override
  String get locationAccessDisabled => '앱 기능에 대한 위치 액세스가 비활성화되었습니다.';

  @override
  String get locationPermissionGranted => '위치 권한이 부여되었습니다.';

  @override
  String get openSettings => '설정 열기';

  @override
  String get themeDark => '어둠';

  @override
  String get themeLight => '빛';

  @override
  String get themeSystem => '시스템';

  @override
  String textScalePercent(String value) {
    return '$value%';
  }

  @override
  String categoryLabel(String category) {
    return '카테고리: $category';
  }

  @override
  String severityLabel(String severity) {
    return '심각도: $severity';
  }

  @override
  String get languageEnglish => '영어';

  @override
  String get languageSpanish => '스페인어';

  @override
  String get languageFrench => '프랑스어';

  @override
  String get languageGerman => '독일어';

  @override
  String get languageChinese => '중국어';

  @override
  String get languageArabic => '아랍어';

  @override
  String get languageHindi => '힌디어';

  @override
  String get languageItalian => '이탈리아어';

  @override
  String get languageJapanese => '일본어';

  @override
  String get languageKorean => '한국어';

  @override
  String get languagePortuguese => '포르투갈어';

  @override
  String get languageRussian => '러시아어';

  @override
  String get languageVietnamese => '베트남어';

  @override
  String get languageGreek => '그리스어';

  @override
  String get languagePunjabi => 'Punjabi';

  @override
  String get discoverTitle => '현지 음식을 발견해보세요';

  @override
  String get openSourceLink => '오픈 소스 링크';

  @override
  String get pendingApproval => '승인 보류 중';

  @override
  String deleteEventConfirmation(String title) {
    return '정말로 \"$title\"을(를) 삭제하시겠습니까? ';
  }

  @override
  String get myActivity => '내 활동';

  @override
  String get businessNotifications => '비즈니스 알림';

  @override
  String get about => '에 대한';

  @override
  String get aboutDescription =>
      'BrisConnect+는 방문자와 지역 주민이 이벤트를 발견하고 명소를 탐색하며 하나의 연결된 플랫폼에서 브리즈번 경험을 포착할 수 있도록 돕는 스마트 시티 가이드입니다.';

  @override
  String versionLabel(String version) {
    return '버전 $version';
  }

  @override
  String get locationPermissions => '위치 권한';

  @override
  String get enableLocationAccess => '위치 액세스 활성화';

  @override
  String get allowNearbyMapFeatures => '주변 추천 및 지도 인식 기능을 허용합니다.';

  @override
  String get locationSettings => '위치 설정';

  @override
  String get setSearchRadius => '이벤트 및 명소 검색 반경을 설정하세요.';

  @override
  String get pleaseLoginToViewSettings => '설정을 보려면 로그인하세요.';

  @override
  String get locationPermissionNotGranted =>
      '위치 권한이 부여되지 않았습니다. 시스템 설정에서 활성화할 수 있습니다.';

  @override
  String get theme => '주제';

  @override
  String get appTheme => '앱 테마';

  @override
  String get chooseHowAppLooks => '앱의 모양을 선택하세요.';

  @override
  String get textSize => '텍스트 크기';

  @override
  String get adjustTextSize => '앱 전체에서 텍스트 크기를 조정합니다.';

  @override
  String get smaller => '더 작게';

  @override
  String get larger => '더 크게';

  @override
  String get support => '지원하다';

  @override
  String get sendAppFeedback => '앱 피드백 보내기';

  @override
  String get reportBugsImprovements => '버그, 오해의 소지가 있는 정보 또는 개선 제안을 신고하세요.';

  @override
  String get noFeedbackYet => '아직 피드백을 제출하지 않았습니다.';

  @override
  String get adminResponse => '관리자 응답';

  @override
  String get awaitingAdminResponse => '관리자 응답을 기다리는 중...';

  @override
  String get statusPending => '보류 중';

  @override
  String get statusInProgress => '진행 중';

  @override
  String get statusResolved => '해결됨';

  @override
  String get statusWontFix => '수정되지 않음';

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
