import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:brisconnect/auth/visitor_auth.dart';
import 'package:brisconnect/l10n/app_localizations.dart';
import 'package:brisconnect/theme/app_palette.dart';

class AiNarrationWidget extends StatefulWidget {
  const AiNarrationWidget({
    super.key,
    required this.narrationText,
    required this.helperText,
  });

  final String narrationText;
  final String helperText;

  @override
  State<AiNarrationWidget> createState() => _AiNarrationWidgetState();
}

class _AiNarrationWidgetState extends State<AiNarrationWidget> {
  late final FlutterTts _tts;
  bool _speaking = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _initializeTts();
    _setupTtsHandlers();
  }

  void _setupTtsHandlers() {
    _tts.setStartHandler(() {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _speaking = true;
      });
    });
    _tts.setCompletionHandler(() {
      if (!mounted) return;
      setState(() {
        _speaking = false;
        _loading = false;
      });
    });
    _tts.setCancelHandler(() {
      if (!mounted) return;
      setState(() {
        _speaking = false;
        _loading = false;
      });
    });
    _tts.setErrorHandler((_) {
      if (!mounted) return;
      setState(() {
        _speaking = false;
        _loading = false;
      });
    });
  }

  /// Maps the visitor's profile language code to a TTS-supported locale.
  /// Falls back to en-AU when the language is unknown or unsupported.
  String _resolveTtsLanguage(String code) {
    final normalized = code.trim().toLowerCase();
    const localeMap = {
      'en': 'en-AU',
      'english': 'en-AU',
      'zh': 'zh-CN',
      'chinese': 'zh-CN',
      'zh-cn': 'zh-CN',
      'zh-hk': 'zh-HK',
      'zh-tw': 'zh-TW',
      'ar': 'ar-SA',
      'arabic': 'ar-SA',
      'hi': 'hi-IN',
      'hindi': 'hi-IN',
      'es': 'es-ES',
      'spanish': 'es-ES',
      'fr': 'fr-FR',
      'french': 'fr-FR',
      'de': 'de-DE',
      'german': 'de-DE',
      'it': 'it-IT',
      'italian': 'it-IT',
      'ja': 'ja-JP',
      'japanese': 'ja-JP',
      'ko': 'ko-KR',
      'korean': 'ko-KR',
      'pt': 'pt-BR',
      'portuguese': 'pt-BR',
      'ru': 'ru-RU',
      'russian': 'ru-RU',
      'vi': 'vi-VN',
      'vietnamese': 'vi-VN',
      'pa': 'pa-IN',
      'punjabi': 'pa-IN',
    };
    return localeMap[normalized] ?? 'en-AU';
  }

  /// Re-applies the TTS voice settings every time playback starts so the
  /// selected profile language is respected even after the user changes it.
  Future<void> _initializeTts() async {
    final profileLanguage = VisitorAuth.currentVisitor?.language ?? 'en';
    final ttsLocale = _resolveTtsLanguage(profileLanguage);

    await _tts.awaitSpeakCompletion(true);
    await _tts.setLanguage(ttsLocale);
    // Natural, conversational Food Discovery Guide voice. Rate 0.82 is
    // closer to everyday human speech and avoids the slow, robotic feel of
    // lower rates. Slightly elevated pitch (1.05) keeps it lively and clear.
    await _tts.setPitch(1.05);
    await _tts.setSpeechRate(0.82);
    await _tts.setVolume(1.0);
    // iOS: play audio even when the device is on silent/ring switch
    await _tts.setSharedInstance(true);
    await _tts.setIosAudioCategory(
      IosTextToSpeechAudioCategory.playback,
      [
        IosTextToSpeechAudioCategoryOptions.allowBluetooth,
        IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
        IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
      ],
      IosTextToSpeechAudioMode.defaultMode,
    );
  }

  String _sanitizeNarration(String raw) {
    var text = raw
        .replaceAll('•', ',')
        .replaceAll(RegExp(r'\n{2,}'), '. ... ')
        .replaceAll('\n', '. ')
        .replaceAll(RegExp(r'\.\s*\.'), '.')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    text = text.replaceAllMapped(
      RegExp(r'\.\s+(?=[A-Z])'),
      (m) => '. ... ',
    );
    return text;
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _togglePlayback() async {
    if (_speaking) {
      await _tts.stop();
      if (!mounted) return;
      setState(() {
        _speaking = false;
        _loading = false;
      });
      return;
    }

    setState(() => _loading = true);
    try {
      await _initializeTts();
      final narration = _sanitizeNarration(widget.narrationText);
      if (narration.isEmpty) {
        throw Exception('Narration text is empty');
      }
      await _tts.stop();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      await _tts.speak(narration);
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.unableToStartNarration),
        ),
      );
      setState(() {
        _loading = false;
        _speaking = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-read the visitor's language on every build so the play button label
    // and any future TTS configuration reflect the latest profile selection.
    final profileLanguage = VisitorAuth.currentVisitor?.language ?? 'en';
    final ttsLocale = _resolveTtsLanguage(profileLanguage);
    // Apply the locale early so a language change takes effect before the
    // user presses play again.
    _tts.setLanguage(ttsLocale).catchError((_) {});

    final l10n = AppLocalizations.of(context)!;
    final buttonIcon = _speaking
        ? Icons.stop_circle_rounded
        : Icons.record_voice_over_rounded;
    final buttonLabel = _speaking ? l10n.stop : l10n.foodDiscoveryGuide;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppPalette.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppPalette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ElevatedButton.icon(
            onPressed: _loading ? null : _togglePlayback,
            icon: _loading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(buttonIcon, size: 18),
            label: Text(buttonLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppPalette.ochre,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.helperText,
            style: const TextStyle(
              fontSize: 12,
              color: AppPalette.mutedText,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
