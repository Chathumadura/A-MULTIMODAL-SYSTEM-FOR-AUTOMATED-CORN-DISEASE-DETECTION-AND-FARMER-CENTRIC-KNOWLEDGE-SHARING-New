import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../../../core/localization/app_localizations.dart';

const String apiBaseUrl =
    "http://10.0.2.2:8000"; // 10.0.2.2 for Android emulator, 127.0.0.1 for web/desktop

class CornYieldPageEnhanced extends StatefulWidget {
  final Function(Locale)? onLanguageChange;

  const CornYieldPageEnhanced({super.key, this.onLanguageChange});

  @override
  State<CornYieldPageEnhanced> createState() => _CornYieldPageEnhancedState();
}

class _CornYieldPageEnhancedState extends State<CornYieldPageEnhanced>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _resultKey = GlobalKey();
  late AnimationController _resultAnimationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  final _farmSizeController = TextEditingController(text: "");
  final _rainfallController = TextEditingController(text: "");
  final _fertilizerController = TextEditingController(text: "");
  final _prevYieldController = TextEditingController(text: "");

  final List<String> _districts = ["Anuradhapura"];

  final List<String> _varieties = ["Hybrid_A", "Hybrid_B", "OPV_Local"];

  final List<String> _soilTypes = ["Sandy", "Loam", "Clay"];

  final List<String> _irrigationTypes = [
    "Rainfed",
    "Tank",
    "Canal",
    "Tube well",
  ];

  final List<String> _pestDiseaseLevels = ["None", "Low", "Medium", "High"];

  String _district = "Anuradhapura";
  String? _variety;
  String? _soilType;
  String? _irrigationType;
  String? _pestDiseaseLevel;

  bool _loading = false;
  YieldResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resultAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _resultAnimationController,
        curve: Curves.easeInOut,
      ),
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(
            parent: _resultAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );
  }

  @override
  void dispose() {
    _resultAnimationController.dispose();
    _scrollController.dispose();
    _farmSizeController.dispose();
    _rainfallController.dispose();
    _fertilizerController.dispose();
    _prevYieldController.dispose();
    super.dispose();
  }

  InputDecoration _fieldDecoration(String label, String hint) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.green.shade100, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF4FB26C), width: 2.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.red.shade300, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 2.5),
      ),
    );
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    final payload = {
      "district": _district,
      "farm_size_acres": double.parse(_farmSizeController.text),
      "variety": _variety!,
      "soil_type": _soilType!,
      "irrigation_type": _irrigationType!,
      "seasonal_rainfall_mm": double.parse(_rainfallController.text),
      "fertilizer_kg_per_acre": double.parse(_fertilizerController.text),
      "previous_yield_kg_per_acre": _prevYieldController.text.trim().isEmpty
          ? 0.0
          : double.parse(_prevYieldController.text),
      "pest_disease_incidence": _pestDiseaseLevelToIndex(_pestDiseaseLevel!),
    };

    // Start timer to ensure minimum 1 second of loading
    final startTime = DateTime.now();

    try {
      final uri = Uri.parse("$apiBaseUrl/predict_yield");
      final res = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;

        // Calculate remaining time to reach 1 second
        final elapsed = DateTime.now().difference(startTime);
        final remaining = const Duration(seconds: 1) - elapsed;

        // Wait if less than 1 second has passed
        if (remaining.inMilliseconds > 0) {
          await Future.delayed(remaining);
        }

        setState(() {
          _result = YieldResult.fromJson(
            data,
            selectedCats: {
              "District": _district,
              "Soil type": _soilType ?? "",
              "Irrigation type": _irrigationType ?? "",
              "Variety": _variety ?? "",
            },
          );
        });

        // Trigger result animation
        _resultAnimationController.forward(from: 0.0);

        // Auto-scroll to result card after a short delay
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _resultKey.currentContext != null) {
            final RenderBox? renderBox =
                _resultKey.currentContext!.findRenderObject() as RenderBox?;
            if (renderBox != null) {
              _scrollController.animateTo(
                _scrollController.position.pixels +
                    renderBox.localToGlobal(Offset.zero).dy -
                    100,
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
              );
            }
          }
        });
      } else {
        // Wait for minimum duration even on error
        final elapsed = DateTime.now().difference(startTime);
        final remaining = const Duration(seconds: 1) - elapsed;
        if (remaining.inMilliseconds > 0) {
          await Future.delayed(remaining);
        }

        setState(() {
          _error = "Backend returned ${res.statusCode}.";
        });
      }
    } catch (e) {
      // Wait for minimum duration even on error
      final elapsed = DateTime.now().difference(startTime);
      final remaining = const Duration(seconds: 1) - elapsed;
      if (remaining.inMilliseconds > 0) {
        await Future.delayed(remaining);
      }

      setState(() {
        _error = "Unable to reach the API. ${e.toString()}";
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _reset() {
    _farmSizeController.text = "";
    _rainfallController.text = "";
    _fertilizerController.text = "";
    _prevYieldController.text = "";
    setState(() {
      _result = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF2E8D4E),
              const Color(0xFF4FB26C),
              Colors.lightGreen.shade200,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Spacer(),
                    _buildLanguageSelector(context),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 40),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(context, loc),
                      const SizedBox(height: 20),
                      _buildQuickInfoSection(context, loc),
                      const SizedBox(height: 20),
                      _buildFormCard(context, loc),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _ErrorCard(message: _error!),
                      ],
                      if (_result != null) ...[
                        const SizedBox(height: 16),
                        SlideTransition(
                          position: _slideAnimation,
                          child: FadeTransition(
                            opacity: _fadeAnimation,
                            child: _ResultCard(
                              key: _resultKey,
                              result: _result!,
                              loc: loc,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSelector(BuildContext context) {
    final currentLocale = Localizations.localeOf(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: PopupMenuButton<Locale>(
        icon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.language, color: Colors.white, size: 20),
            const SizedBox(width: 6),
            Text(
              currentLocale.languageCode == 'si'
                  ? '\u0DC3\u0DD2\u0D82'
                  : currentLocale.languageCode == 'ta'
                  ? '\u0BA4'
                  : 'EN',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 20),
          ],
        ),
        offset: const Offset(0, 45),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        onSelected: (Locale locale) {
          if (widget.onLanguageChange != null) {
            widget.onLanguageChange!(locale);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: const Locale('en', ''),
            child: Row(
              children: [
                Text('🇬🇧', style: TextStyle(fontSize: 20)),
                SizedBox(width: 12),
                Text('English', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          PopupMenuItem(
            value: const Locale('si', ''),
            child: Row(
              children: [
                Text('🇱🇰', style: TextStyle(fontSize: 20)),
                SizedBox(width: 12),
                Text(
                  '\u0DC3\u0DD2\u0D82\u0DC4\u0DBD',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          PopupMenuItem(
            value: const Locale('ta', ''),
            child: Row(
              children: [
                Text('🇱🇰', style: TextStyle(fontSize: 20)),
                SizedBox(width: 12),
                Text(
                  '\u0BA4\u0BAE\u0BBF\u0BB4\u0BCD',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations loc) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFFFFFFFF),
            const Color(0xFFF0FFF4),
            const Color(0xFFE8F5E9),
          ],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.2),
            blurRadius: 30,
            offset: const Offset(0, 12),
            spreadRadius: -5,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.8), width: 1.5),
      ),
      child: Stack(
        children: [
          // Decorative circles in background
          Positioned(
            top: -20,
            right: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.green.shade200.withOpacity(0.2),
                    Colors.green.shade100.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -30,
            left: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    Colors.lightGreen.shade100.withOpacity(0.3),
                    Colors.lightGreen.shade50.withOpacity(0.1),
                  ],
                ),
              ),
            ),
          ),

          // Main content
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                // Icon with advanced styling
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF2E8D4E),
                        const Color(0xFF4FB26C),
                        const Color(0xFF66BB6A),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.5),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                        spreadRadius: 2,
                      ),
                      BoxShadow(
                        color: Colors.green.shade800.withOpacity(0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Animated pulse effect (static for now)
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                      const Icon(
                        Icons.eco_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 20),

                // Title with subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.translate('corn_yield_title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF1A5D31),
                          letterSpacing: -0.5,
                          height: 1.2,
                        ),
                      ),
                      Text(
                        loc.translate('prediction_title'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF4FB26C),
                          letterSpacing: -0.3,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Icon(
                            Icons.analytics_outlined,
                            size: 14,
                            color: Colors.green.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            loc.translate('ai_powered_analysis'),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: Colors.green.shade700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfoSection(BuildContext context, AppLocalizations loc) {
    return Container(
      height: 120,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF2E8D4E),
            const Color(0xFF4FB26C),
            Colors.lightGreen.shade400,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Part 1: ML Model
            Expanded(
              child: _buildBannerCard(
                icon: Icons.psychology_rounded,
                title: 'ML Model',
                subtitle: 'SHAP',
                color: Colors.white.withOpacity(0.95),
              ),
            ),
            const SizedBox(width: 12),
            // Part 2: Fast Analysis
            Expanded(
              child: _buildBannerCard(
                icon: Icons.speed_rounded,
                title: 'Analysis',
                subtitle: 'Fast',
                color: Colors.white.withOpacity(0.95),
              ),
            ),
            const SizedBox(width: 12),
            // Part 3: High Precision
            Expanded(
              child: _buildBannerCard(
                icon: Icons.precision_manufacturing_rounded,
                title: 'Precision',
                subtitle: 'High',
                color: Colors.white.withOpacity(0.95),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBannerCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF2E8D4E).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: const Color(0xFF2E8D4E),
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF2E8D4E),
            ),
          ),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1F2D1F),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(BuildContext context, AppLocalizations loc) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade500, Colors.teal.shade700],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.dashboard_customize,
                    color: Colors.white,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    loc.fieldSnapshot,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _buildInputGrid(context, loc),
            const SizedBox(height: 20),
            _buildActionButtons(context, loc),
          ],
        ),
      ),
    );
  }

  Widget _buildInputGrid(BuildContext context, AppLocalizations loc) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel(loc.district, Icons.location_on, Colors.red),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.green.shade100,
                        width: 2,
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            loc.translate(_district),
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF344034),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel(loc.variety, Icons.spa, Colors.green),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _variety,
                    decoration: _fieldDecoration("", loc.select),
                    items: _varieties
                        .map(
                          (v) => DropdownMenuItem(
                            value: v,
                            child: Text(loc.translate(v)),
                          ),
                        )
                        .toList(),
                    validator: (v) => v == null ? loc.required : null,
                    onChanged: (v) => setState(() => _variety = v),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel(
                    loc.translate('Soil type'),
                    Icons.landscape,
                    Colors.brown,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _soilType,
                    decoration: _fieldDecoration("", loc.select),
                    items: _soilTypes
                        .map(
                          (s) => DropdownMenuItem(
                            value: s,
                            child: Text(loc.translate(s)),
                          ),
                        )
                        .toList(),
                    validator: (v) => v == null ? loc.required : null,
                    onChanged: (v) => setState(() => _soilType = v),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel(
                    loc.translate('Irrigation type'),
                    Icons.water,
                    Colors.blue,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _irrigationType,
                    decoration: _fieldDecoration("", loc.select),
                    items: _irrigationTypes
                        .map(
                          (i) => DropdownMenuItem(
                            value: i,
                            child: Text(loc.translate(i)),
                          ),
                        )
                        .toList(),
                    validator: (v) => v == null ? loc.required : null,
                    onChanged: (v) => setState(() => _irrigationType = v),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel(
                    loc.translate('Pest/disease level'),
                    Icons.bug_report,
                    Colors.red,
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _pestDiseaseLevel,
                    decoration: _fieldDecoration("", loc.select),
                    items: _pestDiseaseLevels
                        .map(
                          (p) => DropdownMenuItem(
                            value: p,
                            child: Text(loc.translate(p)),
                          ),
                        )
                        .toList(),
                    validator: (v) => v == null ? loc.required : null,
                    onChanged: (v) => setState(() => _pestDiseaseLevel = v),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: SizedBox()),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel(loc.farmSize, Icons.landscape, Colors.brown),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _farmSizeController,
                    decoration: _fieldDecoration(loc.acres, "0"),
                    keyboardType: TextInputType.number,
                    validator: (v) => _farmSizeValidator(v, loc),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel(loc.rainfall, Icons.water_drop, Colors.blue),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _rainfallController,
                    decoration: _fieldDecoration(loc.mm, "0"),
                    keyboardType: TextInputType.number,
                    validator: (v) => _numberValidator(v, loc),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel(loc.fertilizer, Icons.eco, Colors.orange),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _fertilizerController,
                    decoration: _fieldDecoration(loc.kgPerAcre, "0"),
                    keyboardType: TextInputType.number,
                    validator: (v) => _numberValidator(v, loc),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFieldLabel(
                    loc.prevYield,
                    Icons.trending_up,
                    Colors.purple,
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _prevYieldController,
                    decoration: _fieldDecoration(loc.kgPerAcre, "0"),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFieldLabel(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(
          text,
          style: GoogleFonts.poppins(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF344034),
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons(BuildContext context, AppLocalizations loc) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: _loading
                    ? [Colors.grey.shade400, Colors.grey.shade500]
                    : [Colors.green.shade500, Colors.green.shade700],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: _loading
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: FilledButton.icon(
              onPressed: _loading ? null : _submit,
              icon: _loading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Colors.white.withOpacity(0.9),
                        ),
                      ),
                    )
                  : const Icon(Icons.analytics_rounded, size: 22),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  _loading ? loc.predicting : loc.predictYield,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: loc.locale.languageCode == 'en' ? 13 : 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange.shade400, Colors.orange.shade600],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FilledButton.icon(
              onPressed: _reset,
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  loc.reset,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: loc.locale.languageCode == 'en' ? 12 : 10,
                  ),
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String? _numberValidator(String? value, AppLocalizations loc) {
    if (value == null || value.trim().isEmpty) return loc.required;
    return null;
  }

  String? _farmSizeValidator(String? value, AppLocalizations loc) {
    return _numberValidator(value, loc);
  }

  int _pestDiseaseLevelToIndex(String level) {
    switch (level) {
      case "None":
        return 0;
      case "Low":
        return 1;
      case "Medium":
        return 2;
      case "High":
        return 3;
      default:
        return 1;
    }
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({super.key, required this.result, required this.loc});

  final YieldResult result;
  final AppLocalizations loc;

  Color _pillColor(double shap) {
    if (shap > 0) return Colors.green.shade50;
    if (shap < 0) return Colors.red.shade50;
    return Colors.grey.shade50;
  }

  Color _pillTextColor(double shap) {
    if (shap > 0) return Colors.green.shade700;
    if (shap < 0) return Colors.red.shade700;
    return Colors.grey.shade700;
  }

  String _effectText(double shap) {
    if (shap > 0) return loc.increasesYield;
    if (shap < 0) return loc.reducesYield;
    return loc.noChange;
  }

  @override
  Widget build(BuildContext context) {
    final maxAbs = result.topFeatures
        .map((f) => f.shapValue.abs())
        .fold<double>(0, max);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.green.shade50],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.green.shade200, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade500, Colors.teal.shade700],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.teal.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(Icons.eco, color: Colors.white, size: 24),
                const SizedBox(width: 12),
                Text(
                  loc.result,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: loc.locale.languageCode == 'en' ? 18 : 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.lightGreen.shade400,
                  Colors.lightGreen.shade500,
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.lightGreen.withOpacity(0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.shopping_basket,
                  color: Colors.white,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.predictedYield,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: loc.locale.languageCode == 'en' ? 14 : 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      Text(
                        "${result.predictedYield.toStringAsFixed(0)} ${loc.kgPerAcre}",
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(
                          fontSize: loc.locale.languageCode == 'en' ? 28 : 22,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            loc.mainContributingFactors,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(
              fontSize: loc.locale.languageCode == 'en' ? 16 : 14,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF344034),
            ),
          ),
          const SizedBox(height: 16),
          ...result.topFeatures.asMap().entries.map((entry) {
            final index = entry.key;
            final f = entry.value;

            // Calculate percentage for this feature
            final totalAbsShap = result.topFeatures
                .map((feature) => feature.shapValue.abs())
                .fold<double>(0, (sum, val) => sum + val);
            final percentage = totalAbsShap > 0
                ? ((f.shapValue.abs() / totalAbsShap) * 100).toStringAsFixed(1)
                : "0.0";

            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.translate(f.displayName),
                                maxLines: 1,
                                overflow: TextOverflow.visible,
                                softWrap: false,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: const Color(0xFF1F2D1F),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                "Impact: $percentage%",
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _pillColor(f.shapValue),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _pillTextColor(
                                f.shapValue,
                              ).withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            _effectText(f.shapValue),
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _pillTextColor(f.shapValue),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ContributionBar(
                      value: f.shapValue,
                      percentage: percentage,
                      index: index,
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}

class _ContributionBar extends StatefulWidget {
  const _ContributionBar({
    required this.value,
    required this.percentage,
    required this.index,
  });

  final double value;
  final String percentage;
  final int index;

  @override
  State<_ContributionBar> createState() => _ContributionBarState();
}

class _ContributionBarState extends State<_ContributionBar>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _widthAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
      value: 0.0,
    );
    _widthAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
    // Start animation after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAnimation();
    });
  }

  void _startAnimation() {
    if (!mounted) return;
    _animationController.reset();
    // Start animation with staggered delay based on index
    Future.delayed(Duration(milliseconds: 100 + (widget.index * 200)), () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void didUpdateWidget(_ContributionBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.percentage != widget.percentage) {
      _startAnimation();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percentValue = double.tryParse(widget.percentage) ?? 0.0;
    final ratio = percentValue / 100.0;
    final isPositive = widget.value >= 0;

    return AnimatedBuilder(
      animation: _widthAnimation,
      builder: (context, child) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth * ratio * _widthAnimation.value;
            return Stack(
              children: [
                Container(
                  height: 14,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                if (width > 0.5)
                  Positioned(
                    left: isPositive
                        ? constraints.maxWidth / 2
                        : (constraints.maxWidth / 2 - width),
                    child: Container(
                      height: 14,
                      width: width,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: isPositive
                              ? [Colors.green.shade400, Colors.green.shade600]
                              : [Colors.red.shade400, Colors.red.shade600],
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: (isPositive ? Colors.green : Colors.red)
                                .withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                Positioned(
                  left: constraints.maxWidth / 2,
                  child: Container(
                    height: 14,
                    width: 2,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class _AnimatedImpactValue extends StatefulWidget {
  const _AnimatedImpactValue({required this.shapValue, required this.index});

  final double shapValue;
  final int index;

  @override
  State<_AnimatedImpactValue> createState() => _AnimatedImpactValueState();
}

class _AnimatedImpactValueState extends State<_AnimatedImpactValue>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _valueAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
      value: 0.0,
    );
    _updateAnimation();
    // Start animation after the first frame is rendered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startAnimation();
    });
  }

  void _updateAnimation() {
    _valueAnimation = Tween<double>(begin: 0.0, end: widget.shapValue).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutCubic),
    );
  }

  void _startAnimation() {
    if (!mounted) return;
    _animationController.reset();
    // Start animation with staggered delay based on index
    Future.delayed(Duration(milliseconds: 100 + (widget.index * 200)), () {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void didUpdateWidget(_AnimatedImpactValue oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shapValue != widget.shapValue) {
      _updateAnimation();
      _startAnimation();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _valueAnimation,
      builder: (context, child) {
        return Text(
          'Impact: ${_valueAnimation.value >= 0 ? '+' : ''}${_valueAnimation.value.toStringAsFixed(2)}',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
          ),
        );
      },
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade50, Colors.red.shade100],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.red.shade300, width: 2),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.poppins(
                color: Colors.red.shade900,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class YieldResult {
  YieldResult({required this.predictedYield, required this.topFeatures});

  final double predictedYield;
  final List<FeatureContribution> topFeatures;

  factory YieldResult.fromJson(
    Map<String, dynamic> json, {
    required Map<String, String> selectedCats,
  }) {
    final featuresJson =
        json["top_contributing_features"] as List<dynamic>? ?? [];
    final rawFeatures = featuresJson
        .map((e) => FeatureContribution.fromJson(e as Map<String, dynamic>))
        .toList();

    // Group categorical features (one-hot encoded)
    final grouped = _groupCategoricalFeatures(rawFeatures, selectedCats);

    return YieldResult(
      predictedYield: (json["predicted_yield_kg_per_acre"] as num).toDouble(),
      topFeatures: grouped,
    );
  }

  static List<FeatureContribution> _groupCategoricalFeatures(
    List<FeatureContribution> features,
    Map<String, String> selectedCats,
  ) {
    final Map<String, List<FeatureContribution>> categoricalGroups = {};
    final List<FeatureContribution> numericFeatures = [];

    // Categorical prefixes to group
    final categoricalPrefixes = [
      'District:',
      'Soil type:',
      'Agro-ecological zone:',
      'Irrigation type:',
      'Variety:',
    ];

    for (final feature in features) {
      bool isCategorical = false;

      for (final prefix in categoricalPrefixes) {
        if (feature.displayName.startsWith(prefix)) {
          // Extract base name (e.g., "Soil type")
          final baseName = prefix.replaceAll(':', '');

          if (!categoricalGroups.containsKey(baseName)) {
            categoricalGroups[baseName] = [];
          }
          categoricalGroups[baseName]!.add(feature);
          isCategorical = true;
          break;
        }
      }

      if (!isCategorical) {
        numericFeatures.add(feature);
      }
    }

    // Process grouped categorical features
    final List<FeatureContribution> result = [];

    for (final entry in categoricalGroups.entries) {
      final baseName = entry.key;
      final group = entry.value;

      if (group.isEmpty) continue;

      final selectedValue = selectedCats[baseName];

      // Total impact for the whole categorical feature
      final totalShap = group.fold<double>(0, (sum, f) => sum + f.shapValue);

      // ALWAYS show the user's selected value in the UI
      final labelValue = (selectedValue != null && selectedValue.isNotEmpty)
          ? selectedValue
          : group.first.displayName.split(': ').last; // fallback

      result.add(
        FeatureContribution(
          displayName: '$baseName: $labelValue',
          shapValue: totalShap,
        ),
      );
    }

    // Combine and sort by absolute SHAP value
    result.addAll(numericFeatures);
    result.sort((a, b) => b.shapValue.abs().compareTo(a.shapValue.abs()));

    return result;
  }
}

class FeatureContribution {
  FeatureContribution({required this.displayName, required this.shapValue});

  final String displayName;
  final double shapValue;

  factory FeatureContribution.fromJson(Map<String, dynamic> json) {
    return FeatureContribution(
      displayName: json["display_name"] as String,
      shapValue: (json["shap_value"] as num).toDouble(),
    );
  }
}
