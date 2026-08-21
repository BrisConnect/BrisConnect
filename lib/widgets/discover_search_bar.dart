import 'dart:async';

import 'package:flutter/material.dart';

import 'package:brisconnect/theme/app_palette.dart';

/// Search bar used at the top of the visitor discover feed.
///
/// Forwards text changes to [onSearchChanged] after a short debounce and
/// invokes [onFilterTap] when the filter icon is pressed.
///
/// Provide [controller] to share a single [TextEditingController] with the
/// parent widget (e.g. so the parent can read the query for filtering).
class DiscoverSearchBar extends StatefulWidget {
  final TextEditingController? controller;
  final void Function(String)? onSearchChanged;
  final VoidCallback? onFilterTap;

  const DiscoverSearchBar({
    super.key,
    this.controller,
    this.onSearchChanged,
    this.onFilterTap,
  });

  @override
  State<DiscoverSearchBar> createState() => _DiscoverSearchBarState();
}

class _DiscoverSearchBarState extends State<DiscoverSearchBar> {
  final _internalController = TextEditingController();
  Timer? _debounce;

  TextEditingController get _effectiveController =>
      widget.controller ?? _internalController;

  @override
  void dispose() {
    _debounce?.cancel();
    _internalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppPalette.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppPalette.ochre),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: _effectiveController,
              onChanged: (value) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 300), () {
                  widget.onSearchChanged?.call(value);
                });
              },
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => FocusScope.of(context).unfocus(),
              decoration: const InputDecoration(
                border: InputBorder.none,
                hintText: 'Search local food…',
                hintStyle: TextStyle(color: AppPalette.mutedText),
              ),
            ),
          ),
          GestureDetector(
            onTap: widget.onFilterTap,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppPalette.surfaceAlt,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppPalette.border.withValues(alpha: 0.5),
                ),
              ),
              child: const Icon(
                Icons.tune_rounded,
                size: 18,
                color: AppPalette.mutedText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
