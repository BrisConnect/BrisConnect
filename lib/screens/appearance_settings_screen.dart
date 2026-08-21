import 'package:flutter/material.dart';
import 'package:brisconnect/auth/local_auth.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/l10n/app_localizations.dart';
import 'package:brisconnect/screens/feedback_form_screen.dart';
import 'package:brisconnect/services/app_display_settings_controller.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class AppearanceSettingsScreen extends StatefulWidget {
  const AppearanceSettingsScreen.visitor({super.key}) : isLocal = false;

  const AppearanceSettingsScreen.local({super.key}) : isLocal = true;

  final bool isLocal;

  @override
  State<AppearanceSettingsScreen> createState() =>
      _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends State<AppearanceSettingsScreen> {
  AppLocalizations get l10n => AppLocalizations.of(context)!;

  late AppThemePreference _themePreference;
  late double _textScaleFactor;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.isLocal) {
      _themePreference = AppDisplaySettingsController.themeFromString(
          LocalAuth.getThemePreference());
      _textScaleFactor = LocalAuth.getTextScaleFactor();
    } else {
      _themePreference = AppDisplaySettingsController.themeFromString(
          VisitorAuth.getThemePreference());
      _textScaleFactor = VisitorAuth.getTextScaleFactor();
    }
  }

  Future<void> _persistSettings({
    AppThemePreference? themePreference,
    double? textScaleFactor,
  }) async {
    setState(() => _isSaving = true);

    final success = widget.isLocal
        ? await LocalAuth.setGeneralAppSettings(
            themePreference: themePreference != null
                ? AppDisplaySettingsController.themeToString(themePreference)
                : null,
            textScaleFactor: textScaleFactor,
          )
        : await VisitorAuth.setGeneralAppSettings(
            themePreference: themePreference != null
                ? AppDisplaySettingsController.themeToString(themePreference)
                : null,
            textScaleFactor: textScaleFactor,
          );

    if (!mounted) return;

    setState(() {
      if (success) {
        if (themePreference != null) _themePreference = themePreference;
        if (textScaleFactor != null) {
          _textScaleFactor = textScaleFactor.clamp(0.9, 1.3);
        }
      }
      _isSaving = false;
    });

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.couldNotSaveSettings),
          duration: const Duration(seconds: 2),
        ),
      );
      return;
    }

    AppDisplaySettingsController.apply(
      themePreference: _themePreference,
      textScaleFactor: _textScaleFactor,
    );
  }

  String? get _reporterName {
    return widget.isLocal
        ? LocalAuth.currentLocal?.name
        : VisitorAuth.currentVisitor?.name;
  }

  String? get _reporterEmail {
    return widget.isLocal
        ? LocalAuth.currentLocal?.email
        : VisitorAuth.currentVisitor?.email;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: LogoAppBarTitle(l10n.appearanceSettings),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _SectionLabel(l10n.theme),
          const SizedBox(height: 8),
          Card(
            color: AppPalette.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppPalette.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.appTheme,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppPalette.charcoal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.chooseHowAppLooks,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppPalette.mutedText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<AppThemePreference>(
                      segments: [
                        ButtonSegment(
                          value: AppThemePreference.system,
                          label: Text(l10n.themeSystem),
                          icon: const Icon(Icons.settings_brightness, size: 18),
                        ),
                        ButtonSegment(
                          value: AppThemePreference.light,
                          label: Text(l10n.themeLight),
                          icon: const Icon(Icons.light_mode_outlined, size: 18),
                        ),
                        ButtonSegment(
                          value: AppThemePreference.dark,
                          label: Text(l10n.themeDark),
                          icon: const Icon(Icons.dark_mode_outlined, size: 18),
                        ),
                      ],
                      selected: {_themePreference},
                      onSelectionChanged: _isSaving
                          ? null
                          : (values) =>
                              _persistSettings(themePreference: values.first),
                      style: ButtonStyle(
                        backgroundColor:
                            WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return AppPalette.deepBlue;
                          }
                          return AppPalette.background;
                        }),
                        foregroundColor:
                            WidgetStateProperty.resolveWith((states) {
                          if (states.contains(WidgetState.selected)) {
                            return Colors.white;
                          }
                          return AppPalette.charcoal;
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel(l10n.textSize),
          const SizedBox(height: 8),
          Card(
            color: AppPalette.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppPalette.border),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.textSize,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppPalette.charcoal,
                        ),
                      ),
                      Text(
                        l10n.textScalePercent(
                            '${(_textScaleFactor * 100).round()}'),
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppPalette.deepBlue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.adjustTextSize,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppPalette.mutedText,
                    ),
                  ),
                  Slider(
                    value: _textScaleFactor,
                    min: 0.9,
                    max: 1.3,
                    divisions: 8,
                    label: l10n.textScalePercent(
                        '${(_textScaleFactor * 100).round()}'),
                    activeColor: AppPalette.deepBlue,
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            setState(() => _textScaleFactor = value);
                          },
                    onChangeEnd: _isSaving
                        ? null
                        : (value) => _persistSettings(textScaleFactor: value),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.smaller,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppPalette.mutedText,
                        ),
                      ),
                      Text(
                        l10n.larger,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppPalette.mutedText,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          _SectionLabel(l10n.support),
          const SizedBox(height: 8),
          Card(
            color: AppPalette.surface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: const BorderSide(color: AppPalette.border),
            ),
            child: ListTile(
              leading: const Icon(
                Icons.feedback_outlined,
                color: AppPalette.deepBlue,
              ),
              title: Text(
                l10n.sendAppFeedback,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                l10n.reportBugsImprovements,
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => FeedbackFormScreen(
                      reporterRole: widget.isLocal ? 'local' : 'visitor',
                      reporterName: _reporterName ?? 'Guest Visitor',
                      reporterEmail: _reporterEmail ?? '',
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
        color: AppPalette.mutedText,
      ),
    );
  }
}
