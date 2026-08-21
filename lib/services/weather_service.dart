import 'dart:convert';
import 'package:http/http.dart' as http;

/// Simple weather model for Brisbane.
class BrisbaneWeather {
  const BrisbaneWeather({
    required this.temperature,
    required this.iconUrl,
    required this.description,
  });

  final double temperature;
  final String iconUrl;
  final String description;

  BrisbaneWeather copyWith({
    double? temperature,
    String? iconUrl,
    String? description,
  }) {
    return BrisbaneWeather(
      temperature: temperature ?? this.temperature,
      iconUrl: iconUrl ?? this.iconUrl,
      description: description ?? this.description,
    );
  }
}

/// Fetches current weather for Brisbane from Open-Meteo (free, no API key).
class WeatherService {
  WeatherService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _latitude = -27.47;
  static const _longitude = 153.03;

  Future<BrisbaneWeather> fetchBrisbaneWeather() async {
    final uri = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      {
        'latitude': '$_latitude',
        'longitude': '$_longitude',
        'current_weather': 'true',
      },
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Weather API error: ${response.statusCode}');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final current = json['current_weather'] as Map<String, dynamic>?;

    if (current == null) {
      throw Exception('Weather data missing current_weather');
    }

    final temp = (current['temperature'] as num).toDouble();
    final code = current['weathercode'] as int? ?? 0;
    final isDay = current['is_day'] as int? ?? 1;

    final (iconUrl, description) = _weatherCodeToIcon(code, isDay == 1);

    return BrisbaneWeather(
      temperature: temp,
      iconUrl: iconUrl,
      description: description,
    );
  }

  /// Maps Open-Meteo WMO weather codes to openweathermap icon URLs.
  /// Using 2x PNGs is reliable on both mobile and web.
  (String iconUrl, String description) _weatherCodeToIcon(int code, bool isDay) {
    final suffix = isDay ? 'd' : 'n';
    String icon;
    String desc;

    switch (code) {
      case 0:
        icon = isDay ? '01d' : '01n';
        desc = 'Clear sky';
      case 1:
      case 2:
      case 3:
        icon = isDay ? '02d' : '02n';
        desc = 'Partly cloudy';
      case 45:
      case 48:
        icon = '50$suffix';
        desc = 'Foggy';
      case 51:
      case 53:
      case 55:
        icon = '09$suffix';
        desc = 'Drizzle';
      case 56:
      case 57:
        icon = '09$suffix';
        desc = 'Freezing drizzle';
      case 61:
      case 63:
      case 65:
        icon = '10$suffix';
        desc = 'Rain';
      case 66:
      case 67:
        icon = '10$suffix';
        desc = 'Freezing rain';
      case 71:
      case 73:
      case 75:
        icon = '13$suffix';
        desc = 'Snow';
      case 77:
        icon = '13$suffix';
        desc = 'Snow grains';
      case 80:
      case 81:
      case 82:
        icon = '09$suffix';
        desc = 'Showers';
      case 85:
      case 86:
        icon = '13$suffix';
        desc = 'Snow showers';
      case 95:
      case 96:
      case 99:
        icon = '11$suffix';
        desc = 'Thunderstorm';
      default:
        icon = isDay ? '03d' : '03n';
        desc = 'Cloudy';
    }

    return (
      'https://openweathermap.org/img/wn/$icon@2x.png',
      desc,
    );
  }

  void dispose() {
    _client.close();
  }
}
