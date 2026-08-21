import 'package:flutter/material.dart';
import 'package:brisconnect/auth/local_auth.dart';

/// Business-owner notification preferences screen.
///
/// Lets local users (business owners) toggle which push notification
/// categories they receive. The screen reads from and writes to
/// [LocalAuth.currentLocal] via [LocalAuth.updateNotificationPreferences].
class BusinessNotificationSettingsScreen extends StatefulWidget {
  const BusinessNotificationSettingsScreen({super.key});

  @override
  State<BusinessNotificationSettingsScreen> createState() =>
      _BusinessNotificationSettingsScreenState();
}

class _BusinessNotificationSettingsScreenState
    extends State<BusinessNotificationSettingsScreen> {
  bool _trendingPromotion = true;
  bool _offerExpiry = true;
  bool _newReview = true;
  bool _businessUpdates = true;
  bool _audienceActivity = true;
  bool _socialShare = true;
  bool _buzzVote = true;
  bool _verificationUpdates = true;
  bool _promotionStatus = true;
  bool _promotionPerformance = true;
  bool _adminMessages = true;
  bool _reportedContent = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final user = LocalAuth.currentLocal;
    if (user != null) {
      _trendingPromotion = user.notifyTrendingPromotion;
      _offerExpiry = user.notifyOfferExpiry;
      _newReview = user.notifyNewReview;
      _businessUpdates = user.notifyBusinessUpdates;
      _audienceActivity = user.notifyAudienceActivity;
      _socialShare = user.notifySocialShare;
      _buzzVote = user.notifyBuzzVote;
      _verificationUpdates = user.notifyVerificationUpdates;
      _promotionStatus = user.notifyPromotionStatus;
      _promotionPerformance = user.notifyPromotionPerformance;
      _adminMessages = user.notifyAdminMessages;
      _reportedContent = user.notifyReportedContent;
    }
  }

  Future<void> _toggle(
    String key,
    bool value,
    void Function(bool) updateLocal,
  ) async {
    setState(() {
      updateLocal(value);
      _isSaving = true;
    });

    final ok = await LocalAuth.updateNotificationPreferences(
      notifyTrendingPromotion: key == 'trendingPromotion' ? value : null,
      notifyOfferExpiry: key == 'offerExpiry' ? value : null,
      notifyNewReview: key == 'newReview' ? value : null,
      notifyBusinessUpdates: key == 'businessUpdates' ? value : null,
      notifyAudienceActivity: key == 'audienceActivity' ? value : null,
      notifySocialShare: key == 'socialShare' ? value : null,
      notifyBuzzVote: key == 'buzzVote' ? value : null,
      notifyVerificationUpdates:
          key == 'verificationUpdates' ? value : null,
      notifyPromotionStatus: key == 'promotionStatus' ? value : null,
      notifyPromotionPerformance:
          key == 'promotionPerformance' ? value : null,
      notifyAdminMessages: key == 'adminMessages' ? value : null,
      notifyReportedContent: key == 'reportedContent' ? value : null,
    );

    if (mounted) {
      setState(() => _isSaving = false);
      if (!ok) {
        final message = LocalAuth.lastErrorMessage ?? 'Update failed.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message)),
        );
      }
    }
  }

  Widget _buildSwitch({
    required Key key,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Semantics(
      label: '$title, $subtitle',
      toggled: value,
      child: SwitchListTile(
        key: key,
        title: Text(title),
        subtitle: Text(subtitle),
        value: value,
        onChanged: _isSaving ? null : onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Business Notifications'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Choose which business alerts you receive as push notifications.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
          _buildSwitch(
            key: const Key('switch_trendingPromotion'),
            title: 'Trending promotions',
            subtitle: 'Notify me when one of my promotions starts trending.',
            value: _trendingPromotion,
            onChanged: (value) => _toggle(
              'trendingPromotion',
              value,
              (v) => _trendingPromotion = v,
            ),
          ),
          _buildSwitch(
            key: const Key('switch_offerExpiry'),
            title: 'Offer expiry reminders',
            subtitle: 'Remind me before my offers expire.',
            value: _offerExpiry,
            onChanged: (value) => _toggle(
              'offerExpiry',
              value,
              (v) => _offerExpiry = v,
            ),
          ),
          _buildSwitch(
            key: const Key('switch_newReview'),
            title: 'New reviews',
            subtitle: 'Notify me when a customer leaves a review.',
            value: _newReview,
            onChanged: (value) => _toggle(
              'newReview',
              value,
              (v) => _newReview = v,
            ),
          ),
          _buildSwitch(
            key: const Key('switch_businessUpdates'),
            title: 'Business updates',
            subtitle: 'Updates about my business profile and listings.',
            value: _businessUpdates,
            onChanged: (value) => _toggle(
              'businessUpdates',
              value,
              (v) => _businessUpdates = v,
            ),
          ),
          _buildSwitch(
            key: const Key('switch_audienceActivity'),
            title: 'Profile views & saves',
            subtitle: 'Notify me when visitors view or save my business.',
            value: _audienceActivity,
            onChanged: (value) => _toggle(
              'audienceActivity',
              value,
              (v) => _audienceActivity = v,
            ),
          ),
          _buildSwitch(
            key: const Key('switch_socialShare'),
            title: 'Social shares',
            subtitle: 'Notify me when someone shares my business.',
            value: _socialShare,
            onChanged: (value) => _toggle(
              'socialShare',
              value,
              (v) => _socialShare = v,
            ),
          ),
          _buildSwitch(
            key: const Key('switch_buzzVote'),
            title: 'Buzz votes',
            subtitle: 'Notify me when someone buzz-votes my business.',
            value: _buzzVote,
            onChanged: (value) => _toggle(
              'buzzVote',
              value,
              (v) => _buzzVote = v,
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          _buildSwitch(
            key: const Key('switch_verificationUpdates'),
            title: 'Verification updates',
            subtitle: 'Notify me when my business verification status changes.',
            value: _verificationUpdates,
            onChanged: (value) => _toggle(
              'verificationUpdates',
              value,
              (v) => _verificationUpdates = v,
            ),
          ),
          _buildSwitch(
            key: const Key('switch_promotionStatus'),
            title: 'Promotion status',
            subtitle: 'Notify me when my promotion is approved, published, rejected, or expiring.',
            value: _promotionStatus,
            onChanged: (value) => _toggle(
              'promotionStatus',
              value,
              (v) => _promotionStatus = v,
            ),
          ),
          _buildSwitch(
            key: const Key('switch_promotionPerformance'),
            title: 'Promotion performance',
            subtitle: 'Notify me when my promotion receives strong engagement.',
            value: _promotionPerformance,
            onChanged: (value) => _toggle(
              'promotionPerformance',
              value,
              (v) => _promotionPerformance = v,
            ),
          ),
          _buildSwitch(
            key: const Key('switch_adminMessages'),
            title: 'Admin messages',
            subtitle: 'Notify me when BrisConnect Admin sends an important message or requires action.',
            value: _adminMessages,
            onChanged: (value) => _toggle(
              'adminMessages',
              value,
              (v) => _adminMessages = v,
            ),
          ),
          _buildSwitch(
            key: const Key('switch_reportedContent'),
            title: 'Reported content',
            subtitle: 'Notify me when content associated with my business requires action.',
            value: _reportedContent,
            onChanged: (value) => _toggle(
              'reportedContent',
              value,
              (v) => _reportedContent = v,
            ),
          ),
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
