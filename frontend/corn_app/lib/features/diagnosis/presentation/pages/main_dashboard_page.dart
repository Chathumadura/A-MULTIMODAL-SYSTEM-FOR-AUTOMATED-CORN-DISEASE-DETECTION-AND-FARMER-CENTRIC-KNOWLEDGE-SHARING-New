import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'nutrient_prediction_page.dart';
import 'corn_yield_page_enhanced.dart';
import '../../../../core/localization/app_localizations.dart';

class MainDashboardPage extends StatelessWidget {
  final Function(Locale) onLanguageChange;

  const MainDashboardPage({super.key, required this.onLanguageChange});

  // --- Brand text like your logo: Corn (green) + Xpert (yellow)
  Widget _cornXpertBrandText({double fontSize = 20}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(bounds),
          child: Text(
            'Corn',
            style: GoogleFonts.ubuntu(
              fontWeight: FontWeight.w900,
              fontSize: fontSize,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.white.withOpacity(0.6),
                  offset: const Offset(0, 0),
                  blurRadius: 8,
                ),
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  offset: const Offset(0, 2),
                  blurRadius: 4,
                ),
              ],
            ),
          ),
        ),
        Text(
          'Xpert',
          style: GoogleFonts.ubuntu(
            fontWeight: FontWeight.w800,
            fontSize: fontSize,
            color: const Color(0xFFF9A825),
            shadows: [
              Shadow(
                color: Colors.orange.withOpacity(0.5),
                offset: const Offset(0, 0),
                blurRadius: 8,
              ),
              Shadow(
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(0, 2),
                blurRadius: 4,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1B1B1B),

        // ✅ AppBar title with icon + styled name
        title: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                'assets/dashboard/app_icon.png',
                width: 28,
                height: 28,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.image_not_supported_outlined,
                    size: 24,
                  );
                },
              ),
            ),
            const SizedBox(width: 10),
            _cornXpertBrandText(fontSize: 20),
          ],
        ),

        actions: [
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language),
            tooltip: loc.language,
            onSelected: onLanguageChange,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: const Locale('en', ''),
                child: Row(
                  children: const [
                    Text('🇬🇧', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 12),
                    Text('English'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: const Locale('si', ''),
                child: Row(
                  children: const [
                    Text('🇱🇰', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 12),
                    Text('සිංහල'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: const Locale('ta', ''),
                child: Row(
                  children: const [
                    Text('🇱🇰', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 12),
                    Text('தமிழ்'),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),

              // Welcome Header
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF2E7D32),
                      Color(0xFF66BB6A),
                      Color(0xFF81C784),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.2),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1B5E20).withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                      spreadRadius: 0,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ✅ “Welcome to CornXpert” with brand style inside
                          Row(
                            children: [
                              Text(
                                'Welcome to ',
                                style: GoogleFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.2),
                                      offset: const Offset(0, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),
                              _cornXpertBrandText(fontSize: 24),
                            ],
                          ),

                          const SizedBox(height: 8),
                          Text(
                            'AI-powered corn farming solutions',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.95),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ✅ Replace leaf icon with your app icon
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(
                          'assets/dashboard/app_icon.png',
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.image_not_supported_outlined,
                              color: Colors.white,
                              size: 48,
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 22),

              Text(
                'Empowering Farmers with Smart AI Solutions',
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1B1B1B),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'AI-powered tools to detect diseases, analyze nutrients, monitor pests, and predict yield.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.black.withOpacity(0.7),
                  letterSpacing: 0.2,
                ),
              ),

              const SizedBox(height: 14),

              GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.80,
                ),
                children: [
                  _FeatureCard(
                    imagePath: 'assets/dashboard/corn_disease.png',
                    title: 'Corn Disease\nDetection',
                    description:
                        'Identify leaf diseases early with AI image analysis.',
                    buttonText: 'Scan Crop',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Disease Detection - Coming Soon'),
                        ),
                      );
                    },
                  ),
                  _FeatureCard(
                    imagePath: 'assets/dashboard/nutrient_analysis.png',
                    title: 'Nutrient Analysis\nTools',
                    description:
                        'Analyze crop nutrient levels from tissue/field data.',
                    buttonText: 'Start Analysis',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const NutrientPredictionPage(),
                        ),
                      );
                    },
                  ),
                  _FeatureCard(
                    imagePath: 'assets/dashboard/pest_alert.png',
                    title: 'Pest Detection\n& Alerts',
                    description: 'Get real-time alerts to protect your crop.',
                    buttonText: 'Check Alerts',
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pest Detection - Coming Soon'),
                        ),
                      );
                    },
                  ),
                  _FeatureCard(
                    imagePath: 'assets/dashboard/yield_prediction.png',
                    title: 'Yield\nPrediction',
                    description: 'Estimate future yield using ML predictions.',
                    buttonText: 'Predict Yield',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CornYieldPageEnhanced(
                            onLanguageChange: onLanguageChange,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/* ----------------- HERO ----------------- */
// (unchanged code below)

class _HeroBanner extends StatelessWidget {
  final VoidCallback onPrimaryTap;
  final VoidCallback onSecondaryTap;

  const _HeroBanner({required this.onPrimaryTap, required this.onSecondaryTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2E8D4E), Color(0xFF66BB6A)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: const SizedBox.shrink(),
    );
  }
}

/* ----------------- FEATURE CARD ----------------- */

class _FeatureCard extends StatelessWidget {
  final String imagePath;
  final String title;
  final String description;
  final String buttonText;
  final VoidCallback onTap;

  const _FeatureCard({
    required this.imagePath,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF9C4), // Very light yellow
            Color(0xFFFFF59D), // Light yellow
            Color(0xFFC8E6C9), // Very light green
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withOpacity(0.7), width: 2.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 10),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // image (top)
            Expanded(
              flex: 5,
              child: Container(
                color: Colors.white,
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(Icons.image_not_supported_outlined),
                    );
                  },
                ),
              ),
            ),

            // text + button (bottom)
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      height: 38,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1B5E20).withOpacity(0.5),
                              blurRadius: 16,
                              offset: const Offset(0, 8),
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: Colors.black.withOpacity(0.15),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: onTap,
                            borderRadius: BorderRadius.circular(16),
                            child: Center(
                              child: Text(
                                buttonText,
                                style: GoogleFonts.poppins(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
