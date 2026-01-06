import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/localization/app_localizations.dart';
import 'features/diagnosis/presentation/pages/main_dashboard_page.dart';

void main() {
  runApp(const CornNutrientApp());
}

class CornNutrientApp extends StatefulWidget {
  const CornNutrientApp({super.key});

  @override
  State<CornNutrientApp> createState() => _CornNutrientAppState();
}

class _CornNutrientAppState extends State<CornNutrientApp> {
  Locale _locale = const Locale('en', '');

  void _changeLanguage(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Corn Nutrient Analyzer',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: MainDashboardPage(onLanguageChange: _changeLanguage),
    );
  }
}
