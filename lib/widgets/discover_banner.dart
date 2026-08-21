import 'package:flutter/material.dart';

import 'package:brisconnect/services/weather_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Brisbane skyline banner used in the visitor discover feed.
///
/// Keeps Brisbane as a subtle backdrop with a dark overlay, bottom gradient
/// fade into the scaffold background, a location label, and an optional
/// weather chip.
class DiscoverBanner extends StatelessWidget {
  final double height;
  final BrisbaneWeather? weather;
  final bool isWeatherLoading;

  const DiscoverBanner({
    super.key,
    this.height = 180,
    this.weather,
    this.isWeatherLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final scaffoldBackground = Theme.of(context).scaffoldBackgroundColor;

    return SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Skyline image fills without distortion.
          Image.asset(
            'assets/Brisbane banner.webp',
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            errorBuilder: (_, __, ___) => Container(
              color: AppPalette.surfaceAlt,
            ),
          ),

          // Subtle dark overlay.
          Container(
            color: Colors.black.withValues(alpha: 0.18),
          ),

          // Bottom gradient fade into page background.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: height * 0.55,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    scaffoldBackground.withValues(alpha: 0.55),
                    scaffoldBackground,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),

          // Location label.
          Positioned(
            left: 20,
            bottom: 22,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.92),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.location_on_rounded,
                    color: AppPalette.ochre,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Brisbane City',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    Text(
                      'Queensland, Australia',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        shadows: [
                          Shadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Weather chip.
          Positioned(
            right: 20,
            top: 14,
            child: _WeatherChip(
              weather: weather,
              isLoading: isWeatherLoading,
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherChip extends StatelessWidget {
  final BrisbaneWeather? weather;
  final bool isLoading;

  const _WeatherChip({this.weather, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: isLoading
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppPalette.ochre,
              ),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (weather != null && weather!.iconUrl.isNotEmpty)
                  Image.network(
                    weather!.iconUrl,
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.wb_sunny_rounded,
                      color: AppPalette.ochre,
                      size: 18,
                    ),
                  )
                else
                  const Icon(
                    Icons.wb_sunny_rounded,
                    color: AppPalette.ochre,
                    size: 18,
                  ),
                const SizedBox(width: 6),
                Text(
                  weather != null
                      ? '${weather!.temperature.round()}°C'
                      : '--°C',
                  style: const TextStyle(
                    color: AppPalette.charcoal,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
    );
  }
}
