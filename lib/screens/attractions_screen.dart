import 'package:flutter/material.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class AttractionsScreen extends StatelessWidget {
  const AttractionsScreen({super.key});

  static const List<_AttractionItem> _attractions = [
    _AttractionItem(
      name: 'South Bank Parklands',
      category: 'Riverfront & Culture',
      location: 'South Brisbane',
      description:
          'A popular cultural precinct with outdoor spaces, galleries, and regular community activities.',
    ),
    _AttractionItem(
      name: 'Queensland Museum',
      category: 'Museum',
      location: 'South Brisbane',
      description:
          'Interactive exhibits, natural history collections, and family-friendly programs.',
    ),
    _AttractionItem(
      name: 'Gallery of Modern Art (GOMA)',
      category: 'Art',
      location: 'South Brisbane',
      description:
          'Contemporary art exhibitions featuring Australian and international artists.',
    ),
    _AttractionItem(
      name: 'Roma Street Parkland',
      category: 'Nature & Recreation',
      location: 'Brisbane City',
      description:
          'A scenic inner-city park with gardens, walking paths, and event-friendly green spaces.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(title: const LogoAppBarTitle('Cultural Attractions')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _attractions.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final attraction = _attractions[index];
          return Card(
            color: AppPalette.surface,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.place, color: AppPalette.ochre),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          attraction.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppPalette.charcoal,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    attraction.category,
                    style: const TextStyle(
                      color: AppPalette.deepBlue,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    attraction.location,
                    style: const TextStyle(color: AppPalette.mutedText),
                  ),
                  const SizedBox(height: 8),
                  Text(attraction.description,
                      style: const TextStyle(color: AppPalette.charcoal)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AttractionItem {
  final String name;
  final String category;
  final String location;
  final String description;

  const _AttractionItem({
    required this.name,
    required this.category,
    required this.location,
    required this.description,
  });
}
