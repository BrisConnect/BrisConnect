import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:brisconnect/theme/app_palette.dart';

class AudioGuideWidget extends StatefulWidget {
  const AudioGuideWidget({
    super.key,
    required this.narrationText,
    required this.helperText,
  });

  final String narrationText;
  final String helperText;

  @override
  State<AudioGuideWidget> createState() => _AudioGuideWidgetState();
}

class _AudioGuideWidgetState extends State<AudioGuideWidget> {
  late final FlutterTts _tts;
  bool _speaking = false;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
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

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _toggleNarration() async {
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
      await _tts.setLanguage('en-AU');
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.45);
      await _tts.speak(widget.narrationText);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to start AI audio guide right now.'),
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
    final buttonIcon =
        _speaking ? Icons.stop_circle_rounded : Icons.record_voice_over_rounded;
    final buttonLabel = _speaking ? 'Stop Narration' : 'Play AI Narration';

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
            onPressed: _loading ? null : _toggleNarration,
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
