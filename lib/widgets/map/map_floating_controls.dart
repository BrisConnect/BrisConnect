import 'package:flutter/material.dart';

import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/map/map_models.dart';

/// Modern floating action buttons that overlay the map.
///
/// Includes My Location, Compass (rotate to north) and Map Style controls.
class MapFloatingButtons extends StatelessWidget {
  const MapFloatingButtons({
    super.key,
    required this.followingUser,
    required this.onMyLocation,
    required this.onCompass,
    required this.onMapStyle,
    this.bearing = 0,
  });

  final bool followingUser;
  final VoidCallback onMyLocation;
  final VoidCallback onCompass;
  final VoidCallback onMapStyle;
  final double bearing;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CircularMapButton(
          tooltip: followingUser ? 'Following GPS' : 'My Location',
          icon: followingUser
              ? Icons.my_location_rounded
              : Icons.location_searching_rounded,
          isActive: followingUser,
          onTap: onMyLocation,
          semanticLabel: 'My Location',
        ),
        const SizedBox(height: 12),
        _CircularMapButton(
          tooltip: 'Compass',
          icon: Icons.explore_rounded,
          isActive: false,
          onTap: onCompass,
          semanticLabel: 'Compass',
          rotation: bearing,
        ),
        const SizedBox(height: 12),
        _CircularMapButton(
          tooltip: 'Map Style',
          icon: Icons.layers_rounded,
          isActive: false,
          onTap: onMapStyle,
          semanticLabel: 'Map Style',
        ),
      ],
    );
  }
}

/// Rounded floating bottom action bar for the map.
///
/// Includes My Location, Nearby results, Food filters and Favourites.
class MapBottomActionBar extends StatelessWidget {
  const MapBottomActionBar({
    super.key,
    required this.followingUser,
    required this.resultsVisible,
    required this.selectedType,
    required this.showOnlyFavourites,
    required this.onMyLocation,
    required this.onNearby,
    required this.onFood,
    required this.onFavourites,
    required this.resultCount,
    this.onRadius,
  });

  final bool followingUser;
  final bool resultsVisible;
  final MapPinType? selectedType;
  final bool showOnlyFavourites;
  final VoidCallback onMyLocation;
  final VoidCallback onNearby;
  final VoidCallback onFood;
  final VoidCallback onFavourites;
  final VoidCallback? onRadius;
  final int resultCount;

  @override
  Widget build(BuildContext context) {
    final actions = [
      _ActionChip(
        icon: Icons.my_location_rounded,
        label: 'My Location',
        isActive: followingUser,
        onTap: onMyLocation,
      ),
      _ActionChip(
        icon: Icons.near_me_rounded,
        label: 'Nearby',
        isActive: resultsVisible,
        badge: resultCount > 0 ? '$resultCount' : null,
        onTap: onNearby,
      ),
      _ActionChip(
        icon: Icons.restaurant_rounded,
        label: 'Food',
        isActive: selectedType == MapPinType.food,
        onTap: onFood,
      ),
      _ActionChip(
        icon: Icons.favorite_rounded,
        label: 'Favourites',
        isActive: showOnlyFavourites,
        onTap: onFavourites,
      ),
    ];

    return Hero(
      tag: 'map-bottom-action-bar',
      child: Material(
        color: Colors.white.withValues(alpha: 0.98),
        elevation: 6,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: actions.asMap().entries.map((entry) {
                final child = entry.value;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    child,
                    if (entry.key < actions.length - 1)
                      const SizedBox(width: 6),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircularMapButton extends StatelessWidget {
  const _CircularMapButton({
    required this.tooltip,
    required this.icon,
    required this.isActive,
    required this.onTap,
    required this.semanticLabel,
    this.rotation = 0,
  });

  final String tooltip;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;
  final String semanticLabel;
  final double rotation;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white.withValues(alpha: 0.97),
        elevation: 3,
        shadowColor: Colors.black.withValues(alpha: 0.1),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          hoverColor: AppPalette.ochre.withValues(alpha: 0.08),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isActive
                    ? AppPalette.deepBlue.withValues(alpha: 0.5)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            alignment: Alignment.center,
            child: AnimatedRotation(
              turns: rotation / 360,
              duration: const Duration(milliseconds: 300),
              child: Icon(
                icon,
                size: 22,
                color: isActive ? AppPalette.deepBlue : AppPalette.charcoal,
                semanticLabel: semanticLabel,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isActive ? AppPalette.ochre : Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        hoverColor: isActive
            ? AppPalette.ochre.withValues(alpha: 0.9)
            : AppPalette.ochre.withValues(alpha: 0.08),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Icon(icon,
                      size: 22,
                      color: isActive ? Colors.white : AppPalette.charcoal),
                  if (badge != null)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: AppPalette.deepBlue,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          badge!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isActive ? Colors.white : AppPalette.charcoal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
