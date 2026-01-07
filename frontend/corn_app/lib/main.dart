import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'features/diagnosis/presentation/pages/main_dashboard_page.dart';

void main() {
  runApp(const CornNutrientApp());
}

class CornNutrientApp extends StatelessWidget {
  const CornNutrientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Corn Nutrient Analyzer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
        textTheme: GoogleFonts.notoSansSinhalaTextTheme(),
      ),
      home: const MainDashboardPage(),
    );
  }
}
