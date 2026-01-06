import 'package:flutter/material.dart';
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
        title: const Text('Corn Nutrient Analyzer'),
        actions: [
          PopupMenuButton<Locale>(
            icon: const Icon(Icons.language),
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
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Main Dashboard',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Select a module to continue',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.auto_graph_rounded),
                  label: Text(loc.cornYieldPrediction),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => CornYieldPageEnhanced(onLanguageChange: onLanguageChange),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.analytics_rounded),
                  label: const Text('Nutrient Prediction'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const NutrientPredictionPage(),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
