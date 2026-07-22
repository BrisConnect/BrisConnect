import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
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
  bool _ttsInitialized = false;
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

  Future<void> _initializeTts() async {
    if (_ttsInitialized) return;
    try {
      await _tts.awaitSpeakCompletion(true);
      await _tts.setLanguage('en-AU');
      // Warm, natural tour-guide voice: slightly lower pitch, relaxed pace
      await _tts.setPitch(0.92);
      await _tts.setSpeechRate(0.45);
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
      _ttsInitialized = true;
    } catch (_) {
      _ttsInitialized = true;
    }
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to start AI narration right now.'),
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
    final buttonIcon = _speaking
        ? Icons.stop_circle_rounded
        : Icons.record_voice_over_rounded;
    final buttonLabel = _speaking ? 'Stop' : 'AI Tour Guide';

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
