// lib/features/diagnosis/presentation/pages/nutrient_prediction_page.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/api/api_client.dart';

class NutrientPredictionPage extends StatefulWidget {
  final String? initialImagePath;
  const NutrientPredictionPage({super.key, this.initialImagePath});

  @override
  State<NutrientPredictionPage> createState() => _NutrientPredictionPageState();
}

class _NutrientPredictionPageState extends State<NutrientPredictionPage>
    with SingleTickerProviderStateMixin {
  final ImagePicker _picker = ImagePicker();
  final ApiClient _apiClient = ApiClient();

  File? _selectedImage;
  bool _isLoading = false;
  String? _predictedClass;
  double? _confidence;
  String? _errorMsg;
  List<double>? _probabilities;
  Map<String, dynamic>? _fertilizerRecommendations;
  List<Map<String, dynamic>>? _top3;
  Map<String, double>? _allProbabilities;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    if (widget.initialImagePath != null) {
      _selectedImage = File(widget.initialImagePath!);
      // auto-run analysis when arriving from capture screen
      _analyzeImage();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String className) {
    return className == 'Healthy' ? Colors.green : Colors.orange;
  }

  String _getActionRequired(String className) {
    switch (className) {
      case 'Healthy':
        return 'සෞඛ්‍ය සම්පන්නයි! පුහුණු කිරීම දිගටම කරගෙන යන්න.\n\nHealthy! Continue regular care.';
      case 'NAB':
        return 'නයිට්‍රජන් පොහොර යොදන්න.\n\nApply Nitrogen Fertilizer.';
      case 'PAB':
        return 'පොස්පේට් පොහොර යොදන්න.\n\nApply Phosphate Fertilizer.';
      case 'KAB':
        return 'පොටෑසියම් පොහොර යොදන්න.\n\nApply Potassium Fertilizer.';
      case 'ZNAB':
        return 'සිංක් පොහොර යොදන්න.\n\nApply Zinc Fertilizer (ZnSO₄).';
      default:
        return 'කරුණාකර කෘෂිකාර්මික විශේෂඥයෙකු හමු වන්න.\n\nPlease consult an agricultural expert.';
    }
  }

  String _getExplanation(String className) {
    switch (className) {
      case 'Healthy':
        return 'මෙම බෝගය සෞඛ්‍ය සම්පන්නයි. සියලුම පෝෂක මට්ටම් ප්‍රශස්තයි.\n\nThis crop is healthy. All nutrient levels are optimal.';
      case 'NAB':
        return 'නයිට්‍රජන් (N) ඌනතාවය හඳුනාගෙන ඇත. නිර්දේශිත නයිට්‍රජන් පොහොර මාත්‍රාව යොදන්න.\n\nNitrogen deficiency detected. Apply recommended nitrogen fertilizer dose.';
      case 'PAB':
        return 'පොස්පරස් (P) ඌනතාවය හඳුනාගෙන ඇත. මාර්ගෝපදේශ අනුව පොස්පේට් පොහොර යොදන්න.\n\nPhosphorus deficiency detected. Apply phosphate fertilizer as per guidelines.';
      case 'KAB':
        return 'පොටෑසියම් (K) ඌනතාවය හඳුනාගෙන ඇත. MOP හෝ සුදුසු K ප්‍රභවයක් යොදන්න.\n\nPotassium deficiency detected. Apply MOP or suitable K source.';
      case 'ZNAB':
        return 'සිංක් (Zn) ඌනතාවය හඳුනාගෙන ඇත. ZnSO₄ හෝ chelated Zn යොදන්න.\n\nZinc deficiency detected. Apply ZnSO₄ or chelated zinc fertilizer.';
      default:
        return 'හඳු නා නොගත් ඌනතාවයකි. කෘෂිකාර්මික විශේෂඥයෙකුගෙන් උපදෙස් ලබා ගන්න.\n\nUnknown deficiency. Please consult an agricultural expert.';
    }
  }

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;

    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final data = await _apiClient.uploadImageForPrediction(_selectedImage!);
      setState(() {
        _predictedClass = data['predicted_class'] as String?;
        final conf = data['confidence'];
        if (conf is num) {
          _confidence = conf.toDouble();
        }
        final probs = data['probabilities'];
        if (probs is List) {
          _probabilities = probs.map((e) => (e as num).toDouble()).toList();
        }
        // Store fertilizer recommendations from API response
        final recs = data['fertilizer_recommendations'];
        if (recs is Map<String, dynamic>) {
          _fertilizerRecommendations = recs;
        }
        // Parse top_3 multi-condition results
        final top3Raw = data['top_3'];
        if (top3Raw is List) {
          _top3 = top3Raw
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
        // Parse all_probabilities for nutrient distribution panel
        final allProbs = data['all_probabilities'];
        if (allProbs is Map) {
          _allProbabilities = Map<String, double>.fromEntries(
            allProbs.entries.map(
              (e) => MapEntry(e.key as String, (e.value as num).toDouble()),
            ),
          );
        }
      });

      // If the model detected a non-corn image, show bilingual alert and go back
      if (mounted && _predictedClass == 'Not_Corn') {
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('Not a Corn Plant'),
            content: const Text(
              'මෙම රූපය බඩ  ඉරිඟු  පත්‍රයක්  නොවේ. කරුණාකර බඩ ඉරිඟු  පත්‍රයක්  අප්ලෝඩ් කරන්න\n\nThis image does not appear to be a corn plant. Please upload a corn leaf image.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  Navigator.of(context).pop();
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
        return;
      }

      if (mounted && _predictedClass != null) {
        _showResultSheet(_predictedClass!, _confidence ?? 0);
      }
      _animationController.forward(from: 0.0);
    } catch (e) {
      setState(() {
        _errorMsg = e.toString();
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showResultSheet(String className, double confidence) {
    final advice = _getActionRequired(className);
    final explanation = _getExplanation(className);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1224),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: className == 'Healthy'
                                ? const Color(0xFF00D9A0).withOpacity(0.15)
                                : Colors.orange.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            className,
                            style: TextStyle(
                              color: className == 'Healthy'
                                  ? const Color(0xFF00D9A0)
                                  : Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${(confidence * 100).toStringAsFixed(1)}% sure',
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      explanation,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1D1F33),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF00D9A0).withOpacity(0.25),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.science, color: Color(0xFF00D9A0)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              advice,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Fertilizer recommendations section
                    if (_fertilizerRecommendations != null &&
                        className != 'Healthy')
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Detailed Fertilizer Recommendations:',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1D1F33),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.blue.withOpacity(0.25),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _fertilizerRecommendations!['deficiency'] ??
                                      'Nutrient Deficiency',
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _fertilizerRecommendations!['timing'] ??
                                      'Follow recommended timing',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              _showFertilizerDetailsModal(ctx);
                            },
                            icon: const Icon(Icons.info_outline),
                            label: const Text('View All Options'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 45),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(
                          Icons.check_circle_outline,
                          color: Color(0xFF00D9A0),
                        ),
                        label: const Text(
                          'Got it',
                          style: TextStyle(
                            color: Color(0xFF00D9A0),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showFertilizerDetailsModal(BuildContext context) {
    if (_fertilizerRecommendations == null) return;

    final options = _fertilizerRecommendations!['fertilizer_options'] as List?;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F1224),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.8,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Fertilizer Options',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: const Icon(Icons.close, color: Colors.white70),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: options?.length ?? 0,
                      itemBuilder: (context, index) {
                        final option = options![index] as Map<String, dynamic>;
                        return _buildFertilizerCard(option, index);
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFertilizerCard(Map<String, dynamic> option, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1F33),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF00D9A0).withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9A0).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: const TextStyle(
                      color: Color(0xFF00D9A0),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option['name'] ?? 'Unknown',
                      style: GoogleFonts.notoSansSinhala(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      option['concentration'] ?? '',
                      style: GoogleFonts.notoSansSinhala(
                        color: const Color(0xFF00D9A0),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1224),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFertilizerDetail('Application', option['application']),
                const SizedBox(height: 12),
                _buildFertilizerDetail('Dosage (English)', option['dosage_en']),
                const SizedBox(height: 12),
                _buildFertilizerDetail('Dosage (Sinhala)', option['dosage_si']),
                if (option['notes'] != null) ...[
                  const SizedBox(height: 12),
                  _buildFertilizerDetail('Notes', option['notes']),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFertilizerDetail(String label, String? value) {
    final isSinhala = label.contains('Sinhala');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value ?? 'N/A',
          softWrap: true,
          textAlign: TextAlign.left,
          style: GoogleFonts.notoSansSinhala(
            color: Colors.white,
            fontSize: isSinhala ? 14 : 13,
            height: 1.5,
            letterSpacing: isSinhala ? 0.3 : 0,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasResult = _predictedClass != null && !_isLoading;
    return Scaffold(
      backgroundColor: const Color(0xFF060912),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Analysis Results',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              if (_isLoading)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        CircularProgressIndicator(color: Color(0xFF00D9A0)),
                        SizedBox(height: 12),
                        Text(
                          'Analyzing leaf...',
                          style: TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                )
              else if (hasResult)
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        _buildNutrientGauges(),
                        const SizedBox(height: 18),
                        _buildConfidenceBanner(),
                        const SizedBox(height: 18),
                        if (_allProbabilities != null)
                          _buildNutrientProbabilityDistribution(),
                        if (_allProbabilities != null)
                          const SizedBox(height: 18),
                        _buildConfidenceChart(),
                        const SizedBox(height: 18),
                        if (_top3 != null && _top3!.length >= 3)
                          _buildMultiConditionSection(),
                        if (_top3 != null && _top3!.length >= 3)
                          const SizedBox(height: 18),
                        _buildActionRequired(),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.info_outline, color: Colors.white54),
                        SizedBox(height: 8),
                        Text(
                          'No image to analyze. Go back and scan a leaf.',
                          style: TextStyle(color: Colors.white70),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              if (_errorMsg != null)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    _errorMsg!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Nutrient Probability Distribution ────────────────────────────────────
  Widget _buildNutrientProbabilityDistribution() {
    final Map<String, Map<String, dynamic>> nutrientMeta = {
      'NAB': {
        'label': 'Nitrogen',
        'symbol': 'N',
        'color': const Color(0xFF64B5F6), // soft blue
      },
      'KAB': {
        'label': 'Potassium',
        'symbol': 'K',
        'color': const Color(0xFFCE93D8), // soft purple
      },
      'PAB': {
        'label': 'Phosphorus',
        'symbol': 'P',
        'color': const Color(0xFFFFB74D), // soft amber
      },
      'ZNAB': {
        'label': 'Zinc',
        'symbol': 'ZN',
        'color': const Color(0xFF4DB6AC), // teal
      },
    };

    // Extract probabilities for the 4 target nutrients
    final Map<String, double> nutrients = {
      for (final key in ['NAB', 'KAB', 'PAB', 'ZNAB'])
        key: _allProbabilities?[key] ?? 0.0,
    };

    // Identify the highest-probability nutrient deficiency
    final highestKey = nutrients.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1F33),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF00D9A0).withOpacity(0.22),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00D9A0).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.bar_chart_rounded,
                  color: Color(0xFF00D9A0),
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Nutrient Probability Distribution',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Model likelihood per nutrient deficiency',
            style: TextStyle(color: Colors.white38, fontSize: 11.5),
          ),
          const SizedBox(height: 16),
          // ── Divider
          Container(
            height: 1,
            color: Colors.white.withOpacity(0.06),
            margin: const EdgeInsets.only(bottom: 16),
          ),
          // ── Nutrient rows
          ...nutrients.entries.map((entry) {
            final meta = nutrientMeta[entry.key]!;
            return _buildNutrientRow(
              symbol: meta['symbol'] as String,
              label: meta['label'] as String,
              probability: entry.value,
              color: meta['color'] as Color,
              isHighest: entry.key == highestKey,
            );
          }),
          // ── Footer note
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.info_outline,
                  color: Colors.white24, size: 13),
              const SizedBox(width: 6),
              const Text(
                'Values from model softmax output',
                style: TextStyle(color: Colors.white24, fontSize: 10.5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientRow({
    required String symbol,
    required String label,
    required double probability,
    required Color color,
    required bool isHighest,
  }) {
    final pct = (probability * 100).toStringAsFixed(1);
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, _) {
        final animatedValue =
            (probability * _animationController.value).clamp(0.0, 1.0);
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: isHighest
                ? const EdgeInsets.fromLTRB(10, 10, 10, 10)
                : EdgeInsets.zero,
            decoration: isHighest
                ? BoxDecoration(
                    color: color.withOpacity(0.09),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: color.withOpacity(0.40), width: 1.2),
                  )
                : null,
            child: Row(
              children: [
                // ── Symbol badge
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withOpacity(isHighest ? 0.22 : 0.10),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Text(
                      symbol,
                      style: TextStyle(
                        color: color,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // ── Label + progress bar
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '$label Deficiency',
                            style: TextStyle(
                              color:
                                  isHighest ? color : Colors.white60,
                              fontSize: 12.5,
                              fontWeight: isHighest
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                          if (isHighest) ...
                            [
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.22),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  'PRIMARY',
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 0.9,
                                  ),
                                ),
                              ),
                            ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: animatedValue,
                          minHeight: 7,
                          backgroundColor:
                              Colors.white.withOpacity(0.07),
                          valueColor:
                              AlwaysStoppedAnimation<Color>(color),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // ── Percentage
                SizedBox(
                  width: 44,
                  child: Text(
                    '$pct%',
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: isHighest ? color : Colors.white38,
                      fontSize: 13,
                      fontWeight: isHighest
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── Confidence Banner ───────────────────────────────────────────────────
  Widget _buildConfidenceBanner() {
    final conf = _confidence ?? 0;
    final bool isHigh = conf >= 0.80;
    final bool isModerate = conf < 0.65;

    if (!isHigh && !isModerate) return const SizedBox.shrink();

    final Color bgColor = isHigh
        ? const Color(0xFF00D9A0).withOpacity(0.12)
        : Colors.amber.withOpacity(0.10);
    final Color borderColor = isHigh
        ? const Color(0xFF00D9A0).withOpacity(0.4)
        : Colors.amber.withOpacity(0.4);
    final Color iconColor =
        isHigh ? const Color(0xFF00D9A0) : Colors.amber;
    final IconData icon =
        isHigh ? Icons.verified_rounded : Icons.warning_amber_rounded;
    final String label = isHigh
        ? 'High Confidence Prediction'
        : 'Moderate Confidence – Secondary nutrient deficiencies possible.';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: iconColor,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Multi-Condition Section ──────────────────────────────────────────────
  Widget _buildMultiConditionSection() {
    final secondaries = _top3!.skip(1).toList(); // indices 1 & 2
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1F33),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.blueAccent.withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.biotech_rounded,
                color: Colors.blueAccent,
                size: 18,
              ),
              const SizedBox(width: 8),
              const Text(
                'Other Possible Nutrient Conditions',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Secondary candidates identified by the model:',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          ...secondaries.map((item) {
            final cls = item['class'] as String? ?? '';
            final prob =
                ((item['probability'] as num?)?.toDouble() ?? 0.0);
            return _buildSecondaryConditionRow(cls, prob);
          }),
        ],
      ),
    );
  }

  Widget _buildSecondaryConditionRow(String className, double probability) {
    final pct = (probability * 100).toStringAsFixed(1);
    final Color barColor = _secondaryColor(className);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: barColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: barColor.withOpacity(0.4)),
                    ),
                    child: Text(
                      className,
                      style: TextStyle(
                        color: barColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _deficiencyLabel(className),
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              Text(
                '$pct%',
                style: TextStyle(
                  color: barColor,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: probability.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: Colors.white.withOpacity(0.08),
              valueColor: AlwaysStoppedAnimation<Color>(barColor),
            ),
          ),
        ],
      ),
    );
  }

  Color _secondaryColor(String className) {
    switch (className) {
      case 'NAB':
        return Colors.lightBlueAccent;
      case 'KAB':
        return Colors.purpleAccent;
      case 'PAB':
        return Colors.orangeAccent;
      case 'ZNAB':
        return Colors.tealAccent;
      case 'Healthy':
        return const Color(0xFF00D9A0);
      default:
        return Colors.blueAccent;
    }
  }

  String _deficiencyLabel(String className) {
    switch (className) {
      case 'NAB':
        return 'Nitrogen Deficiency';
      case 'KAB':
        return 'Potassium Deficiency';
      case 'PAB':
        return 'Phosphorus Deficiency';
      case 'ZNAB':
        return 'Zinc Deficiency';
      case 'Healthy':
        return 'No Deficiency';
      default:
        return 'Unknown';
    }
  }

  Widget _buildNutrientGauges() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1F33),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCircularGauge(
                'Nitrogen (N)',
                _predictedClass == 'NAB' ? 2.4 : 3.5,
                _predictedClass == 'NAB',
              ),
              _buildCircularGauge(
                'Phosphorus (P)',
                _predictedClass == 'PAB' ? 0.5 : 3.2,
                _predictedClass == 'PAB',
              ),
              _buildCircularGauge(
                'Potassium (K)',
                _predictedClass == 'KAB' ? 1.9 : 3.0,
                _predictedClass == 'KAB',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCircularGauge(String label, double value, bool isDeficient) {
    final percentage = (value / 4.0).clamp(0.0, 1.0);
    final color = isDeficient ? Colors.orange : const Color(0xFF00D9A0);
    final status = isDeficient ? '[Low]' : '[Optimal]';

    return Column(
      children: [
        SizedBox(
          width: 90,
          height: 90,
          child: Stack(
            children: [
              Center(
                child: SizedBox(
                  width: 80,
                  height: 80,
                  child: AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: CircularGaugePainter(
                          percentage: percentage * _animationController.value,
                          color: color,
                        ),
                      );
                    },
                  ),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${value.toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(status, style: TextStyle(color: color, fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildConfidenceChart() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1F33),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Confidence Score',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${((_confidence ?? 0) * 100).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Color(0xFF00D9A0),
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 100,
            child: AnimatedBuilder(
              animation: _animationController,
              builder: (context, child) {
                return CustomPaint(
                  size: const Size(double.infinity, 100),
                  painter: ConfidenceChartPainter(
                    confidence: (_confidence ?? 0) * _animationController.value,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionRequired() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1D1F33),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _getStatusColor(_predictedClass!).withOpacity(0.3),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _getStatusColor(_predictedClass!).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _predictedClass == 'Healthy'
                  ? Icons.check_circle
                  : Icons.agriculture,
              color: _getStatusColor(_predictedClass!),
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Action Required:',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  _getActionRequired(_predictedClass!),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class CircularGaugePainter extends CustomPainter {
  final double percentage;
  final Color color;

  CircularGaugePainter({required this.percentage, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // Background arc
    final backgroundPaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Foreground arc
    final foregroundPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * percentage,
      false,
      foregroundPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CircularGaugePainter oldDelegate) {
    return oldDelegate.percentage != percentage;
  }
}

class ConfidenceChartPainter extends CustomPainter {
  final double confidence;

  ConfidenceChartPainter({required this.confidence});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF00D9A0).withOpacity(0.3),
          const Color(0xFF00D9A0).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final linePaint = Paint()
      ..color = const Color(0xFF00D9A0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    final path = Path();
    final wavePath = Path();

    // Create wave pattern
    final points = <Offset>[];
    for (int i = 0; i <= 50; i++) {
      final x = (size.width / 50) * i;
      final baseY = size.height * (1 - confidence * 0.8);
      final wave = math.sin(i * 0.3) * 8;
      final y = baseY + wave;
      points.add(Offset(x, y));
    }

    // Draw filled area
    path.moveTo(0, size.height);
    for (final point in points) {
      path.lineTo(point.dx, point.dy);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);

    // Draw line
    wavePath.moveTo(points[0].dx, points[0].dy);
    for (final point in points) {
      wavePath.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(wavePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant ConfidenceChartPainter oldDelegate) {
    return oldDelegate.confidence != confidence;
  }
}
