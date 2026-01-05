// lib/features/diagnosis/presentation/pages/nutrient_prediction_page.dart
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
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
        return 'සින්ක් සල්ෆේට් යොදන්න.\n\nApply Zinc Sulphate.';
      default:
        return 'Unknown deficiency';
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
        return 'සින්ක් (Zn) ඌනතාවය හඳුනාගෙන ඇත. සින්ක් සල්ෆේට් යෙදීම හෝ පත්‍ර ඉසීම සලකා බලන්න.\n\nZinc deficiency detected. Consider zinc sulphate application or foliar spray.';
      default:
        return 'Unknown class.';
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
      });
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
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
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
        );
      },
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
                        _buildConfidenceChart(),
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
