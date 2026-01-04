import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../../../core/localization/app_localizations.dart';

const String apiBaseUrl = "http://10.0.2.2:8000"; // 10.0.2.2 for Android emulator, 127.0.0.1 for web/desktop

class CornYieldPageEnhanced extends StatefulWidget {
  final Function(Locale)? onLanguageChange;
  
  const CornYieldPageEnhanced({super.key, this.onLanguageChange});

  @override
  State<CornYieldPageEnhanced> createState() => _CornYieldPageEnhancedState();
}

class _CornYieldPageEnhancedState extends State<CornYieldPageEnhanced> {
  final _formKey = GlobalKey<FormState>();
  final _scrollController = ScrollController();
  final _resultKey = GlobalKey();

  final _farmSizeController = TextEditingController(text: "0");
  final _rainfallController = TextEditingController(text: "0");
  final _fertilizerController = TextEditingController(text: "0");
  final _prevYieldController = TextEditingController(text: "0");

  final List<String> _districts = [
    "Monaragala",
    "Badulla",
    "Anuradhapura",
    "Kurunegala",
    "Gampaha",
    "Polonnaruwa",
    "Hambantota",
    "Matale",
  ];

  final List<String> _varieties = [
    "Hybrid_A",
    "Hybrid_B",
    "OPV_Local",
  ];

  String _district = "Monaragala";
  String _variety = "Hybrid_A";

  bool _loading = false;
  YieldResult? _result;
  String? _error;

  @override
  void dispose() {
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
      "variety": _variety,
      "seasonal_rainfall_mm": double.parse(_rainfallController.text),
      "fertilizer_kg_per_acre": double.parse(_fertilizerController.text),
      "previous_yield_kg_per_acre": double.parse(_prevYieldController.text),
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
          _result = YieldResult.fromJson(data);
        });
        
        // Auto-scroll to result card after a short delay
        Future.delayed(const Duration(milliseconds: 300), () {
          if (mounted && _resultKey.currentContext != null) {
            Scrollable.ensureVisible(
              _resultKey.currentContext!,
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              alignment: 0.1, // Position result card near top of visible area
            );
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
    _farmSizeController.text = "0";
    _rainfallController.text = "0";
    _fertilizerController.text = "0";
    _prevYieldController.text = "0";
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
                      _buildIllustrationCard(context, loc),
                      const SizedBox(height: 20),
                      _buildFormCard(context, loc),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        _ErrorCard(message: _error!),
                      ],
                      if (_result != null) ...[
                        const SizedBox(height: 16),
                        _ResultCard(key: _resultKey, result: _result!, loc: loc),
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
              currentLocale.languageCode == 'si' ? '\u0DC3\u0DD2\u0D82' : 
              currentLocale.languageCode == 'ta' ? '\u0BA4' : 'EN',
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
                Text('\u0DC3\u0DD2\u0D82\u0DC4\u0DBD', style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          PopupMenuItem(
            value: const Locale('ta', ''),
            child: Row(
              children: [
                Text('🇱🇰', style: TextStyle(fontSize: 20)),
                SizedBox(width: 12),
                Text('\u0BA4\u0BAE\u0BBF\u0BB4\u0BCD', style: TextStyle(fontWeight: FontWeight.w600)),
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
        border: Border.all(
          color: Colors.white.withOpacity(0.8),
          width: 1.5,
        ),
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

  Widget _buildIllustrationCard(BuildContext context, AppLocalizations loc) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.amber.shade400,
            Colors.orange.shade300,
            Colors.deepOrange.shade200,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.4),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            bottom: -20,
            left: -20,
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.agriculture, color: Colors.orange.shade700, size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🌽 ${loc.translate('smart_farming')}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            loc.translate('ai_powered_yield_predictions'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.poppins(
                              color: Colors.white.withOpacity(0.95),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '✓ ${loc.translate('accurate_predictions')}  ✓ ${loc.translate('data_driven_insights')}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
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
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.blue.shade400, Colors.blue.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.dashboard_customize, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  loc.fieldSnapshot,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1F2D1F),
                  ),
                ),
              ],
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
                  DropdownButtonFormField<String>(
                    value: _district,
                    decoration: _fieldDecoration("", loc.select),
                    items: _districts.map((d) => DropdownMenuItem(value: d, child: Text(loc.translate(d)))).toList(),
                    onChanged: (v) => setState(() => _district = v!),
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
                    items: _varieties.map((v) => DropdownMenuItem(value: v, child: Text(loc.translate(v)))).toList(),
                    onChanged: (v) => setState(() => _variety = v!),
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
                  _buildFieldLabel(loc.farmSize, Icons.landscape, Colors.brown),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _farmSizeController,
                    decoration: _fieldDecoration(loc.acres, "0"),
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
                  _buildFieldLabel(loc.prevYield, Icons.trending_up, Colors.purple),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _prevYieldController,
                    decoration: _fieldDecoration(loc.kgPerAcre, "0"),
                    keyboardType: TextInputType.number,
                    validator: (v) => _numberValidator(v, loc),
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
              boxShadow: _loading ? [] : [
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
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white.withOpacity(0.9)),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
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
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange.shade700,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              side: BorderSide(color: Colors.orange.shade300, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  String? _numberValidator(String? value, AppLocalizations loc) {
    if (value == null || value.trim().isEmpty) return loc.required;
    final v = double.tryParse(value);
    if (v == null) return loc.enterNumber;
    if (v < 0) return loc.cannotNegative;
    return null;
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
    final maxAbs = result.topFeatures.map((f) => f.shapValue.abs()).fold<double>(0, max);

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.green.shade400, Colors.green.shade600],
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.eco, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Text(
                loc.result,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1F2D1F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.green.shade600, Colors.green.shade700],
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
            child: Row(
              children: [
                const Icon(Icons.shopping_basket, color: Colors.white, size: 32),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        loc.predictedYield,
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      Text(
                        "${result.predictedYield.toStringAsFixed(0)} ${loc.kgPerAcre}",
                        style: GoogleFonts.poppins(
                          fontSize: 28,
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
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF344034),
            ),
          ),
          const SizedBox(height: 16),
          ...result.topFeatures.map((f) {
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Impact: ${f.shapValue >= 0 ? '+' : ''}${f.shapValue.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _pillColor(f.shapValue),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _pillTextColor(f.shapValue).withOpacity(0.3),
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
                    _ContributionBar(value: f.shapValue, maxAbs: maxAbs),
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

class _ContributionBar extends StatelessWidget {
  const _ContributionBar({required this.value, required this.maxAbs});

  final double value;
  final double maxAbs;

  @override
  Widget build(BuildContext context) {
    final double ratio = maxAbs == 0 ? 0 : value.abs() / maxAbs;
    final isPositive = value >= 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth * ratio;
        return Stack(
          children: [
            Container(
              height: 14,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            Positioned(
              left: isPositive ? constraints.maxWidth / 2 : (constraints.maxWidth / 2 - width),
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
                      color: (isPositive ? Colors.green : Colors.red).withOpacity(0.4),
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
            child: const Icon(Icons.error_outline, color: Colors.white, size: 24),
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

  factory YieldResult.fromJson(Map<String, dynamic> json) {
    final featuresJson = json["top_contributing_features"] as List<dynamic>? ?? [];
    return YieldResult(
      predictedYield: (json["predicted_yield_kg_per_acre"] as num).toDouble(),
      topFeatures: featuresJson
          .map((e) => FeatureContribution.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
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
