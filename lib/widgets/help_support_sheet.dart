import 'package:flutter/material.dart';
import 'package:brisconnect/theme/app_palette.dart';

class HelpSupportSheet extends StatelessWidget {
  const HelpSupportSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: AppPalette.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Handle bar
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppPalette.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppPalette.ochre.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.help_outline_rounded,
                          color: AppPalette.ochre, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Help & Support',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.charcoal,
                          ),
                        ),
                        Text(
                          'How can we help you?',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppPalette.mutedText,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppPalette.border),
              // Scrollable content
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.all(20),
                  children: [
                    _sectionTitle('Frequently Asked Questions'),
                    const SizedBox(height: 8),
                    _faqTile(
                      icon: Icons.account_circle_outlined,
                      question: 'How do I update my profile?',
                      answer:
                          'Go to your Profile tab, tap your name or avatar, and edit your details.',
                    ),
                    _faqTile(
                      icon: Icons.event_outlined,
                      question: 'How do I submit an event?',
                      answer:
                          'Tap the + button in the navigation bar to add a new event. It will be reviewed before going live.',
                    ),
                    _faqTile(
                      icon: Icons.notifications_outlined,
                      question: 'How do I manage notifications?',
                      answer:
                          'Go to Profile → Notification Settings to turn event reminders on or off.',
                    ),
                    _faqTile(
                      icon: Icons.map_outlined,
                      question: 'How does the map work?',
                      answer:
                          'The Map tab shows nearby events and attractions. Tap any pin for details.',
                    ),
                    _faqTile(
                      icon: Icons.lock_outline_rounded,
                      question: 'How do I reset my password?',
                      answer:
                          'On the login screen tap "Forgot password?" and follow the email instructions.',
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('Contact Us'),
                    const SizedBox(height: 8),
                    _contactTile(
                      icon: Icons.email_outlined,
                      title: 'Email Support',
                      subtitle: 'support@brisconnect.com.au',
                    ),
                    _contactTile(
                      icon: Icons.language_outlined,
                      title: 'Website',
                      subtitle: 'www.brisconnect.com.au',
                    ),
                    const SizedBox(height: 24),
                    _sectionTitle('App Info'),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppPalette.background,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppPalette.border.withValues(alpha: 0.6)),
                      ),
                      child: const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _InfoRow(label: 'App Name', value: 'BrisConnect+'),
                          SizedBox(height: 8),
                          _InfoRow(label: 'Version', value: '1.0.0'),
                          SizedBox(height: 8),
                          _InfoRow(
                              label: 'Platform',
                              value: 'iOS / Android'),
                          SizedBox(height: 8),
                          _InfoRow(
                              label: 'Developer',
                              value: 'BrisConnect+ Team'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: AppPalette.ochre,
        letterSpacing: 0.4,
      ),
    );
  }

  Widget _faqTile({
    required IconData icon,
    required String question,
    required String answer,
  }) {
    return _ExpandableFaq(icon: icon, question: question, answer: answer);
  }

  Widget _contactTile({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppPalette.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppPalette.border.withValues(alpha: 0.5)),
      ),
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: AppPalette.ochre.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: AppPalette.ochre, size: 18),
        ),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppPalette.charcoal)),
        subtitle: Text(subtitle,
            style: const TextStyle(
                fontSize: 13, color: AppPalette.mutedText)),
      ),
    );
  }
}

// ── Expandable FAQ tile ───────────────────────────────────────────────────────

class _ExpandableFaq extends StatefulWidget {
  final IconData icon;
  final String question;
  final String answer;
  const _ExpandableFaq(
      {required this.icon, required this.question, required this.answer});

  @override
  State<_ExpandableFaq> createState() => _ExpandableFaqState();
}

class _ExpandableFaqState extends State<_ExpandableFaq> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppPalette.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppPalette.border.withValues(alpha: 0.5)),
      ),
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(widget.icon,
                      color: AppPalette.ochre, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.question,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: AppPalette.charcoal,
                      ),
                    ),
                  ),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppPalette.mutedText,
                    size: 20,
                  ),
                ],
              ),
              if (_expanded) ...[
                const SizedBox(height: 8),
                Text(
                  widget.answer,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppPalette.mutedText,
                    height: 1.5,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ── Info row ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: AppPalette.mutedText)),
        Text(value,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppPalette.charcoal)),
      ],
    );
  }
}
