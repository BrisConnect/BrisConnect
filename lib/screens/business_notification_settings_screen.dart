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
