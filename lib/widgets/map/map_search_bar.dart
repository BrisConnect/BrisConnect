// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import 'package:brisconnect/theme/app_palette.dart';

/// Premium floating search bar for the discovery map.
///
/// Includes a search icon, optional voice search (where supported), a filter
/// button and a nearby/radius button.
class MapSearchBar extends StatefulWidget {
  const MapSearchBar({
    super.key,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.onFilterTap,
    this.onNearbyTap,
    this.onClear,
    this.onBackPressed,
    this.hintText = 'Search places, categories, locations',
    this.filterActive = false,
    this.nearbyActive = false,
  });

  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onFilterTap;
  final VoidCallback? onNearbyTap;
  final VoidCallback? onClear;
  final VoidCallback? onBackPressed;
  final String hintText;
  final bool filterActive;
  final bool nearbyActive;

  @override
  State<MapSearchBar> createState() => _MapSearchBarState();
}

class _MapSearchBarState extends State<MapSearchBar>
    with SingleTickerProviderStateMixin {
  final SpeechToText _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _isListening = false;
  Timer? _listeningTimer;
  late AnimationController _micPulseController;
  String? _lastVoiceText;

  @override
  void initState() {
    super.initState();
    _micPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    if (!kIsWeb) {
      _initSpeech();
    }
  }

  Future<void> _initSpeech() async {
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            _stopListening();
          }
        },
        onError: (_) => _stopListening(),
      );
      if (mounted) setState(() {});
    } catch (_) {
      _speechAvailable = false;
    }
  }

  void _startListening() async {
    if (!_speechAvailable) {
      _showMicUnavailable();
      return;
    }
    if (_speech.isListening) return;

    setState(() => _isListening = true);
    _micPulseController.repeat(reverse: true);

    await _speech.listen(
      onResult: (result) {
        final text = result.recognizedWords;
        if (text.isNotEmpty && text != _lastVoiceText) {
          _lastVoiceText = text;
          widget.controller.text = text;
          widget.onChanged?.call(text);
        }
        if (result.finalResult) {
          _stopListening();
          widget.onSubmitted?.call(text);
        }
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 2),
      partialResults: true,
    );

    // Safety timeout.
    _listeningTimer?.cancel();
    _listeningTimer = Timer(const Duration(seconds: 12), _stopListening);
  }

  void _stopListening() {
    _listeningTimer?.cancel();
    if (_speech.isListening) _speech.stop();
    if (mounted) {
      setState(() => _isListening = false);
      _micPulseController.stop();
      _micPulseController.reset();
    }
  }

  void _showMicUnavailable() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Voice search is not available on this device.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _stopListening();
    _micPulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;

    return Hero(
      tag: 'map-search-bar',
      child: Material(
        color: Colors.white.withValues(alpha: 0.97),
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              if (widget.onBackPressed != null)
                _ToolbarButton(
                  icon: Icons.arrow_back_rounded,
                  onTap: widget.onBackPressed!,
                ),
              const Padding(
                padding: EdgeInsets.only(left: 14, right: 8),
                child: Icon(Icons.search_rounded,
                    color: AppPalette.mutedText, size: 22),
              ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: textTheme.bodyLarge?.copyWith(
                      color: AppPalette.mutedText,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: textTheme.bodyLarge?.copyWith(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppPalette.charcoal,
                  ),
                ),
              ),
              if (widget.controller.text.isNotEmpty)
                _ToolbarButton(
                  icon: Icons.close_rounded,
                  onTap: () {
                    widget.controller.clear();
                    widget.onChanged?.call('');
                    widget.onClear?.call();
                  },
                ),
              AnimatedBuilder(
                animation: _micPulseController,
                builder: (context, child) {
                  final scale =
                      _isListening ? 1 + _micPulseController.value * 0.15 : 1.0;
                  return Transform.scale(
                    scale: scale,
                    child: _ToolbarButton(
                      icon: _isListening
                          ? Icons.mic_rounded
                          : Icons.mic_none_rounded,
                      color: _isListening
                          ? AppPalette.ochre
                          : AppPalette.mutedText,
                      onTap: _isListening ? _stopListening : _startListening,
                    ),
                  );
                },
              ),
              _ToolbarButton(
                icon: Icons.tune_rounded,
                color: widget.filterActive
                    ? AppPalette.ochre
                    : AppPalette.mutedText,
                onTap: widget.onFilterTap,
              ),
              if (widget.onNearbyTap != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _ToolbarButton(
                    icon: Icons.near_me_rounded,
                    color: widget.nearbyActive
                        ? AppPalette.deepBlue
                        : AppPalette.mutedText,
                    onTap: widget.onNearbyTap,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        hoverColor: AppPalette.ochre.withValues(alpha: 0.08),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: color ?? AppPalette.mutedText, size: 22),
        ),
      ),
    );
  }
}
