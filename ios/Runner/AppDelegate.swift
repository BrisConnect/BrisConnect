import Flutter
import GoogleMaps
import UIKit
import FirebaseMessaging
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate {
  /// Shared Flutter engine — created once, reused by SceneDelegate.
  lazy var flutterEngine: FlutterEngine = FlutterEngine(name: "main")

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Initialise Google Maps before Flutter engine starts.
    if let mapsApiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
      !mapsApiKey.isEmpty
    {
      GMSServices.provideAPIKey(mapsApiKey)
    }

    // Start the engine and register all plugins once, before any scene connects.
    flutterEngine.run()
    GeneratedPluginRegistrant.register(with: flutterEngine)

    setupSocialStoryChannel()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  /// Facebook App ID used for Instagram/Facebook story sharing.
  private let facebookAppID = "822209667547948"

  /// Sets up a method channel for direct Instagram/Facebook story sharing.
  /// Flutter cannot set arbitrary UIPasteboard keys, which Instagram requires
  /// to receive story media, so we handle that here.
  private func setupSocialStoryChannel() {
    let channel = FlutterMethodChannel(
      name: "com.brisconnect/social_story",
      binaryMessenger: flutterEngine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "UNAVAILABLE", message: nil, details: nil))
        return
      }
      switch call.method {
      case "shareToInstagramStory":
        self.shareToInstagramStory(call: call, result: result)
      case "shareToFacebookStory":
        self.shareToFacebookStory(call: call, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func shareToInstagramStory(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let imageData = args["imageData"] as? FlutterStandardTypedData else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "imageData required", details: nil))
      return
    }
    let link = args["link"] as? String

    let pasteboard = UIPasteboard.general
    var pasteboardItems: [String: Any] = [
      "com.instagram.sharedSticker.backgroundImage": imageData.data,
      "com.instagram.sharedSticker.backgroundTopColor": "#000000",
      "com.instagram.sharedSticker.backgroundBottomColor": "#000000"
    ]
    if let link = link, !link.isEmpty {
      pasteboardItems["com.instagram.sharedSticker.contentURL"] = link
    }
    let pasteboardOptions = [UIPasteboard.OptionsKey.expirationDate: Date(timeIntervalSinceNow: 60 * 5)]
    pasteboard.setItems([pasteboardItems], options: pasteboardOptions)

    let urlString = "instagram-stories://share?source_application=\(facebookAppID)"
    guard let url = URL(string: urlString),
          UIApplication.shared.canOpenURL(url) else {
      result(FlutterError(code: "APP_NOT_INSTALLED", message: "Instagram is not installed", details: nil))
      return
    }
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
    result(true)
  }

  private func shareToFacebookStory(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let imageData = args["imageData"] as? FlutterStandardTypedData else {
      result(FlutterError(code: "INVALID_ARGUMENT", message: "imageData required", details: nil))
      return
    }
    let link = args["link"] as? String

    let pasteboard = UIPasteboard.general
    var pasteboardItems: [String: Any] = [
      "com.facebook.sharedSticker.backgroundImage": imageData.data,
      "com.facebook.sharedSticker.appID": facebookAppID
    ]
    if let link = link, !link.isEmpty {
      pasteboardItems["com.facebook.sharedSticker.contentURL"] = link
    }
    let pasteboardOptions = [UIPasteboard.OptionsKey.expirationDate: Date(timeIntervalSinceNow: 60 * 5)]
    pasteboard.setItems([pasteboardItems], options: pasteboardOptions)

    let urlString = "facebook-stories://share?source_application=\(facebookAppID)"
    guard let url = URL(string: urlString),
          UIApplication.shared.canOpenURL(url) else {
      result(FlutterError(code: "APP_NOT_INSTALLED", message: "Facebook is not installed", details: nil))
      return
    }
    UIApplication.shared.open(url, options: [:], completionHandler: nil)
    result(true)
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    // Forward APNs token to Firebase Messaging plugin.
    Messaging.messaging().apnsToken = deviceToken
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }
}
