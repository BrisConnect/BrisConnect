import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:brisconnect/services/weather_service.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Brisbane skyline banner that fades naturally into the page background.
///
/// Displays a subtle dark overlay and bottom gradient so the restaurant
/// content below becomes the visual focal point. Includes a location label
/// and an optional weather chip.
class BrisbaneBannerWidget extends StatelessWidget {
  /// Height of the banner in logical pixels.
  final double height;

  /// Optional weather data to display in the top-right chip.
  final BrisbaneWeather? weather;

  /// Whether the weather chip should show a loading indicator.
  final bool isWeatherLoading;

  /// Asset path for the skyline image.
  final String imageAssetPath;

  const BrisbaneBannerWidget({
    super.key,
    this.height = 180,
    this.weather,
    this.isWeatherLoading = false,
    this.imageAssetPath = 'assets/Brisbane banner.webp',
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
          // Skyline image fills the banner without distortion.
          Image.asset(
            imageAssetPath,
            fit: BoxFit.cover,
            alignment: Alignment.bottomCenter,
            errorBuilder: (_, __, ___) => Container(
              color: AppPalette.surfaceAlt,
            ),
          ),

          // Dark overlay for readability (15–20% opacity).
          Container(
            color: Colors.black.withValues(alpha: 0.18),
          ),

          // Bottom gradient that blends into the scaffold background.
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
                    color: Colors.white.withValues(alpha: 0.9),
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
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
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
                        color: Colors.white.withValues(alpha: 0.75),
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
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
            top: 16,
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
                  CachedNetworkImage(
                    imageUrl: weather!.iconUrl,
                    width: 28,
                    height: 28,
                    fit: BoxFit.contain,
                    errorWidget: (_, __, ___) => const Icon(
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
