import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import '../../../../core/localization/app_localizations.dart';

const String apiBaseUrl =
    "http://10.0.2.2:8000"; // 10.0.2.2 for Android emulator, 127.0.0.1 for web/desktop

class CornYieldPage extends StatefulWidget {
  const CornYieldPage({super.key});

  @override
  State<CornYieldPage> createState() => _CornYieldPageState();
}

class _CornYieldPageState extends State<CornYieldPage> {
  final _formKey = GlobalKey<FormState>();

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
  void dispose() {
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
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFFE0E6DD),
          style: BorderStyle.solid,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(
          color: Color(0xFF4FB26C),
          width: 1.4,
          style: BorderStyle.solid,
        ),
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

    try {
      final uri = Uri.parse("$apiBaseUrl/predict_yield");
      final res = await http.post(
        uri,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(payload),
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
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
      } else {
        setState(() {
          _error = "Backend returned ${res.statusCode}.";
        });
      }
    } catch (e) {
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
    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: 200,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF3FB15E), Color(0xFF2D8B4E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 36),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 12),
                  _buildFormCard(context),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorCard(message: _error!),
                  ],
                  if (_result != null) ...[
                    const SizedBox(height: 12),
                    _ResultCard(result: _result!),
                  ],
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F7EC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.grass_rounded,
              color: Color(0xFF2E8D4E),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Corn Yield Prediction",
                  style: GoogleFonts.manrope(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1F2D1F),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  "Guided by Plantix-style crop health cues",
                  style: GoogleFonts.manrope(
                    fontSize: 13,
                    color: const Color(0xFF5D6D5D),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1F7B41),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              "LIVE",
              style: GoogleFonts.manrope(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 8),
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
                Text(
                  "Field snapshot",
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF1F2D1F),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F7EC),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    "6 inputs",
                    style: GoogleFonts.manrope(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF2E8D4E),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 68) / 2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFE0E6DD),
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Text(
                      _district,
                      style: GoogleFonts.manrope(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF344034),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 68) / 2,
                  child: DropdownButtonFormField<String>(
                    value: _variety,
                    decoration: _fieldDecoration("Variety", "Select"),
                    items: _varieties
                        .map((v) => DropdownMenuItem(value: v, child: Text(v)))
                        .toList(),
                    validator: (v) => v == null ? "Required" : null,
                    onChanged: (v) => setState(() => _variety = v),
                  ),
                ),
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 68) / 2,
                  child: TextFormField(
                    controller: _farmSizeController,
                    decoration: _fieldDecoration("Farm Size", "acres"),
                    keyboardType: TextInputType.number,
                    validator: _numberValidator,
                  ),
                ),
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 68) / 2,
                  child: TextFormField(
                    controller: _rainfallController,
                    decoration: _fieldDecoration("Rainfall", "mm"),
                    keyboardType: TextInputType.number,
                    validator: _numberValidator,
                  ),
                ),
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 68) / 2,
                  child: TextFormField(
                    controller: _fertilizerController,
                    decoration: _fieldDecoration("Fertilizer", "kg/acre"),
                    keyboardType: TextInputType.number,
                    validator: _numberValidator,
                  ),
                ),
                SizedBox(
                  width: (MediaQuery.of(context).size.width - 68) / 2,
                  child: TextFormField(
                    controller: _prevYieldController,
                    decoration: _fieldDecoration("Prev Yield", "kg/acre"),
                    keyboardType: TextInputType.number,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _loading ? null : _submit,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.auto_graph_rounded),
                    label: Text(
                      _loading ? "Predicting..." : "Predict yield",
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w800),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF2E8D4E),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _reset,
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(
                      "Reset",
                      style: GoogleFonts.manrope(fontWeight: FontWeight.w700),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF2E8D4E),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      side: const BorderSide(
                        color: Color(0xFFE0E6DD),
                        style: BorderStyle.solid,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String? _numberValidator(String? value) {
    if (value == null || value.trim().isEmpty) return "Required";
    return null;
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
  const _ResultCard({required this.result});

  final YieldResult result;

  Color _pillColor(double shap) {
    if (shap > 0) return const Color(0xFFE6F7EC);
    if (shap < 0) return const Color(0xFFFFEAE8);
    return const Color(0xFFF1F3F1);
  }

  Color _pillTextColor(double shap) {
    if (shap > 0) return const Color(0xFF1E7A43);
    if (shap < 0) return const Color(0xFFB02A1C);
    return const Color(0xFF3A3F3A);
  }

  String _effectText(double shap) {
    if (shap > 0) return "increases yield";
    if (shap < 0) return "reduces yield";
    return "no change";
  }

  @override
  Widget build(BuildContext context) {
    final maxAbs = result.topFeatures
        .map((f) => f.shapValue.abs())
        .fold<double>(0, max);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 14,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_florist_rounded, color: Color(0xFF2E8D4E)),
              const SizedBox(width: 8),
              Text(
                "Result",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF1F2D1F),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            "Predicted yield: ${result.predictedYield.toStringAsFixed(0)} kg/acre",
            style: GoogleFonts.manrope(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: const Color(0xFF1F2D1F),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Main contributing factors",
            style: GoogleFonts.manrope(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF344034),
            ),
          ),
          const SizedBox(height: 12),
          ...result.topFeatures.map((f) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppLocalizations.of(context).translate(f.displayName),
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1F2D1F),
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _pillColor(f.shapValue),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          _effectText(f.shapValue),
                          style: GoogleFonts.manrope(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _pillTextColor(f.shapValue),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _ContributionBar(value: f.shapValue, maxAbs: maxAbs),
                ],
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
              height: 12,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F3F1),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            Positioned(
              left: isPositive
                  ? constraints.maxWidth / 2
                  : (constraints.maxWidth / 2 - width),
              child: Container(
                height: 12,
                width: width,
                decoration: BoxDecoration(
                  color: isPositive
                      ? const Color(0xFF4FB26C)
                      : const Color(0xFFE85D4F),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Positioned(
              left: constraints.maxWidth / 2,
              child: Container(
                height: 12,
                width: 1,
                color: const Color(0xFFCBD3C8),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF2F0),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: const Color(0xFFE8C6C3),
          style: BorderStyle.solid,
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFB02A1C)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.manrope(
                color: const Color(0xFF7A2C2C),
                fontWeight: FontWeight.w700,
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

    final grouped = _groupCategoricalFeatures(rawFeatures, selectedCats);

    return YieldResult(
      predictedYield: (json["predicted_yield_kg_per_acre"] as num).toDouble(),
      topFeatures: grouped,
    );
  }

  static String _norm(String s) =>
      s.toLowerCase().replaceAll('_', '').replaceAll(' ', '');

  static List<FeatureContribution> _groupCategoricalFeatures(
    List<FeatureContribution> features,
    Map<String, String> selectedCats,
  ) {
    final Map<String, List<FeatureContribution>> groups = {};
    final List<FeatureContribution> numeric = [];

    final prefixes = [
      'District:',
      'Soil type:',
      'Agro-ecological zone:',
      'Irrigation type:',
      'Variety:',
    ];

    for (final f in features) {
      bool grouped = false;
      for (final p in prefixes) {
        if (f.displayName.startsWith(p)) {
          final base = p.replaceAll(':', '');
          (groups[base] ??= []).add(f);
          grouped = true;
          break;
        }
      }
      if (!grouped) numeric.add(f);
    }

    final List<FeatureContribution> result = [];

    for (final entry in groups.entries) {
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

    result.addAll(numeric);
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
