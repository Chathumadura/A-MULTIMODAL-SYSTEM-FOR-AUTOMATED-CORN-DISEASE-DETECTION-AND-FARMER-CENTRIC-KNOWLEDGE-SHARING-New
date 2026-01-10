import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'nutrient_prediction_page.dart';
import 'corn_yield_page_enhanced.dart';
import '../../../../core/localization/app_localizations.dart';

class MainDashboardPage extends StatelessWidget {
  final Function(Locale) onLanguageChange;

  const MainDashboardPage({super.key, required this.onLanguageChange});

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2E8D4E),
        title: Text(
          'CornXpert',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.white,
            letterSpacing: 0.5,
          ),
        ),
        actions: [
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language, color: Colors.white),
            tooltip: loc.language,
            onSelected: onLanguageChange,
            itemBuilder: (context) => [
              PopupMenuItem(
                value: const Locale('en', ''),
                child: Row(
                  children: [
                    Text('🇬🇧', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 12),
                    Text('English'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: const Locale('si', ''),
                child: Row(
                  children: [
                    Text('🇱🇰', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 12),
                    Text('\u0DC3\u0DD2\u0D82\u0DC4\u0DBD'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: const Locale('ta', ''),
                child: Row(
                  children: [
                    Text('🇱🇰', style: TextStyle(fontSize: 20)),
                    SizedBox(width: 12),
                    Text('\u0BA4\u0BAE\u0BBF\u0BB4\u0BCD'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF2E8D4E), // Dark green
              const Color(0xFF66BB6A), // Medium green
              const Color(0xFFFFF9C4), // Light yellow
            ],
            stops: [0.0, 0.3, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                // Hero Section with Illustration
                _buildHeroSection(context),
                const SizedBox(height: 24),

                // Section Title
                Text(
                  'Smart AI Solutions',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1F2D1F),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'AI-powered tools for data-driven decisions',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 16),

                // Grid of Module Cards
                Expanded(
                  child: GridView.count(
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.85,
                    children: [
                      _buildModuleCard(
                        context,
                        title: 'Corn Yield\nPrediction',
                        description: 'Predict yield with ML',
                        icon: Icons.auto_graph_rounded,
                        gradient: [
                          const Color(0xFF2E8D4E),
                          const Color(0xFF4FB26C),
                        ],
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
                      _buildModuleCard(
                        context,
                        title: 'Nutrient\nPrediction',
                        description: 'Analyze soil nutrients',
                        icon: Icons.eco_rounded,
                        gradient: [
                          const Color(0xFF4CAF50),
                          const Color(0xFF8BC34A),
                        ],
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const NutrientPredictionPage(),
                            ),
                          );
                        },
                      ),
                      _buildModuleCard(
                        context,
                        title: 'Detect Corn\nDiseases',
                        description: 'Identify plant diseases',
                        icon: Icons.biotech_rounded,
                        gradient: [
                          const Color(0xFF66BB6A),
                          const Color(0xFF9CCC65),
                        ],
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Disease Detection - Coming Soon'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        },
                      ),
                      _buildModuleCard(
                        context,
                        title: 'Pest\nDetection',
                        description: 'Monitor pest activity',
                        icon: Icons.bug_report_rounded,
                        gradient: [
                          const Color(0xFF81C784),
                          const Color(0xFFAED581),
                        ],
                        onTap: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Pest Detection - Coming Soon'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.2),
            Colors.white.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Transform Farming\nwith AI',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Data-driven insights for better yields',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.95),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Animated illustration placeholder
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(Icons.agriculture_rounded, size: 32, color: Colors.white),
                Positioned(
                  top: 6,
                  right: 6,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatCard('5000+', 'Farmers'),
          _buildStatCard('4', 'AI Solutions'),
          _buildStatCard('95%', 'Accuracy'),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1F2D1F),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildModuleCard(
    BuildContext context, {
    required String title,
    required String description,
    required IconData icon,
    required List<Color> gradient,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFFFFFDE7), // Very light yellow
              const Color(0xFFFFF9C4), // Light yellow
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            // Bottom-right shadow (darker)
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(6, 6),
            ),
            // Top-left highlight (lighter)
            BoxShadow(
              color: Colors.white.withOpacity(0.7),
              blurRadius: 16,
              offset: const Offset(-4, -4),
            ),
            // Colored glow
            BoxShadow(
              color: gradient[0].withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradient,
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(3, 3),
                        ),
                        BoxShadow(
                          color: gradient[1].withOpacity(0.5),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(icon, size: 28, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1F2D1F),
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
                      color: Colors.grey.shade700,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
