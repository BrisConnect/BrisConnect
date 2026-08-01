// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get appTitle => 'BrisConnect+';

  @override
  String get welcome => 'Добро пожаловать';

  @override
  String get signIn => 'Войти';

  @override
  String get signUp => 'Зарегистрироваться';

  @override
  String get signOut => 'Выйти';

  @override
  String get email => 'Электронная почта';

  @override
  String get password => 'Пароль';

  @override
  String get phone => 'Телефон';

  @override
  String get name => 'Имя';

  @override
  String get save => 'Сохранить';

  @override
  String get cancel => 'Отмена';

  @override
  String get editProfile => 'Редактировать профиль';

  @override
  String get profileInfo => 'Информация профиля';

  @override
  String get preferences => 'Настройки';

  @override
  String get language => 'Язык';

  @override
  String get locationRadius => 'Радиус местоположения';

  @override
  String get appearanceSettings => 'Настройки внешнего вида';

  @override
  String get feedback => 'Обратная связь';

  @override
  String get myFeedback => 'Моя обратная связь';

  @override
  String get helpAndSupport => 'Помощь и поддержка';

  @override
  String get discover => 'Исследовать';

  @override
  String get community => 'Сообщество';

  @override
  String get map => 'Карта';

  @override
  String get saved => 'Сохранено';

  @override
  String get profile => 'Профиль';

  @override
  String get food => 'Еда';

  @override
  String get events => 'События';

  @override
  String get businesses => 'Бизнес';

  @override
  String get promotions => 'Акции';

  @override
  String get photos => 'Фото';

  @override
  String get newPost => 'Новое';

  @override
  String get search => 'Поиск';

  @override
  String get filter => 'Фильтр';

  @override
  String get clearFilters => 'Очистить фильтры';

  @override
  String get noResults => 'Результаты не найдены';

  @override
  String get loading => 'Загрузка...';

  @override
  String get error => 'Ошибка';

  @override
  String get success => 'Успех';

  @override
  String get profileUpdated => 'Профиль успешно обновлён.';

  @override
  String get profileUpdateFailed =>
      'Не удалось обновить профиль. Попробуйте ещё раз.';

  @override
  String get guestVisitor => 'Гость';

  @override
  String get localUser => 'Местный';

  @override
  String get filterEventsTitle => 'Фильтровать события';

  @override
  String get priceLabel => 'Цена';

  @override
  String get dateLabel => 'Дата';

  @override
  String get pickADate => 'Выберите дату';

  @override
  String get resetButton => 'Сброс';

  @override
  String get applyButton => 'Применить';

  @override
  String get freeLabel => 'Бесплатно';

  @override
  String get paidLabel => 'Платный';

  @override
  String eventSavedToInterested(String eventTitle) {
    return '$eventTitle сохранено в разделе «Интересно».';
  }

  @override
  String eventRemovedFromInterested(String eventTitle) {
    return '$eventTitle удален из списка «Интересно».';
  }

  @override
  String savedToAttractions(String title) {
    return '$title сохранен в папке «Сохраненные достопримечательности».';
  }

  @override
  String removedFromAttractions(String title) {
    return '$title удален из сохраненных достопримечательностей.';
  }

  @override
  String get pleaseSignInToSaveEvents =>
      'Пожалуйста, войдите в систему как посетитель, чтобы сохранять события.';

  @override
  String get pleaseSignInToReview =>
      'Пожалуйста, войдите, чтобы написать отзыв или BuzzVote.';

  @override
  String reviewSubmitted(String rating, String buzzRating) {
    return 'Отзыв отправлен\\! ⭐ $rating / Живая информация ⚡ $buzzRating';
  }

  @override
  String reviewSubmitFailed(String error) {
    return 'Не удалось отправить отзыв: $error';
  }

  @override
  String get noExternalLink => 'Для этого элемента пока нет внешней ссылки.';

  @override
  String get unableToOpenLink =>
      'Сейчас невозможно открыть ссылку на мероприятие.';

  @override
  String shareTitle(String title) {
    return 'Поделиться: $title';
  }

  @override
  String get reportEvent => 'Сообщить о событии';

  @override
  String get reviewsOnlyForFood =>
      'Отзывы доступны только для продуктов питания.';

  @override
  String get chooseFromGallery => 'Выбрать из галереи';

  @override
  String get takeAPhoto => 'Сфотографироваться';

  @override
  String get pleaseLoginVisitor =>
      'Пожалуйста, сначала войдите в систему как посетитель.';

  @override
  String get onlyJpgPng => 'Поддерживаются только изображения JPG и PNG.';

  @override
  String get imageTooLarge =>
      'Изображение слишком велико. Пожалуйста, выберите изображение меньшего размера.';

  @override
  String get profilePictureUpdated => 'Изображение профиля успешно обновлено.';

  @override
  String get profilePictureUpdateFailed =>
      'Не удалось обновить изображение профиля. Пожалуйста, попробуйте еще раз.';

  @override
  String get enterYourName => 'Введите свое имя';

  @override
  String get phoneHint => 'например 04хххххххх';

  @override
  String get nameCannotBeEmpty => 'Имя не может быть пустым.';

  @override
  String get nameMinLength => 'Имя должно состоять минимум из 2 символов.';

  @override
  String get enterValidPhone => 'Введите действительный номер телефона.';

  @override
  String get changeProfilePicture => 'Изменить изображение профиля';

  @override
  String get uploadProfilePicture => 'Загрузить изображение профиля';

  @override
  String get areYouSureSignOut => 'Вы уверены, что хотите выйти?';

  @override
  String get returnWelcome => 'Вернуться к экрану приветствия';

  @override
  String get setHowFarRecommendations =>
      'Установите, насколько далеко могут распространяться рекомендации';

  @override
  String get themeTextSizeFeedback => 'Тема, размер текста и отзывы';

  @override
  String get faqsContactAppInfo =>
      'Часто задаваемые вопросы, свяжитесь с нами и информация о приложении';

  @override
  String get viewSubmittedFeedback =>
      'Просмотр отправленных вами отзывов и ответов администратора';

  @override
  String get discoverSubtitle => 'Откройте для себя местную еду и впечатления';

  @override
  String get searchHintLocalFood =>
      'Найдите местные предприятия общественного питания...';

  @override
  String get homeLabel => 'Главная';

  @override
  String get recommendedForYou => 'Рекомендуется для вас';

  @override
  String get seeAll => 'Посмотреть все';

  @override
  String get categories => 'Категории';

  @override
  String get nearby => 'Рядом';

  @override
  String get noFoodPlacesFound => 'Мест с едой не найдено';

  @override
  String get noFoodPlacesSubtitle =>
      'Попробуйте изменить параметры поиска или фильтра.';

  @override
  String get localFoodBusinesses => 'Местные продовольственные предприятия';

  @override
  String get localFoodSubtitle =>
      'Поддержите малые и средние пищевые предприятия Брисбена';

  @override
  String get exploreReviewFoodBusinesses =>
      'Изучите и сделайте обзор предприятий пищевой промышленности';

  @override
  String get noSavedItemsTitle => 'Пока нет сохраненных элементов';

  @override
  String get noSavedItemsSubtitle =>
      'Коснитесь значка сердечка на визитных карточках с едой или закладки в бизнес-профиле, чтобы сохранить их здесь.';

  @override
  String get savedEvents => 'Сохраненные события';

  @override
  String get savedEventsSubtitle => 'Напоминания и планы ваших мероприятий';

  @override
  String get savedAttractions => 'Сохраненные достопримечательности';

  @override
  String get savedAttractionsSubtitle =>
      'Места для посещения независимо от событий';

  @override
  String get savedBusinesses => 'Сохраненные предприятия';

  @override
  String get savedBusinessesSubtitle =>
      'Пищевые предприятия, которые вы добавили в закладки';

  @override
  String get savedItemsUnavailableTitle => 'Сохраненные элементы недоступны.';

  @override
  String get savedItemsUnavailableSubtitle =>
      'Некоторые сохраненные элементы больше не публикуются в ленте открытий.';

  @override
  String get retryAction => 'Повторить попытку';

  @override
  String get unableToLoadDiscover =>
      'Невозможно загрузить обнаруженные элементы прямо сейчас. Пожалуйста, попробуйте еще раз.';

  @override
  String get unableToLoadSaved =>
      'Невозможно загрузить сохраненные элементы прямо сейчас. Пожалуйста, попробуйте еще раз.';

  @override
  String get dateTBA => 'Дата будет объявлена позднее';

  @override
  String get timeTBA => 'Время будет объявлено позднее';

  @override
  String get untitledEvent => 'Безымянное событие';

  @override
  String get locationTBA => 'Местоположение будет объявлено позднее';

  @override
  String get priceTBA => 'Цена будет объявлена позже';

  @override
  String get placeFallback => 'Место';

  @override
  String get foodExperienceFallback => 'Еда Опыт';

  @override
  String get stadiumFallback => 'Стадион';

  @override
  String get eventFallback => 'Событие';

  @override
  String get attractionFallback => 'Привлечение';

  @override
  String ratingReviewsCount(String rating, String count) {
    return '$rating · $count отзывов';
  }

  @override
  String get approved => 'Утверждено';

  @override
  String get audience => 'Аудитория';

  @override
  String get businessLabel => 'Бизнес';

  @override
  String get controlDistance =>
      'Расстояние управления для ближайших возможностей';

  @override
  String get dashboard => 'Панель управления';

  @override
  String get delete => 'Удалить';

  @override
  String get deleteEvent => 'Удалить событие';

  @override
  String get deletingEvent => 'Удаление мероприятия...';

  @override
  String get displayName => 'Отображаемое имя';

  @override
  String errorDeletingEvent(String error) {
    return 'Ошибка удаления события: $error.';
  }

  @override
  String errorLoadingMap(String error) {
    return 'Ошибка загрузки карты: $error.';
  }

  @override
  String eventDeleted(String title) {
    return 'Событие «$title» удалено.';
  }

  @override
  String get failedToDeleteEvent =>
      'Не удалось удалить мероприятие. Пожалуйста, попробуйте еще раз.';

  @override
  String get feed => 'Кормить';

  @override
  String get localBusinessPortal => 'Местный бизнес-портал';

  @override
  String get pending => 'Ожидается';

  @override
  String get phoneNumber => 'Номер телефона';

  @override
  String get pleaseLoginLocal =>
      'Пожалуйста, сначала войдите в систему как локальный пользователь.';

  @override
  String get pleaseLoginToDelete =>
      'Пожалуйста, войдите, чтобы удалить события.';

  @override
  String get pushAlerts => 'Push-уведомления для вашего бизнеса';

  @override
  String get rejected => 'Отклонено';

  @override
  String get reviews => 'Отзывы';

  @override
  String get saveChanges => 'Сохранить изменения';

  @override
  String get searchHintEvents => 'Поиск событий, заказов...';

  @override
  String get suburb => 'Пригород';

  @override
  String get thisLinkUnavailable => 'Эта ссылка сейчас недоступна.';

  @override
  String get total => 'Итого';

  @override
  String get couldNotSaveSettings =>
      'Не удалось сохранить настройки. Пожалуйста, попробуйте еще раз.';

  @override
  String get locationAccessDisabled =>
      'Доступ к местоположению отключен для функций приложения.';

  @override
  String get locationPermissionGranted =>
      'Разрешение на размещение предоставлено.';

  @override
  String get openSettings => 'Открыть настройки';

  @override
  String get themeDark => 'Темный';

  @override
  String get themeLight => 'Свет';

  @override
  String get themeSystem => 'Система';

  @override
  String textScalePercent(String value) {
    return '$value%';
  }

  @override
  String categoryLabel(String category) {
    return 'Категория: $category';
  }

  @override
  String severityLabel(String severity) {
    return 'Серьезность: $severity';
  }

  @override
  String get languageEnglish => 'английский';

  @override
  String get languageSpanish => 'испанский';

  @override
  String get languageFrench => 'французский';

  @override
  String get languageGerman => 'немецкий';

  @override
  String get languageChinese => 'китайский';

  @override
  String get languageArabic => 'арабский';

  @override
  String get languageHindi => 'Хинди';

  @override
  String get languageItalian => 'итальянский';

  @override
  String get languageJapanese => 'японский';

  @override
  String get languageKorean => 'Корейский';

  @override
  String get languagePortuguese => 'португальский';

  @override
  String get languageRussian => 'русский';

  @override
  String get languageVietnamese => 'вьетнамский';

  @override
  String get languageGreek => 'Греческий';

  @override
  String get languagePunjabi => 'Punjabi';

  @override
  String get discoverTitle => 'Откройте для себя местную еду';

  @override
  String get openSourceLink => 'Ссылка с открытым исходным кодом';

  @override
  String get pendingApproval => 'Ожидает одобрения';

  @override
  String deleteEventConfirmation(String title) {
    return 'Вы уверены, что хотите удалить «$title»? ';
  }

  @override
  String get myActivity => 'Моя деятельность';

  @override
  String get businessNotifications => 'Бизнес-уведомления';

  @override
  String get about => 'О';

  @override
  String get aboutDescription =>
      'BrisConnect+ — это умный путеводитель по городу, который помогает посетителям и местным жителям узнавать о событиях, исследовать достопримечательности и записывать свои впечатления от Брисбена на одной подключенной платформе.';

  @override
  String versionLabel(String version) {
    return 'Версия $version';
  }

  @override
  String get locationPermissions => 'Разрешения местоположения';

  @override
  String get enableLocationAccess => 'Включить доступ к местоположению';

  @override
  String get allowNearbyMapFeatures =>
      'Разрешить рекомендации поблизости и функции с поддержкой карты.';

  @override
  String get locationSettings => 'Настройки местоположения';

  @override
  String get setSearchRadius =>
      'Установите радиус поиска событий и достопримечательностей.';

  @override
  String get pleaseLoginToViewSettings =>
      'Пожалуйста, войдите, чтобы просмотреть настройки.';

  @override
  String get locationPermissionNotGranted =>
      'Разрешение на размещение не было предоставлено. Вы можете включить его в настройках системы.';

  @override
  String get theme => 'Тема';

  @override
  String get appTheme => 'Тема приложения';

  @override
  String get chooseHowAppLooks => 'Выберите, как будет выглядеть приложение.';

  @override
  String get textSize => 'Размер текста';

  @override
  String get adjustTextSize => 'Отрегулируйте размер текста в приложении.';

  @override
  String get smaller => 'Меньший';

  @override
  String get larger => 'Больше';

  @override
  String get support => 'Поддерживать';

  @override
  String get sendAppFeedback => 'Отправить отзыв о приложении';

  @override
  String get reportBugsImprovements =>
      'Сообщайте об ошибках, вводящей в заблуждение информации или предложениях по улучшению.';

  @override
  String get noFeedbackYet => 'Вы еще не отправили ни одного отзыва.';

  @override
  String get adminResponse => 'Ответ администратора';

  @override
  String get awaitingAdminResponse => 'Жду ответа администратора...';

  @override
  String get statusPending => 'В ожидании';

  @override
  String get statusInProgress => 'В ходе выполнения';

  @override
  String get statusResolved => 'Решено';

  @override
  String get statusWontFix => 'Не исправлю';

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
