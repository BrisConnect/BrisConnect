import 'package:flutter/material.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Privacy Policy screen shown during signup and from app settings.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.background,
        foregroundColor: AppPalette.charcoal,
        elevation: 0,
        title: const Text(
          'Privacy Policy',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSection(
                title: '1. Introduction',
                content:
                    'BrisConnect+ ("we", "our", or "us") is committed to protecting your privacy. '
                    'This Privacy Policy explains how we collect, use, store, and share your '
                    'personal information when you use the BrisConnect+ mobile application and website.',
              ),
              _buildSection(
                title: '2. Information We Collect',
                content:
                    'We collect information you provide directly to us, such as your name, email '
                    'address, phone number, profile photo, business details, and any content you '
                    'post or submit. We also collect usage data, device information, and location '
                    'data (with your permission) to help you discover nearby food venues and events.',
              ),
              _buildSection(
                title: '3. How We Use Your Information',
                content:
                    'We use your information to provide, maintain, and improve BrisConnect+, '
                    'including account management, personalised recommendations, promotions, '
                    'reviews, buzz voting, crowd-sourced reports, and customer support. We may '
                    'also send you service-related notifications and marketing communications '
                    '(which you can opt out of at any time).',
              ),
              _buildSection(
                title: '4. Sharing Your Information',
                content:
                    'We do not sell your personal information. We may share information with '
                    'service providers who help us operate the app, comply with legal obligations, '
                    'or protect our rights. Aggregated or anonymised data may be shared with '
                    'business partners for analytics and insights.',
              ),
              _buildSection(
                title: '5. Location Data',
                content:
                    'With your consent, we collect your device\'s location to show nearby '
                    'businesses, events, directions, and live crowd information. You can disable '
                    'location services at any time through your device settings.',
              ),
              _buildSection(
                title: '6. Data Security',
                content:
                    'We implement reasonable technical and organisational measures to protect '
                    'your personal information. However, no method of transmission over the '
                    'internet or electronic storage is 100% secure, and we cannot guarantee '
                    'absolute security.',
              ),
              _buildSection(
                title: '7. Your Rights',
                content:
                    'You have the right to access, update, or delete your personal information. '
                    'You can manage most information through your profile settings. To request '
                    'deletion of your account and associated data, please contact us at '
                    'brisconnect0@gmail.com.',
              ),
              _buildSection(
                title: '8. Children\'s Privacy',
                content:
                    'BrisConnect+ is not intended for children under the age of 13. We do not '
                    'knowingly collect personal information from children under 13. If you believe '
                    'we have collected such information, please contact us immediately.',
              ),
              _buildSection(
                title: '9. Changes to This Policy',
                content:
                    'We may update this Privacy Policy from time to time. We will notify you of '
                    'material changes by posting the updated policy in the app or via email. Your '
                    'continued use of BrisConnect+ after changes means you accept the revised policy.',
              ),
              _buildSection(
                title: '10. Contact Us',
                content:
                    'If you have any questions or concerns about this Privacy Policy, please '
                    'contact us at brisconnect0@gmail.com.',
              ),
              const SizedBox(height: 32),
              Text(
                'Last updated: 31 July 2026',
                style: TextStyle(
                  color: AppPalette.mutedText,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppPalette.charcoal,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: const TextStyle(
              color: AppPalette.mutedText,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
