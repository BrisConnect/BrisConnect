// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Vietnamese (`vi`).
class AppLocalizationsVi extends AppLocalizations {
  AppLocalizationsVi([String locale = 'vi']) : super(locale);

  @override
  String get appTitle => 'BrisConnect+';

  @override
  String get welcome => 'Chào mừng';

  @override
  String get signIn => 'Đăng nhập';

  @override
  String get signUp => 'Đăng ký';

  @override
  String get signOut => 'Đăng xuất';

  @override
  String get email => 'Email';

  @override
  String get password => 'Mật khẩu';

  @override
  String get phone => 'Điện thoại';

  @override
  String get name => 'Tên';

  @override
  String get save => 'Lưu';

  @override
  String get cancel => 'Hủy';

  @override
  String get editProfile => 'Chỉnh sửa hồ sơ';

  @override
  String get profileInfo => 'Thông tin hồ sơ';

  @override
  String get preferences => 'Tùy chọn';

  @override
  String get language => 'Ngôn ngữ';

  @override
  String get locationRadius => 'Bán kính vị trí';

  @override
  String get appearanceSettings => 'Giao diện';

  @override
  String get feedback => 'Phản hồi';

  @override
  String get myFeedback => 'Phản hồi của tôi';

  @override
  String get helpAndSupport => 'Trợ giúp & Hỗ trợ';

  @override
  String get discover => 'Khám phá';

  @override
  String get community => 'Cộng đồng';

  @override
  String get map => 'Bản đồ';

  @override
  String get saved => 'Đã lưu';

  @override
  String get profile => 'Hồ sơ';

  @override
  String get food => 'Ẩm thực';

  @override
  String get events => 'Sự kiện';

  @override
  String get businesses => 'Doanh nghiệp';

  @override
  String get promotions => 'Khuyến mãi';

  @override
  String get photos => 'Ảnh';

  @override
  String get newPost => 'Mới';

  @override
  String get search => 'Tìm kiếm';

  @override
  String get filter => 'Lọc';

  @override
  String get clearFilters => 'Xóa bộ lọc';

  @override
  String get noResults => 'Không tìm thấy kết quả';

  @override
  String get loading => 'Đang tải...';

  @override
  String get error => 'Lỗi';

  @override
  String get success => 'Thành công';

  @override
  String get profileUpdated => 'Hồ sơ đã được cập nhật.';

  @override
  String get profileUpdateFailed =>
      'Không thể cập nhật hồ sơ. Vui lòng thử lại.';

  @override
  String get guestVisitor => 'Khách tham quan';

  @override
  String get localUser => 'Địa phương';

  @override
  String get filterEventsTitle => 'Lọc sự kiện';

  @override
  String get priceLabel => 'Giá';

  @override
  String get dateLabel => 'Ngày';

  @override
  String get pickADate => 'Chọn một ngày';

  @override
  String get resetButton => 'Đặt lại';

  @override
  String get applyButton => 'Áp dụng';

  @override
  String get freeLabel => 'miễn phí';

  @override
  String get paidLabel => 'Đã trả tiền';

  @override
  String eventSavedToInterested(String eventTitle) {
    return '$eventTitle đã lưu vào Quan tâm.';
  }

  @override
  String eventRemovedFromInterested(String eventTitle) {
    return '$eventTitle đã bị xóa khỏi Quan tâm.';
  }

  @override
  String savedToAttractions(String title) {
    return '$title đã lưu vào Điểm tham quan đã lưu.';
  }

  @override
  String removedFromAttractions(String title) {
    return '$title đã bị xóa khỏi Điểm tham quan đã lưu.';
  }

  @override
  String get pleaseSignInToSaveEvents =>
      'Vui lòng đăng nhập với tư cách là Khách truy cập để lưu sự kiện.';

  @override
  String get pleaseSignInToReview =>
      'Vui lòng đăng nhập để viết đánh giá hoặc BuzzVote.';

  @override
  String reviewSubmitted(String rating, String buzzRating) {
    return 'Đã gửi đánh giá\\! ⭐ $rating / Buzz ⚡ $buzzRating';
  }

  @override
  String reviewSubmitFailed(String error) {
    return 'Không thể gửi đánh giá: $error';
  }

  @override
  String get noExternalLink =>
      'Không có liên kết bên ngoài có sẵn cho mục này.';

  @override
  String get unableToOpenLink => 'Không thể mở liên kết sự kiện ngay bây giờ.';

  @override
  String shareTitle(String title) {
    return 'Chia sẻ: $title';
  }

  @override
  String get reportEvent => 'Báo cáo sự kiện';

  @override
  String get reviewsOnlyForFood =>
      'Đánh giá chỉ có sẵn cho các mặt hàng thực phẩm';

  @override
  String get chooseFromGallery => 'Chọn từ thư viện';

  @override
  String get takeAPhoto => 'Chụp ảnh';

  @override
  String get pleaseLoginVisitor =>
      'Vui lòng đăng nhập với tư cách là Khách truy cập trước.';

  @override
  String get onlyJpgPng => 'Chỉ hỗ trợ hình ảnh JPG và PNG.';

  @override
  String get imageTooLarge =>
      'Hình ảnh quá lớn. Vui lòng chọn một hình ảnh nhỏ hơn.';

  @override
  String get profilePictureUpdated => 'Ảnh hồ sơ được cập nhật thành công.';

  @override
  String get profilePictureUpdateFailed =>
      'Không thể cập nhật ảnh hồ sơ. Vui lòng thử lại.';

  @override
  String get enterYourName => 'Nhập tên của bạn';

  @override
  String get phoneHint => 'ví dụ: 04xxxxxxxxx';

  @override
  String get nameCannotBeEmpty => 'Tên không được để trống.';

  @override
  String get nameMinLength => 'Tên phải có ít nhất 2 ký tự.';

  @override
  String get enterValidPhone => 'Nhập số điện thoại hợp lệ.';

  @override
  String get changeProfilePicture => 'Thay đổi ảnh hồ sơ';

  @override
  String get uploadProfilePicture => 'Tải ảnh hồ sơ lên';

  @override
  String get areYouSureSignOut => 'Bạn có chắc chắn muốn đăng xuất không?';

  @override
  String get returnWelcome => 'Quay lại màn hình chào mừng';

  @override
  String get setHowFarRecommendations =>
      'Đặt khoảng cách có thể đưa ra đề xuất';

  @override
  String get themeTextSizeFeedback => 'Chủ đề, kích thước văn bản và phản hồi';

  @override
  String get faqsContactAppInfo =>
      'Câu hỏi thường gặp, liên hệ với chúng tôi và thông tin ứng dụng';

  @override
  String get viewSubmittedFeedback =>
      'Xem phản hồi đã gửi của bạn và phản hồi của quản trị viên';

  @override
  String get discoverSubtitle => 'Khám phá ẩm thực và trải nghiệm địa phương';

  @override
  String get searchHintLocalFood =>
      'Tìm kiếm các doanh nghiệp thực phẩm địa phương...';

  @override
  String get homeLabel => 'Trang chủ';

  @override
  String get recommendedForYou => 'Đề xuất cho bạn';

  @override
  String get seeAll => 'Xem Tất Cả';

  @override
  String get categories => 'Danh mục';

  @override
  String get nearby => 'lân cận';

  @override
  String get noFoodPlacesFound => 'Không tìm thấy địa điểm ăn uống nào';

  @override
  String get noFoodPlacesSubtitle =>
      'Hãy thử thay đổi lựa chọn tìm kiếm hoặc bộ lọc của bạn.';

  @override
  String get localFoodBusinesses => 'Doanh nghiệp thực phẩm địa phương';

  @override
  String get localFoodSubtitle =>
      'Hỗ trợ các doanh nghiệp thực phẩm vừa và nhỏ ở Brisbane';

  @override
  String get exploreReviewFoodBusinesses =>
      'Khám phá và đánh giá các doanh nghiệp thực phẩm';

  @override
  String get noSavedItemsTitle => 'Chưa có mục nào được lưu';

  @override
  String get noSavedItemsSubtitle =>
      'Nhấn vào biểu tượng trái tim trên danh thiếp thực phẩm hoặc dấu trang trên hồ sơ doanh nghiệp để lưu chúng tại đây.';

  @override
  String get savedEvents => 'Sự kiện đã lưu';

  @override
  String get savedEventsSubtitle => 'Lời nhắc và kế hoạch sự kiện của bạn';

  @override
  String get savedAttractions => 'Điểm tham quan đã lưu';

  @override
  String get savedAttractionsSubtitle =>
      'Địa điểm tham quan độc lập với các sự kiện';

  @override
  String get savedBusinesses => 'Doanh nghiệp đã lưu';

  @override
  String get savedBusinessesSubtitle =>
      'Các doanh nghiệp thực phẩm bạn đã đánh dấu';

  @override
  String get savedItemsUnavailableTitle => 'Các mục đã lưu không có sẵn';

  @override
  String get savedItemsUnavailableSubtitle =>
      'Một số mục đã lưu không còn được xuất bản trong nguồn cấp dữ liệu khám phá nữa.';

  @override
  String get retryAction => 'Thử lại';

  @override
  String get unableToLoadDiscover =>
      'Không thể tải các mục khám phá ngay bây giờ. Vui lòng thử lại.';

  @override
  String get unableToLoadSaved =>
      'Không thể tải các mục đã lưu ngay bây giờ. Vui lòng thử lại.';

  @override
  String get dateTBA => 'Ngày TBA';

  @override
  String get timeTBA => 'thời gian TBA';

  @override
  String get untitledEvent => 'Sự kiện không có tiêu đề';

  @override
  String get locationTBA => 'Vị trí TBA';

  @override
  String get priceTBA => 'Giá TBA';

  @override
  String get placeFallback => 'Địa điểm';

  @override
  String get foodExperienceFallback => 'Trải nghiệm ẩm thực';

  @override
  String get stadiumFallback => 'Sân vận động';

  @override
  String get eventFallback => 'Sự kiện';

  @override
  String get attractionFallback => 'Sự hấp dẫn';

  @override
  String ratingReviewsCount(String rating, String count) {
    return '$rating · $count đánh giá';
  }

  @override
  String get approved => 'Đã được phê duyệt';

  @override
  String get audience => 'Khán giả';

  @override
  String get businessLabel => 'Kinh doanh';

  @override
  String get controlDistance => 'Kiểm soát khoảng cách cho các cơ hội lân cận';

  @override
  String get dashboard => 'Trang tổng quan';

  @override
  String get delete => 'Xóa';

  @override
  String get deleteEvent => 'Xóa sự kiện';

  @override
  String get deletingEvent => 'Đang xóa sự kiện...';

  @override
  String get displayName => 'Tên hiển thị';

  @override
  String errorDeletingEvent(String error) {
    return 'Lỗi xóa sự kiện: $error';
  }

  @override
  String errorLoadingMap(String error) {
    return 'Lỗi tải bản đồ: $error';
  }

  @override
  String eventDeleted(String title) {
    return 'Sự kiện \"$title\" đã bị xóa.';
  }

  @override
  String get failedToDeleteEvent => 'Không thể xóa sự kiện. Vui lòng thử lại.';

  @override
  String get feed => 'Nguồn cấp dữ liệu';

  @override
  String get localBusinessPortal => 'Cổng thông tin doanh nghiệp địa phương';

  @override
  String get pending => 'Đang chờ xử lý';

  @override
  String get phoneNumber => 'Số điện thoại';

  @override
  String get pleaseLoginLocal =>
      'Vui lòng đăng nhập với tư cách là người dùng cục bộ trước.';

  @override
  String get pleaseLoginToDelete => 'Vui lòng đăng nhập để xóa sự kiện.';

  @override
  String get pushAlerts => 'Đẩy thông báo cho doanh nghiệp của bạn';

  @override
  String get rejected => 'Bị từ chối';

  @override
  String get reviews => 'Đánh giá';

  @override
  String get saveChanges => 'Lưu thay đổi';

  @override
  String get searchHintEvents => 'Tìm kiếm sự kiện, đặt chỗ...';

  @override
  String get suburb => 'Ngoại ô';

  @override
  String get thisLinkUnavailable => 'Liên kết này hiện không có sẵn.';

  @override
  String get total => 'Tổng cộng';

  @override
  String get couldNotSaveSettings => 'Không thể lưu cài đặt. Vui lòng thử lại.';

  @override
  String get locationAccessDisabled =>
      'Quyền truy cập vị trí bị vô hiệu hóa đối với các tính năng của ứng dụng.';

  @override
  String get locationPermissionGranted => 'Đã cấp quyền truy cập vị trí.';

  @override
  String get openSettings => 'Mở cài đặt';

  @override
  String get themeDark => 'Tối';

  @override
  String get themeLight => 'Ánh sáng';

  @override
  String get themeSystem => 'Hệ thống';

  @override
  String textScalePercent(String value) {
    return '$value%';
  }

  @override
  String categoryLabel(String category) {
    return 'Danh mục: $category';
  }

  @override
  String severityLabel(String severity) {
    return 'Mức độ nghiêm trọng: $severity';
  }

  @override
  String get languageEnglish => 'Tiếng Anh';

  @override
  String get languageSpanish => 'tiếng Tây Ban Nha';

  @override
  String get languageFrench => 'người Pháp';

  @override
  String get languageGerman => 'tiếng Đức';

  @override
  String get languageChinese => 'Tiếng Trung';

  @override
  String get languageArabic => 'tiếng Ả Rập';

  @override
  String get languageHindi => 'Tiếng Hindi';

  @override
  String get languageItalian => 'người Ý';

  @override
  String get languageJapanese => 'tiếng Nhật';

  @override
  String get languageKorean => 'Tiếng Hàn';

  @override
  String get languagePortuguese => 'tiếng Bồ Đào Nha';

  @override
  String get languageRussian => 'tiếng Nga';

  @override
  String get languageVietnamese => 'Tiếng Việt';

  @override
  String get languageGreek => 'tiếng Hy Lạp';

  @override
  String get discoverTitle => 'Khám phá ẩm thực địa phương';

  @override
  String get openSourceLink => 'Liên kết nguồn mở';

  @override
  String get pendingApproval => 'Đang chờ phê duyệt';

  @override
  String deleteEventConfirmation(String title) {
    return 'Bạn có chắc chắn muốn xóa \"$title\" không? ';
  }

  @override
  String get myActivity => 'Hoạt động của tôi';

  @override
  String get businessNotifications => 'Thông báo kinh doanh';

  @override
  String get about => 'Về';

  @override
  String get aboutDescription =>
      'BrisConnect+ là hướng dẫn thành phố thông minh giúp du khách và người dân địa phương khám phá các sự kiện, khám phá các điểm tham quan và ghi lại trải nghiệm Brisbane của họ trong một nền tảng được kết nối.';

  @override
  String versionLabel(String version) {
    return 'Phiên bản $version';
  }

  @override
  String get locationPermissions => 'Quyền vị trí';

  @override
  String get enableLocationAccess => 'Bật quyền truy cập vị trí';

  @override
  String get allowNearbyMapFeatures =>
      'Cho phép đề xuất lân cận và các tính năng nhận biết bản đồ.';

  @override
  String get locationSettings => 'Cài đặt vị trí';

  @override
  String get setSearchRadius =>
      'Đặt bán kính tìm kiếm của bạn cho các sự kiện và điểm tham quan.';

  @override
  String get pleaseLoginToViewSettings => 'Vui lòng đăng nhập để xem cài đặt.';

  @override
  String get locationPermissionNotGranted =>
      'Quyền vị trí không được cấp. Bạn có thể kích hoạt nó trong cài đặt hệ thống.';

  @override
  String get theme => 'chủ đề';

  @override
  String get appTheme => 'Chủ đề ứng dụng';

  @override
  String get chooseHowAppLooks => 'Chọn giao diện của ứng dụng.';

  @override
  String get textSize => 'Kích thước văn bản';

  @override
  String get adjustTextSize => 'Điều chỉnh kích thước văn bản trên ứng dụng.';

  @override
  String get smaller => 'Nhỏ hơn';

  @override
  String get larger => 'lớn hơn';

  @override
  String get support => 'Ủng hộ';

  @override
  String get sendAppFeedback => 'Gửi phản hồi về ứng dụng';

  @override
  String get reportBugsImprovements =>
      'Báo cáo lỗi, thông tin sai lệch hoặc đề xuất cải tiến.';

  @override
  String get noFeedbackYet => 'Bạn chưa gửi bất kỳ phản hồi nào.';

  @override
  String get adminResponse => 'Phản hồi của quản trị viên';

  @override
  String get awaitingAdminResponse => 'Đang chờ phản hồi của quản trị viên...';

  @override
  String get statusPending => 'Chưa giải quyết';

  @override
  String get statusInProgress => 'Đang tiến hành';

  @override
  String get statusResolved => 'Đã giải quyết';

  @override
  String get statusWontFix => 'Sẽ không sửa chữa';
}
