import 'package:flutter/material.dart';

import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/map/map_models.dart';

/// Row of live information chips for a map pin.
///
/// Shows current crowd level, estimated wait time, open now, closing soon,
/// premium partner and verified business badges when applicable.
class MapLiveBadges extends StatelessWidget {
  const MapLiveBadges({
    super.key,
    required this.pin,
    this.spacing = 6,
    this.runSpacing = 6,
    this.compact = false,
  });

  final MapPin pin;
  final double spacing;
  final double runSpacing;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    if (pin.isPremium) {
      chips.add(_Badge(
        icon: Icons.workspace_premium_rounded,
        label: 'Premium',
        color: const Color(0xFF8B5CF6),
        compact: compact,
      ));
    }

    if (pin.isVerified) {
      chips.add(_Badge(
        icon: Icons.verified_rounded,
        label: 'Verified',
        color: AppPalette.deepBlue,
        compact: compact,
      ));
    }

    if (pin.isPopular) {
      chips.add(_Badge(
        icon: Icons.local_fire_department_rounded,
        label: 'Popular',
        color: AppPalette.ochre,
        compact: compact,
      ));
    }

    if (pin.crowdLevel != null && pin.crowdLevel!.isNotEmpty) {
      final crowd = pin.crowdLevel!.toLowerCase();
      final color = crowd.contains('high')
          ? const Color(0xFFEF4444)
          : crowd.contains('moder')
              ? const Color(0xFFF59E0B)
              : const Color(0xFF10B981);
      chips.add(_Badge(
        icon: Icons.people_outline_rounded,
        label: 'Crowd: ${pin.crowdLevel}',
        color: color,
        compact: compact,
      ));
    }

    if (pin.waitTime != null && pin.waitTime!.isNotEmpty) {
      chips.add(_Badge(
        icon: Icons.timer_outlined,
        label: 'Wait ${pin.waitTime}',
        color: AppPalette.mutedText,
        compact: compact,
      ));
    }

    if (pin.isClosingSoon == true) {
      chips.add(_Badge(
        icon: Icons.access_time_filled_rounded,
        label: 'Closing soon',
        color: const Color(0xFFF59E0B),
        compact: compact,
      ));
    } else if (pin.isOpenNow == true) {
      chips.add(_Badge(
        icon: Icons.check_circle_rounded,
        label: 'Open now',
        color: const Color(0xFF10B981),
        compact: compact,
      ));
    } else if (pin.isOpenNow == false) {
      chips.add(_Badge(
        icon: Icons.cancel_rounded,
        label: 'Closed',
        color: const Color(0xFF9CA3AF),
        compact: compact,
      ));
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: spacing,
      runSpacing: runSpacing,
      children: chips,
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.icon,
    required this.label,
    required this.color,
    required this.compact,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 6 : 8,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 11 : 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
