// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'BrisConnect+';

  @override
  String get welcome => 'ようこそ';

  @override
  String get signIn => 'サインイン';

  @override
  String get signUp => 'サインアップ';

  @override
  String get signOut => 'サインアウト';

  @override
  String get email => 'メール';

  @override
  String get password => 'パスワード';

  @override
  String get phone => '電話';

  @override
  String get name => '名前';

  @override
  String get save => '保存';

  @override
  String get cancel => 'キャンセル';

  @override
  String get editProfile => 'プロフィールを編集';

  @override
  String get profileInfo => 'プロフィール情報';

  @override
  String get preferences => '設定';

  @override
  String get language => '言語';

  @override
  String get locationRadius => '位置の半径';

  @override
  String get appearanceSettings => '外観設定';

  @override
  String get feedback => 'フィードバック';

  @override
  String get myFeedback => 'マイフィードバック';

  @override
  String get helpAndSupport => 'ヘルプとサポート';

  @override
  String get discover => '発見';

  @override
  String get community => 'コミュニティ';

  @override
  String get map => '地図';

  @override
  String get saved => '保存済み';

  @override
  String get profile => 'プロフィール';

  @override
  String get food => '食べ物';

  @override
  String get events => 'イベント';

  @override
  String get businesses => 'ビジネス';

  @override
  String get promotions => 'プロモーション';

  @override
  String get photos => '写真';

  @override
  String get newPost => '新着';

  @override
  String get search => '検索';

  @override
  String get filter => 'フィルター';

  @override
  String get clearFilters => 'フィルターをクリア';

  @override
  String get noResults => '結果が見つかりません';

  @override
  String get loading => '読み込み中...';

  @override
  String get error => 'エラー';

  @override
  String get success => '成功';

  @override
  String get profileUpdated => 'プロフィールが正常に更新されました。';

  @override
  String get profileUpdateFailed => 'プロフィールを更新できませんでした。もう一度お試しください。';

  @override
  String get guestVisitor => 'ゲスト訪問者';

  @override
  String get localUser => '地元';

  @override
  String get filterEventsTitle => 'イベントのフィルタリング';

  @override
  String get priceLabel => '価格';

  @override
  String get dateLabel => '日付';

  @override
  String get pickADate => '日付を選択してください';

  @override
  String get resetButton => 'リセット';

  @override
  String get applyButton => '申し込む';

  @override
  String get freeLabel => '無料';

  @override
  String get paidLabel => '有料';

  @override
  String eventSavedToInterested(String eventTitle) {
    return '$eventTitle は「興味あり」に保存されました。';
  }

  @override
  String eventRemovedFromInterested(String eventTitle) {
    return '$eventTitle が「興味あり」から削除されました。';
  }

  @override
  String savedToAttractions(String title) {
    return '$title が保存された観光スポットに保存されました。';
  }

  @override
  String removedFromAttractions(String title) {
    return '$title が保存されたアトラクションから削除されました。';
  }

  @override
  String get pleaseSignInToSaveEvents => 'イベントを保存するには、訪問者としてログインしてください。';

  @override
  String get pleaseSignInToReview => 'レビューを書くか BuzzVote するにはサインインしてください。';

  @override
  String reviewSubmitted(String rating, String buzzRating) {
    return 'レビューが送信されました\\! ⭐ $rating / バズ ⚡ $buzzRating';
  }

  @override
  String reviewSubmitFailed(String error) {
    return 'レビューを送信できませんでした: $error';
  }

  @override
  String get noExternalLink => 'このアイテムに利用できる外部リンクはまだありません。';

  @override
  String get unableToOpenLink => '現在、イベント リンクを開けません。';

  @override
  String shareTitle(String title) {
    return '共有: $title';
  }

  @override
  String get reportEvent => 'イベントを報告する';

  @override
  String get reviewsOnlyForFood => 'レビューは食品のみに適用されます';

  @override
  String get chooseFromGallery => 'ギャラリーから選ぶ';

  @override
  String get takeAPhoto => '写真を撮ってください';

  @override
  String get pleaseLoginVisitor => 'まずビジターとしてログインしてください。';

  @override
  String get onlyJpgPng => 'JPG および PNG 画像のみがサポートされています。';

  @override
  String get imageTooLarge => '画像が大きすぎます。小さい画像を選択してください。';

  @override
  String get profilePictureUpdated => 'プロフィール写真が正常に更新されました。';

  @override
  String get profilePictureUpdateFailed => 'プロフィール写真を更新できませんでした。もう一度試してください。';

  @override
  String get enterYourName => 'あなたの名前を入力してください';

  @override
  String get phoneHint => '例: 04xxxxxxxx';

  @override
  String get nameCannotBeEmpty => '名前を空にすることはできません。';

  @override
  String get nameMinLength => '名前は少なくとも 2 文字である必要があります。';

  @override
  String get enterValidPhone => '有効な電話番号を入力してください。';

  @override
  String get changeProfilePicture => 'プロフィール写真を変更する';

  @override
  String get uploadProfilePicture => 'プロフィール写真をアップロードする';

  @override
  String get areYouSureSignOut => 'サインアウトしてもよろしいですか?';

  @override
  String get returnWelcome => 'ようこそ画面に戻る';

  @override
  String get setHowFarRecommendations => 'どこまで推奨できるかを設定する';

  @override
  String get themeTextSizeFeedback => 'テーマ、テキストサイズ、フィードバック';

  @override
  String get faqsContactAppInfo => 'FAQ、お問い合わせ、アプリ情報';

  @override
  String get viewSubmittedFeedback => '送信されたフィードバックと管理者の応答を表示する';

  @override
  String get discoverSubtitle => '地元の食べ物や体験を発見する';

  @override
  String get searchHintLocalFood => '地元の飲食店を検索...';

  @override
  String get homeLabel => 'ホーム';

  @override
  String get recommendedForYou => 'あなたにおすすめ';

  @override
  String get seeAll => 'すべて見る';

  @override
  String get categories => 'カテゴリー';

  @override
  String get nearby => '近くの';

  @override
  String get noFoodPlacesFound => '食事できる場所が見つかりません';

  @override
  String get noFoodPlacesSubtitle => '検索またはフィルターの選択を変更してみてください。';

  @override
  String get localFoodBusinesses => '地元の食品ビジネス';

  @override
  String get localFoodSubtitle => 'ブリスベンの中小規模の食品企業をサポートする';

  @override
  String get exploreReviewFoodBusinesses => '食品ビジネスの探索とレビュー';

  @override
  String get noSavedItemsTitle => '保存されたアイテムはまだありません';

  @override
  String get noSavedItemsSubtitle =>
      '食品の名刺のハートのアイコン、またはビジネス プロフィールのブックマークをタップして、ここに保存します。';

  @override
  String get savedEvents => '保存されたイベント';

  @override
  String get savedEventsSubtitle => 'イベントのリマインダーと計画';

  @override
  String get savedAttractions => '保存された観光スポット';

  @override
  String get savedAttractionsSubtitle => 'イベントとは関係なく訪れるべき場所';

  @override
  String get savedBusinesses => '保存されたビジネス';

  @override
  String get savedBusinessesSubtitle => 'ブックマークした飲食店';

  @override
  String get savedItemsUnavailableTitle => '保存されたアイテムは使用できません';

  @override
  String get savedItemsUnavailableSubtitle =>
      '一部の保存済みアイテムはディスカバリー フィードで公開されなくなりました。';

  @override
  String get retryAction => '再試行';

  @override
  String get unableToLoadDiscover => '現在、検出アイテムを読み込むことができません。もう一度試してください。';

  @override
  String get unableToLoadSaved => '現在、保存されたアイテムをロードできません。もう一度試してください。';

  @override
  String get dateTBA => '日付未定';

  @override
  String get timeTBA => '時間未定';

  @override
  String get untitledEvent => '無題のイベント';

  @override
  String get locationTBA => '場所は未定';

  @override
  String get priceTBA => '価格未定';

  @override
  String get placeFallback => '場所';

  @override
  String get foodExperienceFallback => '食体験';

  @override
  String get stadiumFallback => 'スタジアム';

  @override
  String get eventFallback => 'イベント';

  @override
  String get attractionFallback => 'アトラクション';

  @override
  String ratingReviewsCount(String rating, String count) {
    return '$rating · $count レビュー';
  }

  @override
  String get approved => '承認済み';

  @override
  String get audience => '観客';

  @override
  String get businessLabel => 'ビジネス';

  @override
  String get controlDistance => '近くのチャンスに合わせて距離をコントロール';

  @override
  String get dashboard => 'ダッシュボード';

  @override
  String get delete => '削除';

  @override
  String get deleteEvent => 'イベントの削除';

  @override
  String get deletingEvent => 'イベントを削除しています...';

  @override
  String get displayName => '表示名';

  @override
  String errorDeletingEvent(String error) {
    return 'イベント削除エラー: $error';
  }

  @override
  String errorLoadingMap(String error) {
    return 'マップのロード中にエラーが発生しました: $error';
  }

  @override
  String eventDeleted(String title) {
    return 'イベント「$title」は削除されました。';
  }

  @override
  String get failedToDeleteEvent => 'イベントの削除に失敗しました。もう一度試してください。';

  @override
  String get feed => '飼料';

  @override
  String get localBusinessPortal => 'ローカルビジネスポータル';

  @override
  String get pending => '保留中';

  @override
  String get phoneNumber => '電話番号';

  @override
  String get pleaseLoginLocal => '最初にローカル ユーザーとしてログインしてください。';

  @override
  String get pleaseLoginToDelete => 'イベントを削除するにはログインしてください。';

  @override
  String get pushAlerts => 'ビジネス向けのプッシュ アラート';

  @override
  String get rejected => '拒否されました';

  @override
  String get reviews => 'レビュー';

  @override
  String get saveChanges => '変更を保存';

  @override
  String get searchHintEvents => 'イベントや予約を検索...';

  @override
  String get suburb => '郊外';

  @override
  String get thisLinkUnavailable => 'このリンクは現在利用できません。';

  @override
  String get total => '合計';

  @override
  String get couldNotSaveSettings => '設定を保存できませんでした。もう一度試してください。';

  @override
  String get locationAccessDisabled => 'アプリ機能の位置情報アクセスが無効になっています。';

  @override
  String get locationPermissionGranted => '位置情報の許可が与えられました。';

  @override
  String get openSettings => '設定を開く';

  @override
  String get themeDark => '暗い';

  @override
  String get themeLight => 'ライト';

  @override
  String get themeSystem => 'システム';

  @override
  String textScalePercent(String value) {
    return '$value%';
  }

  @override
  String categoryLabel(String category) {
    return 'カテゴリ: $category';
  }

  @override
  String severityLabel(String severity) {
    return '重大度: $severity';
  }

  @override
  String get languageEnglish => '英語';

  @override
  String get languageSpanish => 'スペイン語';

  @override
  String get languageFrench => 'フランス語';

  @override
  String get languageGerman => 'ドイツ語';

  @override
  String get languageChinese => '中国語';

  @override
  String get languageArabic => 'アラビア語';

  @override
  String get languageHindi => 'ヒンディー語';

  @override
  String get languageItalian => 'イタリア語';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageKorean => '韓国人';

  @override
  String get languagePortuguese => 'ポルトガル語';

  @override
  String get languageRussian => 'ロシア語';

  @override
  String get languageVietnamese => 'ベトナム語';

  @override
  String get languageGreek => 'ギリシャ語';

  @override
  String get discoverTitle => '地元の食べ物を発見する';

  @override
  String get openSourceLink => 'オープンソースリンク';

  @override
  String get pendingApproval => '承認待ち';

  @override
  String deleteEventConfirmation(String title) {
    return '「$title」を削除してもよろしいですか?';
  }

  @override
  String get myActivity => '私の活動';

  @override
  String get businessNotifications => '業務上のお知らせ';

  @override
  String get about => 'について';

  @override
  String get aboutDescription =>
      'BrisConnect+ は、訪問者や地元の人々がイベントを発見し、観光名所を探索し、ブリスベンでの体験を 1 つの接続されたプラットフォームで記録できるようにするスマート シティ ガイドです。';

  @override
  String versionLabel(String version) {
    return 'バージョン $version';
  }

  @override
  String get locationPermissions => '位置情報の許可';

  @override
  String get enableLocationAccess => '位置情報アクセスを有効にする';

  @override
  String get allowNearbyMapFeatures => '近くのおすすめや地図対応の機能を許可します。';

  @override
  String get locationSettings => '位置情報の設定';

  @override
  String get setSearchRadius => 'イベントや観光スポットの検索範囲を設定します。';

  @override
  String get pleaseLoginToViewSettings => '設定を表示するにはログインしてください。';

  @override
  String get locationPermissionNotGranted =>
      '位置情報の許可が与えられませんでした。システム設定で有効にすることができます。';

  @override
  String get theme => 'テーマ';

  @override
  String get appTheme => 'アプリのテーマ';

  @override
  String get chooseHowAppLooks => 'アプリの外観を選択します。';

  @override
  String get textSize => '文字サイズ';

  @override
  String get adjustTextSize => 'アプリ全体でテキストのサイズを調整します。';

  @override
  String get smaller => 'より小さい';

  @override
  String get larger => 'より大きな';

  @override
  String get support => 'サポート';

  @override
  String get sendAppFeedback => 'アプリのフィードバックを送信する';

  @override
  String get reportBugsImprovements => 'バグ、誤解を招く情報、または改善提案を報告します。';

  @override
  String get noFeedbackYet => 'まだフィードバックを送信していません。';

  @override
  String get adminResponse => '管理者の応答';

  @override
  String get awaitingAdminResponse => '管理者の応答を待っています...';

  @override
  String get statusPending => '保留中';

  @override
  String get statusInProgress => '進行中';

  @override
  String get statusResolved => '解決済み';

  @override
  String get statusWontFix => '直らない';
}
