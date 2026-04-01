import 'package:flutter/material.dart';
import 'package:brisconnect/screens/attraction_detail_screen.dart';
import 'package:brisconnect/screens/approved_attractions_map_screen.dart';
import 'package:brisconnect/services/approved_attraction_service.dart';
import 'package:brisconnect/theme/app_palette.dart';
import 'package:brisconnect/widgets/inline_status_message.dart';
import 'package:brisconnect/widgets/logo_app_bar_title.dart';

class AttractionsScreen extends StatelessWidget {
  AttractionsScreen({
    super.key,
    ApprovedAttractionService? attractionService,
  }) : attractionService = attractionService ?? ApprovedAttractionService();

  final ApprovedAttractionService attractionService;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppPalette.background,
      appBar: AppBar(
        title: const LogoAppBarTitle('Cultural Attractions'),
        actions: [
          IconButton(
            tooltip: 'Approved attractions map',
            icon: const Icon(Icons.map_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ApprovedAttractionsMapScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<ApprovedAttraction>>(
        stream: attractionService.watchApprovedAttractions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: InlineStatusMessage(
                  message: 'Unable to load attractions right now. Please try again.',
                  type: InlineStatusType.error,
                  actionLabel: 'Retry',
                  onAction: () {},
                ),
              ),
            );
          }

          final attractions = snapshot.data ?? const <ApprovedAttraction>[];
          if (attractions.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No approved attractions available right now.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppPalette.mutedText),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: attractions.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final attraction = attractions[index];
              return Card(
                color: AppPalette.surface,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AttractionDetailScreen(
                          attraction: attraction,
                          allAttractions: attractions,
                        ),
                      ),
                    );
                  },
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
                            const Icon(Icons.chevron_right_rounded, color: AppPalette.mutedText),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          attraction.category ?? 'Attraction',
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
                        Text(
                          attraction.description,
                          style: const TextStyle(color: AppPalette.charcoal),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
