import 'package:cloud_functions/cloud_functions.dart';
import 'package:brisconnect/config/app_config.dart';
import 'package:brisconnect/services/business_dashboard_service.dart';

/// Calls Gemini via a Firebase Function to get AI-powered improvement
/// suggestions based on the owner's dashboard metrics.
class BusinessInsightsService {
  final FirebaseFunctions _functions;

  BusinessInsightsService({FirebaseFunctions? functions})
      : _functions = functions ??
            FirebaseFunctions.instanceFor(
                region: AppConfig.firebaseFunctionsRegion);

  Future<List<Map<String, String>>> getSuggestions({
    required BusinessDashboardMetrics metrics,
    String businessName = 'your business',
    String category = '',
  }) async {
    try {
      final callable = _functions.httpsCallable('generateBusinessInsights');
      final result = await callable.call<Map<String, dynamic>>({
        'businessName': businessName,
        'category': category,
        'metrics': _metricsToMap(metrics),
      });

      final data = result.data;
      final suggestions = data['suggestions'];
      if (suggestions is! List || suggestions.isEmpty) {
        return _fallbackSuggestions(metrics);
      }

      return suggestions
          .whereType<Map<String, dynamic>>()
          .map((s) => {
                'title': (s['title'] as String? ?? '').trim(),
                'tip': (s['tip'] as String? ?? '').trim(),
              })
          .where((s) => s['title']!.isNotEmpty || s['tip']!.isNotEmpty)
          .toList();
    } catch (e) {
      return _fallbackSuggestions(metrics);
    }
  }

  Map<String, dynamic> _metricsToMap(BusinessDashboardMetrics m) {
    return {
      'profileViews': m.profileViews,
      'saves': m.saves,
      'socialShares': m.socialShares,
      'activePromotions': m.activePromotions,
      'newReviews': m.newReviews,
      'totalReviews': m.totalReviews,
      'averageRating': m.averageRating,
      'averageBuzzRating': m.averageBuzzRating,
      'totalBuzzVotes': m.totalBuzzVotes,
      'buzzScore': m.buzzScore,
      'crowdLevel': m.crowdLevel,
      'crowdReportCount': m.crowdReportCount,
      'profileViewsChange': m.profileViewsChange,
      'savesChange': m.savesChange,
      'socialSharesChange': m.socialSharesChange,
      'activePromotionsChange': m.activePromotionsChange,
      'newReviewsChange': m.newReviewsChange,
    };
  }

  List<Map<String, String>> _fallbackSuggestions(
      BusinessDashboardMetrics metrics) {
    final suggestions = <Map<String, String>>[];

    if (metrics.profileViews == 0) {
      suggestions.add({
        'title': 'Boost your visibility',
        'tip': 'You have no profile views this week. Try creating a promotion '
            'or an AI-generated post to get in front of more customers.',
      });
    }

    if (metrics.activePromotions == 0) {
      suggestions.add({
        'title': 'Run a promotion',
        'tip': 'Active promotions drive more visits and saves. '
            'Create a limited-time offer to attract new customers.',
      });
    }

    if (metrics.totalReviews == 0) {
      suggestions.add({
        'title': 'Collect reviews',
        'tip': 'Reviews build trust. Ask happy customers to leave a review '
            'on your BrisConnect profile.',
      });
    }

    if (metrics.socialShares == 0) {
      suggestions.add({
        'title': 'Encourage social sharing',
        'tip': 'Shares extend your reach beyond BrisConnect. '
            'Add share-worthy photos and deals to your profile.',
      });
    }

    if (suggestions.isEmpty) {
      suggestions.add({
        'title': 'Keep momentum going',
        'tip': 'Your metrics look healthy. Keep posting fresh content and '
            'responding to reviews to stay top of mind.',
      });
    }

    return suggestions;
  }
}
