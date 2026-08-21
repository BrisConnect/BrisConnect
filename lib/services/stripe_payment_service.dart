import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:brisconnect/config/app_config.dart';
import 'package:brisconnect/utils/checkout_window_export.dart';

/// Handles Stripe Checkout sessions for business owner subscriptions
/// and one-off promotion boosts.
class StripePaymentService {
  static String? _lastErrorMessage;

  static String? get lastErrorMessage => _lastErrorMessage;

  static FirebaseFunctions get _functions {
    return FirebaseFunctions.instanceFor(
        region: AppConfig.firebaseFunctionsRegion);
  }

  /// The current page origin used for Stripe success/cancel redirects.
  static String get _origin {
    if (kIsWeb) {
      try {
        return Uri.base.origin;
      } catch (_) {
        return 'https://brisconnect-68b78.web.app';
      }
    }
    return 'https://brisconnect-68b78.web.app';
  }

  /// Fetches the Stripe Checkout URL for a subscription without opening it.
  ///
  /// Provide [planId] (and optionally [businessId]) to purchase a specific
  /// admin-configurable subscription plan.
  static Future<String?> getSubscriptionCheckoutUrl({
    required String ownerId,
    String? businessId,
    String? planId,
  }) async {
    _lastErrorMessage = null;
    try {
      final callable = _functions.httpsCallable('createSubscriptionCheckout');
      final payload = <String, dynamic>{
        'ownerId': ownerId,
        'origin': _origin,
      };
      if (businessId != null && businessId.isNotEmpty) {
        payload['businessId'] = businessId;
      }
      if (planId != null && planId.isNotEmpty) {
        payload['planId'] = planId;
      }
      final result = await callable.call(payload);
      final url = result.data['url'] as String?;
      if (url == null || url.isEmpty) {
        _lastErrorMessage = 'Checkout URL was not returned.';
        return null;
      }
      return url;
    } on FirebaseFunctionsException catch (e) {
      _lastErrorMessage = e.message ?? 'Checkout failed. Please try again.';
      return null;
    } catch (e) {
      _lastErrorMessage = 'Checkout failed: $e';
      return null;
    }
  }

  /// Starts a subscription checkout and redirects the user to Stripe.
  /// Returns true when a checkout URL was opened.
  ///
  /// Provide [planId] (and optionally [businessId]) to purchase a specific
  /// admin-configurable subscription plan.
  ///
  /// On web, pass a [CheckoutWindow] opened synchronously from the button
  /// click handler to avoid pop-up blockers. If omitted, the URL will be
  /// launched directly.
  static Future<bool> startSubscriptionCheckout({
    required String ownerId,
    String? businessId,
    String? planId,
    CheckoutWindow? checkoutWindow,
  }) async {
    final url = await getSubscriptionCheckoutUrl(
      ownerId: ownerId,
      businessId: businessId,
      planId: planId,
    );
    if (url == null) return false;
    return _launchUrl(url, checkoutWindow: checkoutWindow);
  }

  /// Fetches the Stripe Checkout URL for a promotion plan without opening it.
  ///
  /// Provide [planId] (and optionally [businessId]) to purchase an
  /// admin-configurable plan. When [planId] is omitted, a legacy generic
  /// promotion boost is created using [promotionTitle].
  static Future<String?> getPromotionCheckoutUrl({
    required String ownerId,
    String? businessId,
    String? planId,
    String promotionTitle = 'Promotion Boost',
  }) async {
    _lastErrorMessage = null;
    try {
      final callable = _functions.httpsCallable('createPromotionCheckout');
      final payload = <String, dynamic>{
        'ownerId': ownerId,
        'promotionTitle': promotionTitle,
        'origin': _origin,
      };
      if (businessId != null && businessId.isNotEmpty) {
        payload['businessId'] = businessId;
      }
      if (planId != null && planId.isNotEmpty) {
        payload['planId'] = planId;
      }
      final result = await callable.call(payload);
      final url = result.data['url'] as String?;
      if (url == null || url.isEmpty) {
        _lastErrorMessage = 'Checkout URL was not returned.';
        return null;
      }
      return url;
    } on FirebaseFunctionsException catch (e) {
      _lastErrorMessage = e.message ?? 'Checkout failed. Please try again.';
      return null;
    } catch (e) {
      _lastErrorMessage = 'Checkout failed: $e';
      return null;
    }
  }

  /// Starts a promotion plan checkout and redirects the user to Stripe.
  ///
  /// Provide [planId] (and optionally [businessId]) to purchase an
  /// admin-configurable plan.
  static Future<bool> startPromotionCheckout({
    required String ownerId,
    String? businessId,
    String? planId,
    String promotionTitle = 'Promotion Boost',
    CheckoutWindow? checkoutWindow,
  }) async {
    final url = await getPromotionCheckoutUrl(
      ownerId: ownerId,
      businessId: businessId,
      planId: planId,
      promotionTitle: promotionTitle,
    );
    if (url == null) return false;
    return _launchUrl(url, checkoutWindow: checkoutWindow);
  }

  /// Opens the Stripe Customer Portal so the owner can manage or cancel
  /// their subscription, update payment methods, and view invoices.
  ///
  /// On web, pass a [CheckoutWindow] opened synchronously from the button
  /// click handler to avoid pop-up blockers.
  static Future<bool> openBillingPortal({
    required String ownerId,
    CheckoutWindow? checkoutWindow,
  }) async {
    _lastErrorMessage = null;
    try {
      final callable = _functions.httpsCallable('createBillingPortalSession');
      final result = await callable.call({
        'ownerId': ownerId,
        'origin': _origin,
      });
      final url = result.data['url'] as String?;
      if (url == null || url.isEmpty) {
        _lastErrorMessage = 'Portal URL was not returned.';
        return false;
      }
      return _launchUrl(url, checkoutWindow: checkoutWindow);
    } on FirebaseFunctionsException catch (e) {
      _lastErrorMessage = e.message ?? 'Could not open billing portal.';
      return false;
    } catch (e) {
      _lastErrorMessage = 'Could not open billing portal: $e';
      return false;
    }
  }

  /// Returns the current subscription status for a business owner.
  static Future<Map<String, dynamic>> getSubscriptionStatus(
      String ownerId) async {
    _lastErrorMessage = null;
    try {
      final callable = _functions.httpsCallable('getSubscriptionStatus');
      final result = await callable.call({'ownerId': ownerId});
      final data = result.data as Map<String, dynamic>? ?? {};
      return {
        'active': (data['active'] as bool?) ?? false,
        'status': (data['status'] as String?) ?? 'none',
        'currentPeriodEnd': data['currentPeriodEnd'],
        'cancelAtPeriodEnd': (data['cancelAtPeriodEnd'] as bool?) ?? false,
      };
    } on FirebaseFunctionsException catch (e) {
      _lastErrorMessage = e.message ?? 'Could not load subscription status.';
      return {'active': false, 'status': 'error'};
    } catch (e) {
      _lastErrorMessage = 'Could not load subscription status: $e';
      return {'active': false, 'status': 'error'};
    }
  }

  static Future<bool> _launchUrl(
    String url, {
    CheckoutWindow? checkoutWindow,
  }) async {
    // On the web, use a synchronously-opened checkout window when provided,
    // or fall back to a direct window.open. This avoids pop-up blockers and
    // url_launcher externalApplication issues on Flutter web.
    if (kIsWeb) {
      final window = checkoutWindow ?? openBlankCheckoutWindow();
      if (!window.isOpen) {
        _lastErrorMessage =
            'Could not open checkout. Please allow pop-ups for this site.';
        return false;
      }
      window.navigate(url);
      return true;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      final opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      return opened;
    }
    _lastErrorMessage = 'Could not open checkout page.';
    return false;
  }
}
