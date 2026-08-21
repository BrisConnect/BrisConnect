import 'package:brisconnect/services/business_dashboard_service.dart';

/// Service to generate contextual messages for the chef mascot.
/// Messages are based on real dashboard metrics to provide relevant guidance.
class ChefMessageService {
  static const List<String> _idleMessages = [
    'Hi! Need help growing your business today?',
    'Tap me for quick actions!',
    'Let\'s boost your engagement together!',
    'Ready to create amazing content?',
    'Your customers are waiting to hear from you!',
  ];

  static const List<String> _highProfileViews = [
    'Wow! Your profile is getting noticed! Keep up the great work.',
    'You\'re attracting attention. Time to convert those views into sales?',
    'Your profile is a magnet! Let\'s capitalize on this momentum.',
  ];

  static const List<String> _lowEngagement = [
    'Your profile could use some boost. Try creating fresh content!',
    'Time to refresh your offerings? Let\'s create something new!',
    'Your audience is ready. Share what makes you special!',
  ];

  static const List<String> _manyReviews = [
    'Your reviews are amazing! Showcase them with a promotion!',
    'People love you! Let\'s tell more of them about it.',
  ];

  static const List<String> _fewReviews = [
    'More reviews would help boost your visibility. Any happy customers?',
    'Great time to ask customers for feedback!',
  ];

  static const List<String> _activePromotions = [
    'Your promotion is live! Watch those metrics climb.',
    'Nice! You\'ve got a promotion running. Perfect timing!',
  ];

  static const List<String> _noPromotions = [
    'No active promotions? Let\'s change that and boost visibility!',
    'A promotion could give you the boost you need!',
  ];

  static const List<String> _newSaves = [
    'People are saving your business! You\'re leaving a good impression.',
    'Saves are climbing! Your business is becoming a favorite.',
  ];

  static const List<String> _highBuzzScore = [
    'Your buzz score is fantastic! You\'re the talk of the town!',
    'Keep riding that buzz! Your momentum is strong.',
  ];

  // Track last message timestamp to avoid repetition (this session only)
  static DateTime? _lastMessageTime;

  /// Get a contextual message based on dashboard metrics
  static String getContextualMessage(
    BusinessDashboardMetrics metrics, {
    int minSecondsBetweenMessages = 30,
  }) {
    // If we've shown a message recently, use idle messages to vary
    final now = DateTime.now();
    if (_lastMessageTime != null &&
        now.difference(_lastMessageTime!).inSeconds < minSecondsBetweenMessages) {
      return _getRandomIdleMessage();
    }

    List<String> candidateMessages = [];

    // High engagement signals
    if (metrics.profileViews > 100) {
      candidateMessages.addAll(_highProfileViews);
    }

    // Low engagement warning
    if (metrics.profileViews < 20 && metrics.saves < 10) {
      candidateMessages.addAll(_lowEngagement);
    }

    // Reviews feedback
    if (metrics.totalReviews > 10) {
      candidateMessages.addAll(_manyReviews);
    } else if (metrics.totalReviews == 0) {
      candidateMessages.addAll(_fewReviews);
    }

    // Promotion status
    if (metrics.activePromotions > 0) {
      candidateMessages.addAll(_activePromotions);
    } else {
      candidateMessages.addAll(_noPromotions);
    }

    // Saves signal
    if (metrics.saves > 50) {
      candidateMessages.addAll(_newSaves);
    }

    // Buzz score feedback
    if (metrics.buzzScore >= 75) {
      candidateMessages.addAll(_highBuzzScore);
    }

    // If no specific message applies, use idle
    if (candidateMessages.isEmpty) {
      return _getRandomIdleMessage();
    }

    // Pick a random message and track the timestamp
    final message = candidateMessages[
        (candidateMessages.hashCode * now.millisecondsSinceEpoch) %
            candidateMessages.length];

    _lastMessageTime = now;

    return message;
  }

  /// Reset the message tracking (for testing or session reset)
  static void reset() {
    _lastMessageTime = null;
  }

  static String _getRandomIdleMessage() {
    final now = DateTime.now();
    return _idleMessages[now.millisecondsSinceEpoch % _idleMessages.length];
  }
}
