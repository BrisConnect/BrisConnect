// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'BrisConnect+';

  @override
  String get welcome => '欢迎';

  @override
  String get signIn => '登录';

  @override
  String get signUp => '注册';

  @override
  String get signOut => '退出登录';

  @override
  String get email => '电子邮件';

  @override
  String get password => '密码';

  @override
  String get phone => '电话';

  @override
  String get name => '姓名';

  @override
  String get save => '保存';

  @override
  String get cancel => '取消';

  @override
  String get editProfile => '编辑个人资料';

  @override
  String get profileInfo => '个人资料信息';

  @override
  String get preferences => '偏好设置';

  @override
  String get language => '语言';

  @override
  String get locationRadius => '位置半径';

  @override
  String get appearanceSettings => '外观设置';

  @override
  String get feedback => '反馈';

  @override
  String get myFeedback => '我的反馈';

  @override
  String get helpAndSupport => '帮助与支持';

  @override
  String get discover => '发现';

  @override
  String get community => '社区';

  @override
  String get map => '地图';

  @override
  String get saved => '已保存';

  @override
  String get profile => '个人资料';

  @override
  String get food => '美食';

  @override
  String get events => '活动';

  @override
  String get businesses => '商家';

  @override
  String get promotions => '促销';

  @override
  String get photos => '照片';

  @override
  String get newPost => '最新';

  @override
  String get search => '搜索';

  @override
  String get filter => '筛选';

  @override
  String get clearFilters => '清除筛选';

  @override
  String get noResults => '未找到结果';

  @override
  String get loading => '加载中...';

  @override
  String get error => '错误';

  @override
  String get success => '成功';

  @override
  String get profileUpdated => '个人资料更新成功。';

  @override
  String get profileUpdateFailed => '无法更新个人资料。请重试。';

  @override
  String get guestVisitor => '访客';

  @override
  String get localUser => '当地的';

  @override
  String get filterEventsTitle => '过滤事件';

  @override
  String get priceLabel => '价格';

  @override
  String get dateLabel => '日期';

  @override
  String get pickADate => '选择日期';

  @override
  String get resetButton => '重置';

  @override
  String get applyButton => '申请';

  @override
  String get freeLabel => '免费';

  @override
  String get paidLabel => '付费';

  @override
  String eventSavedToInterested(String eventTitle) {
    return '$eventTitle 已保存到“感兴趣”。';
  }

  @override
  String eventRemovedFromInterested(String eventTitle) {
    return '$eventTitle 从“感兴趣”中删除。';
  }

  @override
  String savedToAttractions(String title) {
    return '$title 已保存到已保存的景点。';
  }

  @override
  String removedFromAttractions(String title) {
    return '$title 已从保存的景点中删除。';
  }

  @override
  String get pleaseSignInToSaveEvents => '请以访客身份登录以保存活动。';

  @override
  String get pleaseSignInToReview => '请登录以撰写评论或 BuzzVote。';

  @override
  String reviewSubmitted(String rating, String buzzRating) {
    return '审核已提交\\! ⭐ $rating / 嗡嗡声 ⚡ $buzzRating';
  }

  @override
  String reviewSubmitFailed(String error) {
    return '无法提交评论：$error';
  }

  @override
  String get noExternalLink => '该商品尚无可用的外部链接。';

  @override
  String get unableToOpenLink => '目前无法打开活动链接。';

  @override
  String shareTitle(String title) {
    return '分享：$title';
  }

  @override
  String get reportEvent => '报告事件';

  @override
  String get reviewsOnlyForFood => '评论仅适用于食品';

  @override
  String get chooseFromGallery => '从画廊中选择';

  @override
  String get takeAPhoto => '拍张照片';

  @override
  String get pleaseLoginVisitor => '请先以访客身份登录。';

  @override
  String get onlyJpgPng => '仅支持 JPG 和 PNG 图像。';

  @override
  String get imageTooLarge => '图片太大。请选择较小的图像。';

  @override
  String get profilePictureUpdated => '个人资料图片更新成功。';

  @override
  String get profilePictureUpdateFailed => '无法更新个人资料图片。请再试一次。';

  @override
  String get enterYourName => '输入你的名字';

  @override
  String get phoneHint => '例如04xxxxxxxx';

  @override
  String get nameCannotBeEmpty => '名称不能为空。';

  @override
  String get nameMinLength => '名称必须至少包含 2 个字符。';

  @override
  String get enterValidPhone => '输入有效的电话号码。';

  @override
  String get changeProfilePicture => '更改个人资料图片';

  @override
  String get uploadProfilePicture => '上传个人资料图片';

  @override
  String get areYouSureSignOut => '您确定要退出吗？';

  @override
  String get returnWelcome => '返回欢迎屏幕';

  @override
  String get setHowFarRecommendations => '设置推荐的范围';

  @override
  String get themeTextSizeFeedback => '主题、文字大小和反馈';

  @override
  String get faqsContactAppInfo => '常见问题解答、联系我们和应用程序信息';

  @override
  String get viewSubmittedFeedback => '查看您提交的反馈和管理员回复';

  @override
  String get discoverSubtitle => '探索当地美食和体验';

  @override
  String get searchHintLocalFood => '搜索当地食品企业...';

  @override
  String get homeLabel => '首页';

  @override
  String get recommendedForYou => '为您推荐';

  @override
  String get seeAll => '查看全部';

  @override
  String get categories => '类别';

  @override
  String get nearby => '附近';

  @override
  String get noFoodPlacesFound => '没有找到吃饭的地方';

  @override
  String get noFoodPlacesSubtitle => '尝试更改您的搜索或过滤器选择。';

  @override
  String get localFoodBusinesses => '当地食品企业';

  @override
  String get localFoodSubtitle => '支持布里斯班中小型食品企业';

  @override
  String get exploreReviewFoodBusinesses => '探索和回顾食品企业';

  @override
  String get noSavedItemsTitle => '还没有保存的项目';

  @override
  String get noSavedItemsSubtitle => '点击食品名片上的心形图标或企业资料上的书签，将其保存在此处。';

  @override
  String get savedEvents => '已保存的活动';

  @override
  String get savedEventsSubtitle => '您的活动提醒和计划';

  @override
  String get savedAttractions => '已保存的景点';

  @override
  String get savedAttractionsSubtitle => '与活动无关的参观地点';

  @override
  String get savedBusinesses => '已保存的企业';

  @override
  String get savedBusinessesSubtitle => '您已添加书签的食品企业';

  @override
  String get savedItemsUnavailableTitle => '已保存的项目不可用';

  @override
  String get savedItemsUnavailableSubtitle => '某些已保存的项目不再在发现源中发布。';

  @override
  String get retryAction => '重试';

  @override
  String get unableToLoadDiscover => '目前无法加载发现项目。请再试一次。';

  @override
  String get unableToLoadSaved => '现在无法加载已保存的项目。请再试一次。';

  @override
  String get dateTBA => '日期待定';

  @override
  String get timeTBA => '时间待定';

  @override
  String get untitledEvent => '无标题活动';

  @override
  String get locationTBA => '地点待定';

  @override
  String get priceTBA => '价格待定';

  @override
  String get placeFallback => '地点';

  @override
  String get foodExperienceFallback => '美食体验';

  @override
  String get stadiumFallback => '体育场';

  @override
  String get eventFallback => '活动';

  @override
  String get attractionFallback => '景点';

  @override
  String ratingReviewsCount(String rating, String count) {
    return '$rating · $count 评论';
  }

  @override
  String get approved => '已批准';

  @override
  String get audience => '观众';

  @override
  String get businessLabel => '商务';

  @override
  String get controlDistance => '控制距离以寻找附近的机会';

  @override
  String get dashboard => '仪表板';

  @override
  String get delete => '删除';

  @override
  String get deleteEvent => '删除事件';

  @override
  String get deletingEvent => '正在删除活动...';

  @override
  String get displayName => '显示名称';

  @override
  String errorDeletingEvent(String error) {
    return '删除事件时出错：$error';
  }

  @override
  String errorLoadingMap(String error) {
    return '加载地图时出错：$error';
  }

  @override
  String eventDeleted(String title) {
    return '事件“$title”已被删除。';
  }

  @override
  String get failedToDeleteEvent => '删除事件失败。请再试一次。';

  @override
  String get feed => '饲料';

  @override
  String get localBusinessPortal => '本地商业门户';

  @override
  String get pending => '待定';

  @override
  String get phoneNumber => '电话号码';

  @override
  String get pleaseLoginLocal => '请先以本地用户身份登录。';

  @override
  String get pleaseLoginToDelete => '请登录以删除事件。';

  @override
  String get pushAlerts => '为您的企业推送警报';

  @override
  String get rejected => '被拒绝';

  @override
  String get reviews => '评论';

  @override
  String get saveChanges => '保存更改';

  @override
  String get searchHintEvents => '搜索活动、预订...';

  @override
  String get suburb => '郊区';

  @override
  String get thisLinkUnavailable => '此链接目前不可用。';

  @override
  String get total => '总计';

  @override
  String get couldNotSaveSettings => '无法保存设置。请再试一次。';

  @override
  String get locationAccessDisabled => '应用程序功能禁用位置访问。';

  @override
  String get locationPermissionGranted => '已授予位置许可。';

  @override
  String get openSettings => '打开设置';

  @override
  String get themeDark => '黑暗';

  @override
  String get themeLight => '光';

  @override
  String get themeSystem => '系统';

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
  String get languageEnglish => '英语';

  @override
  String get languageSpanish => '西班牙语';

  @override
  String get languageFrench => '法语';

  @override
  String get languageGerman => '德语';

  @override
  String get languageChinese => '中文';

  @override
  String get languageArabic => '阿拉伯语';

  @override
  String get languageHindi => '印地语';

  @override
  String get languageItalian => '意大利语';

  @override
  String get languageJapanese => '日语';

  @override
  String get languageKorean => '韩语';

  @override
  String get languagePortuguese => '葡萄牙语';

  @override
  String get languageRussian => '俄语';

  @override
  String get languageVietnamese => '越南语';

  @override
  String get languageGreek => '希腊语';

  @override
  String get languagePunjabi => '旁遮普语';

  @override
  String get discoverTitle => '探索当地美食';

  @override
  String get openSourceLink => '开源链接';

  @override
  String get pendingApproval => '待批准';

  @override
  String deleteEventConfirmation(String title) {
    return '您确定要删除“$title”吗？';
  }

  @override
  String get myActivity => '我的活动';

  @override
  String get businessNotifications => '业务通知';

  @override
  String get about => '关于';

  @override
  String get aboutDescription =>
      'BrisConnect+ 是一款智能城市指南，可帮助游客和当地人在一个互联平台上发现活动、探索景点并捕捉他们的布里斯班体验。';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get locationPermissions => '位置权限';

  @override
  String get enableLocationAccess => '启用位置访问';

  @override
  String get allowNearbyMapFeatures => '允许附近的推荐和地图感知功能。';

  @override
  String get locationSettings => '位置设置';

  @override
  String get setSearchRadius => '设置活动和景点的搜索半径。';

  @override
  String get pleaseLoginToViewSettings => '请登录查看设置。';

  @override
  String get locationPermissionNotGranted => '未授予位置许可。您可以在系统设置中启用它。';

  @override
  String get theme => '主题';

  @override
  String get appTheme => '应用主题';

  @override
  String get chooseHowAppLooks => '选择应用程序的外观。';

  @override
  String get textSize => '文字大小';

  @override
  String get adjustTextSize => '调整整个应用程序的文本大小。';

  @override
  String get smaller => '较小';

  @override
  String get larger => '较大';

  @override
  String get support => '支持';

  @override
  String get sendAppFeedback => '发送应用程序反馈';

  @override
  String get reportBugsImprovements => '报告错误、误导性信息或改进建议。';

  @override
  String get noFeedbackYet => '您尚未提交任何反馈。';

  @override
  String get adminResponse => '管理员回应';

  @override
  String get awaitingAdminResponse => '等待管理员回复...';

  @override
  String get statusPending => '待办的';

  @override
  String get statusInProgress => '进行中';

  @override
  String get statusResolved => '已解决';

  @override
  String get statusWontFix => '不会修复';

  @override
  String get foodBusinessDetails => '商家详情';

  @override
  String get aboutThisFoodExperience => '关于此美食体验';

  @override
  String get highlights => '亮点';

  @override
  String get contactAndLinks => '联系方式与链接';

  @override
  String get gallery => '图库';

  @override
  String get openingHours => '营业时间';

  @override
  String get menu => '菜单';

  @override
  String get menuFallback => '菜单';

  @override
  String get call => '致电';

  @override
  String get website => '网站';

  @override
  String get orderOnline => '在线订购';

  @override
  String get viewOnMap => '在地图上查看';

  @override
  String get foodDiscoveryGuide => '美食探索指南';

  @override
  String get foodDiscoveryGuideHelper => '点击播放，让美食探索指南为您介绍这个美食地点及其亮点。';

  @override
  String get stop => '停止';

  @override
  String get unableToStartNarration => '目前无法开始美食探索指南语音介绍。';

  @override
  String get unableToCallNumber => '目前无法拨打此号码。';

  @override
  String get unableToSendEmail => '目前无法发送邮件。';

  @override
  String get foodSpotCannotBeShared => '目前无法分享此美食地点。';

  @override
  String foodDescriptionIntro(String title, String cuisine, String location) {
    return 'Step into $title, a $cuisine destination in the heart of $location.';
  }

  @override
  String foodDescriptionRating(String rating) {
    return '深受当地居民和游客喜爱，评分为$rating星。';
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
    return '无论是悠闲的早午餐、商务午餐还是热闹的晚餐，$title都能为您提供温馨的氛围和体现布里斯班餐饮风情的美味。';
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
