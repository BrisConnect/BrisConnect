import 'package:flutter/material.dart';

import 'package:brisconnect/theme/app_palette.dart';

/// A selectable, rounded category chip used in horizontal filter lists.
///
/// Adapts its background and foreground colors based on [isSelected].
class CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry? padding;

  const CategoryChip({
    super.key,
    required this.label,
    this.isSelected = false,
    this.onTap,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: padding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? AppPalette.ochre : Colors.white,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isSelected ? AppPalette.ochre : AppPalette.border,
              width: 1,
            ),
            boxShadow: [
              if (!isSelected)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppPalette.charcoal,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
