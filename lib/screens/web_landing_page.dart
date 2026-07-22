import 'package:flutter/material.dart';
import 'package:brisconnect/theme/app_palette.dart';

/// Web landing page with hero section and Launch Web App button
class WebLandingPage extends StatefulWidget {
  const WebLandingPage({super.key});

  @override
  State<WebLandingPage> createState() => _WebLandingPageState();
}

class _WebLandingPageState extends State<WebLandingPage> {
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 768;

    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Hero Section
            Container(
              width: double.infinity,
              height: isMobile ? 500 : 600,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppPalette.deepBlue,
                    AppPalette.deepBlue.withValues(alpha: 0.8),
                  ],
                ),
              ),
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(isMobile ? 24 : 48),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo/Icon
                      Container(
                        width: isMobile ? 80 : 120,
                        height: isMobile ? 80 : 120,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              AppPalette.ochre,
                              AppPalette.gold,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: AppPalette.ochre.withValues(alpha: 0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.location_on_rounded,
                          color: Colors.white,
                          size: isMobile ? 40 : 60,
                        ),
                      ),
                      SizedBox(height: isMobile ? 24 : 32),

                      // Title
                      Text(
                        'Discover Brisbane',
                        style: Theme.of(context).textTheme.displayLarge?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: isMobile ? 32 : 56,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isMobile ? 12 : 16),

                      // Subtitle
                      Text(
                        'Explore events, attractions, and experiences across Brisbane',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: isMobile ? 14 : 18,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: isMobile ? 32 : 48),

                      // Launch Button
                      ElevatedButton.icon(
                        onPressed: _launchApp,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(
                          'Launch Web App',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                fontSize: isMobile ? 14 : 16,
                              ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppPalette.ochre,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: isMobile ? 32 : 48,
                            vertical: isMobile ? 14 : 18,
                          ),
                          elevation: 8,
                          shadowColor: AppPalette.ochre.withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Features Section
            Padding(
              padding: EdgeInsets.all(isMobile ? 24 : 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Why Choose BrisConnect+',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  SizedBox(height: isMobile ? 24 : 32),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = (constraints.maxWidth - 16) / (isMobile ? 1 : 3);
                      return Wrap(
                        spacing: 16,
                        runSpacing: 16,
                        children: [
                          _buildFeatureCard(
                            context,
                            'Discover Events',
                            'Browse upcoming events across Brisbane',
                            Icons.event_rounded,
                            itemWidth,
                          ),
                          _buildFeatureCard(
                            context,
                            'Explore Attractions',
                            'Find top attractions and landmarks',
                            Icons.place_rounded,
                            itemWidth,
                          ),
                          _buildFeatureCard(
                            context,
                            'Search & Filter',
                            'Easily search and filter by category',
                            Icons.search_rounded,
                            itemWidth,
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    double width,
  ) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppPalette.ochre.withValues(alpha: 0.2),
                      AppPalette.ochre.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  color: AppPalette.ochre,
                  size: 32,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppPalette.mutedText,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _launchApp() {
    Navigator.of(context).pushReplacementNamed('/web/home');
  }
}
