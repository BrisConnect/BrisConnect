import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Compact AI Assistant card for the Business Owner Dashboard.
/// Features an animated assistant icon, contextual message, and quick actions.
/// Desktop-only. Positioned alongside Gemini Insights card.
class AiAssistantCard extends StatefulWidget {
  /// Current business owner's name
  final String businessName;

  /// Contextual message from dashboard analytics
  final String message;

  /// Callback when Create AI Post is clicked
  final VoidCallback? onCreatePost;

  /// Callback when View Insights is clicked
  final VoidCallback? onViewInsights;

  const AiAssistantCard({
    super.key,
    required this.businessName,
    this.message = 'Hi! Need help growing your business today?',
    this.onCreatePost,
    this.onViewInsights,
  });

  @override
  State<AiAssistantCard> createState() => _AiAssistantCardState();
}

class _AiAssistantCardState extends State<AiAssistantCard>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  late FlutterTts _tts;
  bool _speechEnabled = false;
  bool _isSpeaking = false;
  bool _prefersReducedMotion = false;

  @override
  void initState() {
    super.initState();
    _initializeTts();
    _initializeAnimations();
    _checkReducedMotionPreference();
  }

  void _initializeTts() async {
    _tts = FlutterTts();
    try {
      await _tts.setLanguage('en-US');
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.5);
      _tts.setCompletionHandler(() {
        if (mounted) setState(() => _isSpeaking = false);
      });
      setState(() => _speechEnabled = true);
    } catch (e) {
      debugPrint('TTS initialization failed: $e');
    }
  }

  void _checkReducedMotionPreference() {
    _prefersReducedMotion = MediaQuery.of(context).disableAnimations;
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (!_prefersReducedMotion) {
      _pulseController.repeat(reverse: true);
    }
  }

  Future<void> _speak() async {
    if (!_speechEnabled || _isSpeaking || _prefersReducedMotion) return;
    setState(() => _isSpeaking = true);
    try {
      await _tts.speak(widget.message);
    } catch (e) {
      debugPrint('Speech failed: $e');
      setState(() => _isSpeaking = false);
    }
  }

  void _stopSpeaking() async {
    await _tts.stop();
    setState(() => _isSpeaking = false);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _tts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppPalette.ochre.withValues(alpha: 0.3),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppPalette.ochre.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Title
          Row(
            children: [
              ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppPalette.ochre.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.support_agent_rounded,
                    color: AppPalette.ochre,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'AI Assistant',
                      style: TextStyle(
                        color: AppPalette.charcoal,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Grow your business smarter',
                      style: TextStyle(
                        color: AppPalette.mutedText,
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (_speechEnabled)
                GestureDetector(
                  onTap: _isSpeaking ? _stopSpeaking : _speak,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: _isSpeaking
                          ? AppPalette.ochre.withValues(alpha: 0.15)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      _isSpeaking
                          ? Icons.volume_up_rounded
                          : Icons.volume_mute_rounded,
                      size: 16,
                      color: AppPalette.ochre,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          // Message bubble
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF0),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: AppPalette.ochre.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Text(
              widget.message,
              style: const TextStyle(
                color: AppPalette.charcoal,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: _buildActionButton(
                  'Create Post',
                  Icons.edit_rounded,
                  widget.onCreatePost,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildActionButton(
                  'View Insights',
                  Icons.insights_rounded,
                  widget.onViewInsights,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    VoidCallback? onTap,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: AppPalette.ochre.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: AppPalette.ochre.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: AppPalette.ochre),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppPalette.charcoal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
