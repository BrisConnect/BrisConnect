import 'package:flutter/material.dart';

import 'package:brisconnect/theme/app_palette.dart';

/// Bottom sheet for selecting the discovery radius.
class MapRadiusSheet extends StatelessWidget {
  const MapRadiusSheet({
    super.key,
    required this.selectedKm,
    required this.options,
    required this.onSelected,
  });

  final double selectedKm;
  final List<double> options;
  final ValueChanged<double> onSelected;

  String _label(double km) {
    if (km >= 1000) return 'Entire Brisbane';
    if (km == km.toInt()) return '${km.toInt()} km';
    return '${km.toStringAsFixed(1)} km';
  }

  @override
  Widget build(BuildContext context) {
    return _SheetContainer(
      title: 'Nearby radius',
      subtitle: 'Show places within this distance from Brisbane CBD.',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: options.map((km) {
          final selected = selectedKm == km;
          return ChoiceChip(
            label: Text(_label(km)),
            selected: selected,
            onSelected: (_) {
              onSelected(km);
              Navigator.pop(context);
            },
            selectedColor: AppPalette.ochre,
            backgroundColor: Colors.white,
            labelStyle: TextStyle(
              color: selected ? Colors.white : AppPalette.charcoal,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: BorderSide(
                color: selected ? AppPalette.ochre : AppPalette.border,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Bottom sheet for switching the map style.
class MapStyleSheet extends StatelessWidget {
  const MapStyleSheet({
    super.key,
    required this.currentStyle,
    required this.onSelected,
  });

  final MapStyle currentStyle;
  final ValueChanged<MapStyle> onSelected;

  @override
  Widget build(BuildContext context) {
    final styles = [
      (MapStyle.normal, 'Normal', Icons.map_rounded, Colors.green),
      (MapStyle.satellite, 'Satellite', Icons.satellite_rounded, Colors.blue),
      (MapStyle.terrain, 'Terrain', Icons.terrain_rounded, Colors.brown),
      (MapStyle.dark, 'Dark Mode', Icons.dark_mode_rounded, Colors.purple),
    ];

    return _SheetContainer(
      title: 'Map style',
      subtitle: 'Choose how the map looks.',
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: styles.map((entry) {
          final style = entry.$1;
          final label = entry.$2;
          final icon = entry.$3;
          final accent = entry.$4;
          final selected = currentStyle == style;
          return InkWell(
            onTap: () {
              onSelected(style);
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 76,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: selected ? accent.withValues(alpha: 0.12) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected ? accent : AppPalette.border,
                  width: selected ? 2 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      color: selected ? accent : AppPalette.mutedText,
                      size: 28),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected ? accent : AppPalette.charcoal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Available map rendering styles.
enum MapStyle {
  normal,
  satellite,
  terrain,
  dark,
}

/// Bottom sheet that lists available food categories and lets the user toggle
/// which ones are shown on the map.
class FoodCategorySheet extends StatelessWidget {
  const FoodCategorySheet({
    super.key,
    required this.categories,
    required this.selectedCategories,
    required this.onToggle,
    required this.onClear,
  });

  final List<String> categories;
  final Set<String> selectedCategories;
  final ValueChanged<String> onToggle;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return _SheetContainer(
      title: 'Food Categories',
      subtitle: 'Tap categories to show matching food pins on the map.',
      action: selectedCategories.isNotEmpty
          ? TextButton(
              onPressed: onClear,
              child: const Text(
                'Clear all',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppPalette.ochre),
              ),
            )
          : null,
      // ignore: sort_child_properties_last
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: categories.map((category) {
          final isSelected = selectedCategories.contains(category);
          return GestureDetector(
            onTap: () => onToggle(category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isSelected) ...[
                    const Icon(Icons.check_rounded,
                        size: 14, color: Colors.white),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    category,
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
        }).toList(),
      ),
      footer: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppPalette.ochre,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            textStyle:
                const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: Text(
            selectedCategories.isEmpty
                ? 'Show all food pins'
                : 'Show ${selectedCategories.length} selected',
          ),
        ),
      ),
    );
  }
}

/// Sheet shown when the user chooses navigation directions.
class NavModeSheet extends StatelessWidget {
  const NavModeSheet({super.key, required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    const modes = [
      (icon: Icons.directions_car_rounded, label: 'Drive', mode: 'd'),
      (icon: Icons.directions_walk_rounded, label: 'Walk', mode: 'w'),
      (icon: Icons.directions_bus_rounded, label: 'Transit', mode: 'r'),
      (icon: Icons.directions_bike_rounded, label: 'Bicycle', mode: 'b'),
    ];
    return _SheetContainer(
      title: 'Navigate to $name',
      subtitle: 'Choose travel mode',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: modes
            .map((m) => _ModeButton(
                  icon: m.icon,
                  label: m.label,
                  onTap: () => Navigator.pop(context, m.mode),
                ))
            .toList(),
      ),
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton(
      {required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppPalette.ochre,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  color: AppPalette.deepBlue,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SheetContainer extends StatelessWidget {
  const _SheetContainer({
    required this.title,
    required this.child,
    this.subtitle,
    this.action,
    this.footer,
  });

  final String title;
  final Widget child;
  final String? subtitle;
  final Widget? action;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppPalette.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: AppPalette.deepBlue,
                    ),
                  ),
                ),
                if (action != null) action!,
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style:
                    const TextStyle(fontSize: 13, color: AppPalette.mutedText),
              ),
            ],
            const SizedBox(height: 18),
            child,
            if (footer != null) ...[
              const SizedBox(height: 20),
              footer!,
            ],
          ],
        ),
      ),
    );
  }
}
