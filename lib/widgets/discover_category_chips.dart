import 'package:flutter/material.dart';

import 'package:brisconnect/theme/app_palette.dart';

/// A quick-category chip list for the discover feed (e.g. Cafes, Burgers,
/// Trending).
class DiscoverCategoryChips extends StatelessWidget {
  final List<DiscoverQuickCategory> categories;
  final String? selectedLabel;
  final ValueChanged<DiscoverQuickCategory> onSelected;

  const DiscoverCategoryChips({
    super.key,
    required this.categories,
    this.selectedLabel,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: categories.map((category) {
          final isActive = selectedLabel == category.label;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: _CategoryChip(
              label: category.label,
              emoji: category.emoji,
              isSelected: isActive,
              onTap: () => onSelected(category),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class DiscoverQuickCategory {
  final String label;
  final String emoji;

  const DiscoverQuickCategory({required this.label, required this.emoji});
}

class _CategoryChip extends StatelessWidget {
  final String label;
  final String emoji;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.emoji,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppPalette.ochre : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppPalette.ochre : AppPalette.border,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppPalette.ochre.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppPalette.charcoal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
