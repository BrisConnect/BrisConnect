import 'package:flutter/material.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Terms of Service screen shown during signup and from app settings.
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        backgroundColor: AppPalette.background,
        foregroundColor: AppPalette.charcoal,
        elevation: 0,
        title: const Text(
          'Terms of Service',
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
                title: '1. Acceptance of Terms',
                content:
                    'By accessing or using BrisConnect+ (the "App"), you agree to be bound by these '
                    'Terms of Service and all applicable laws and regulations. If you do not agree '
                    'with any part of these terms, you must not use the App.',
              ),
              _buildSection(
                title: '2. Eligibility',
                content:
                    'You must be at least 13 years old to use BrisConnect+. By creating an account, '
                    'you represent and warrant that you meet this age requirement and that all '
                    'information you provide is accurate and complete.',
              ),
              _buildSection(
                title: '3. Account Registration',
                content:
                    'You may be required to create an account to access certain features. You are '
                    'responsible for maintaining the confidentiality of your account credentials '
                    'and for all activities that occur under your account. You agree to notify us '
                    'immediately of any unauthorised use.',
              ),
              _buildSection(
                title: '4. User Content',
                content:
                    'You retain ownership of any content you submit, post, or share through the '
                    'App, including reviews, photos, ratings, and business information. By posting '
                    'content, you grant BrisConnect+ a non-exclusive, royalty-free, worldwide '
                    'licence to use, display, reproduce, and distribute your content in connection '
                    'with operating and promoting the App.',
              ),
              _buildSection(
                title: '5. Prohibited Conduct',
                content:
                    'You agree not to use the App for any unlawful or harmful purpose, including '
                    'but not limited to: posting false, misleading, defamatory, or abusive content; '
                    'infringing intellectual property rights; attempting to interfere with the App\'s '
                    'security or functionality; harvesting user data; or spamming other users.',
              ),
              _buildSection(
                title: '6. Business Listings and Promotions',
                content:
                    'Local business owners may create business profiles, list events, and publish '
                    'promotions. You are responsible for ensuring that all listings comply with '
                    'applicable laws and do not mislead consumers. BrisConnect+ reserves the right '
                    'to review, modify, or remove any content at its discretion.',
              ),
              _buildSection(
                title: '7. Reviews and Ratings',
                content:
                    'Reviews must reflect genuine experiences. Fake, paid, or manipulated reviews '
                    'are strictly prohibited. We reserve the right to remove reviews that violate '
                    'these terms or our community guidelines.',
              ),
              _buildSection(
                title: '8. Intellectual Property',
                content:
                    'All trademarks, logos, designs, and other intellectual property displayed on '
                    'the App are owned by BrisConnect+ or its licensors. You may not copy, modify, '
                    'distribute, or create derivative works without our prior written consent.',
              ),
              _buildSection(
                title: '9. Termination',
                content:
                    'We may suspend or terminate your account and access to the App at any time, '
                    'with or without notice, for conduct that we believe violates these Terms or '
                    'is harmful to other users, us, or third parties.',
              ),
              _buildSection(
                title: '10. Disclaimer of Warranties',
                content:
                    'The App is provided on an "as is" and "as available" basis. BrisConnect+ makes '
                    'no warranties, express or implied, regarding the reliability, accuracy, or '
                    'availability of the App or its content.',
              ),
              _buildSection(
                title: '11. Limitation of Liability',
                content:
                    'To the maximum extent permitted by law, BrisConnect+ shall not be liable for '
                    'any indirect, incidental, special, consequential, or punitive damages arising '
                    'out of or related to your use of the App.',
              ),
              _buildSection(
                title: '12. Changes to Terms',
                content:
                    'We may update these Terms of Service from time to time. Continued use of the '
                    'App after changes constitutes acceptance of the revised terms.',
              ),
              _buildSection(
                title: '13. Governing Law',
                content:
                    'These Terms are governed by the laws of Queensland, Australia. Any disputes '
                    'arising from these Terms shall be resolved in the courts of Queensland.',
              ),
              _buildSection(
                title: '14. Contact Us',
                content:
                    'If you have any questions about these Terms of Service, please contact us at '
                    'brisconnect0@gmail.com.',
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
