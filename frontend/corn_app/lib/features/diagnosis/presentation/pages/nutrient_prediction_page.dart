import 'package:flutter/material.dart';

class NutrientPredictionPage extends StatelessWidget {
  const NutrientPredictionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrient Prediction')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Icon(Icons.analytics_rounded, size: 80, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'This is your Nutrient Prediction screen.\n'
              'Later add:\n'
              '- Image upload\n'
              '- Backend API call\n'
              '- Result cards (N, P, K, Zn)',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
