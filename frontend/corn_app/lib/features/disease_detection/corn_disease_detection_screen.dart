import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import 'api_disease_classifier.dart';
import 'disease_classifier.dart';
import 'disease_prediction.dart';

class CornDiseaseDetectionScreen extends StatefulWidget {
  const CornDiseaseDetectionScreen({super.key, DiseaseClassifier? classifier})
    : _classifier = classifier;

  final DiseaseClassifier? _classifier;

  @override
  State<CornDiseaseDetectionScreen> createState() =>
      _CornDiseaseDetectionScreenState();
}

class _CornDiseaseDetectionScreenState extends State<CornDiseaseDetectionScreen>
    with TickerProviderStateMixin {
  static const double _s8 = 8;
  static const double _s12 = 12;
  static const double _s16 = 16;

  final ImagePicker _picker = ImagePicker();

  late final DiseaseClassifier _classifier;
  late final AnimationController _resultRevealController;
  late final AnimationController _shimmerController;

  File? _image;
  DiseasePrediction? _prediction;
  bool _loading = false;
  bool _showMissingImageHint = false;

  @override
  void initState() {
    super.initState();
    _classifier = widget._classifier ?? ApiDiseaseClassifier();
    _resultRevealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
  }

  @override
  void dispose() {
    _resultRevealController.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;

      setState(() {
        _image = File(file.path);
        _prediction = null;
        _showMissingImageHint = false;
      });
    } catch (_) {
      _showError('Failed to pick image. Please try again.');
    }
  }

  Future<void> _detectDisease() async {
    if (_loading) return;

    if (_image == null) {
      setState(() {
        _showMissingImageHint = true;
      });
      _showError('Please pick an image before detection.');
      return;
    }

    setState(() {
      _loading = true;
      _showMissingImageHint = false;
    });
    _shimmerController.repeat();

    try {
      debugPrint('Starting disease prediction for image: ${_image!.path}');
      final result = await _classifier.predict(_image!);
      debugPrint('Disease prediction completed: ${result.prediction}');
      if (!mounted) return;

      setState(() {
        _prediction = result;
      });
      _resultRevealController.forward(from: 0);
    } catch (_) {
      if (!mounted) return;
      _showError('Detection failed. Please try again.');
    } finally {
      if (mounted) {
        _shimmerController.stop();
        setState(() {
          _loading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1B1B1B),
        title: Text(
          'Corn Disease Detection',
          style: GoogleFonts.poppins(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: const Color(0xFF1B1B1B),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F5E9), Color(0xFFF7FBE8), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(_s16, _s8, _s16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _FeatureBanner(),
                const SizedBox(height: _s16),
                _UploadCard(
                  image: _image,
                  loading: _loading,
                  onReplace: _pickImage,
                ),
                const SizedBox(height: _s12),
                _ActionRow(
                  loading: _loading,
                  hasImage: _image != null,
                  onPick: _pickImage,
                  onDetect: _detectDisease,
                ),
                const SizedBox(height: 6),
                Text(
                  'Best results: single leaf, clear focus, natural light.',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF6A7C71),
                  ),
                ),
                if (_showMissingImageHint) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Pick an image first to run disease detection.',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFC56A00),
                    ),
                  ),
                ],
                const SizedBox(height: _s16),
                _ResultPanel(
                  prediction: _prediction,
                  loading: _loading,
                  reveal: _resultRevealController,
                  shimmer: _shimmerController,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeatureBanner extends StatelessWidget {
  const _FeatureBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF388E3C), Color(0xFF66BB6A)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withValues(alpha: 0.23),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -35,
            top: -20,
            child: Container(
              width: 130,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(50),
                gradient: LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.26),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Smart Disease Detection',
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.biotech_outlined,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Upload a clear corn leaf image to identify disease symptoms.',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.96),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _MiniTag(
                    icon: Icons.wb_sunny_outlined,
                    label: 'Good Lighting',
                  ),
                  _MiniTag(
                    icon: Icons.center_focus_strong,
                    label: 'Close Focus',
                  ),
                  _MiniTag(icon: Icons.eco_outlined, label: 'Leaf Surface'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 14),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadCard extends StatelessWidget {
  const _UploadCard({
    required this.image,
    required this.loading,
    required this.onReplace,
  });

  final File? image;
  final bool loading;
  final VoidCallback onReplace;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDAE8D8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Leaf Image',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1B1B1B),
                ),
              ),
              const Spacer(),
              if (image != null)
                TextButton.icon(
                  onPressed: loading ? null : onReplace,
                  icon: const Icon(Icons.refresh_rounded, size: 16),
                  label: Text(
                    'Replace Image',
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF1B5E20),
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Container(
              color: const Color(0xFFF2F8F0),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: image == null
                          ? const _EmptyState()
                          : Image.file(image!, fit: BoxFit.cover),
                    ),
                    if (loading)
                      Positioned.fill(
                        child: ColoredBox(
                          color: Colors.black.withValues(alpha: 0.26),
                          child: const Center(
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _DotPatternPainter())),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFB7DDBA),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.add_photo_alternate_outlined,
                  size: 34,
                  color: Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'No image selected',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF38513A),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'Choose a clear corn leaf photo for best results.',
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFF5B7160),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.loading,
    required this.hasImage,
    required this.onPick,
    required this.onDetect,
  });

  final bool loading;
  final bool hasImage;
  final VoidCallback onPick;
  final VoidCallback onDetect;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _PressableScale(
            enabled: !loading,
            onTap: onPick,
            child: SizedBox(
              height: 46,
              child: OutlinedButton.icon(
                onPressed: loading ? null : onPick,
                icon: const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(
                  'Pick Image',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1B5E20),
                  side: const BorderSide(color: Color(0xFF7FB986), width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  backgroundColor: Colors.white,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _PressableScale(
            enabled: hasImage && !loading,
            onTap: onDetect,
            child: SizedBox(
              height: 46,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [Color(0xFF1B5E20), Color(0xFF43A047)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1B5E20).withValues(alpha: 0.32),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton.icon(
                  onPressed: hasImage && !loading ? onDetect : null,
                  icon: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Icon(Icons.science_outlined, size: 18),
                  label: Text(
                    'Detect Disease',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.transparent,
                    disabledForegroundColor: Colors.white70,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _PressableScale extends StatefulWidget {
  const _PressableScale({
    required this.child,
    required this.enabled,
    required this.onTap,
  });

  final Widget child;
  final bool enabled;
  final VoidCallback onTap;

  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.enabled ? widget.onTap : null,
      onTapDown: widget.enabled ? (_) => setState(() => _scale = 0.98) : null,
      onTapUp: widget.enabled ? (_) => setState(() => _scale = 1.0) : null,
      onTapCancel: widget.enabled ? () => setState(() => _scale = 1.0) : null,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({
    required this.prediction,
    required this.loading,
    required this.reveal,
    required this.shimmer,
  });

  final DiseasePrediction? prediction;
  final bool loading;
  final AnimationController reveal;
  final AnimationController shimmer;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFDFEBDD), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFE7F4E7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.insights_outlined,
                  color: Color(0xFF1B5E20),
                  size: 18,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Result',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1B1B1B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (loading && prediction == null)
            _ResultSkeleton(shimmer: shimmer)
          else if (prediction == null)
            Text(
              'No result yet',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color(0xFF60746A),
              ),
            )
          else
            FadeTransition(
              opacity: CurvedAnimation(parent: reveal, curve: Curves.easeOut),
              child: SlideTransition(
                position:
                    Tween<Offset>(
                      begin: const Offset(0, 0.05),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(parent: reveal, curve: Curves.easeOut),
                    ),
                child: _ResultContent(prediction: prediction!, reveal: reveal),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'Use good lighting for better accuracy.',
            style: GoogleFonts.poppins(
              fontSize: 11.5,
              color: const Color(0xFF7A8B83),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultSkeleton extends StatelessWidget {
  const _ResultSkeleton({required this.shimmer});

  final AnimationController shimmer;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, child) {
        return Column(
          children: [
            _ShimmerBlock(width: double.infinity, height: 44, t: shimmer.value),
            const SizedBox(height: 10),
            _ShimmerBlock(width: double.infinity, height: 14, t: shimmer.value),
            const SizedBox(height: 8),
            _ShimmerBlock(width: double.infinity, height: 14, t: shimmer.value),
            const SizedBox(height: 8),
            _ShimmerBlock(width: double.infinity, height: 14, t: shimmer.value),
          ],
        );
      },
    );
  }
}

class _ShimmerBlock extends StatelessWidget {
  const _ShimmerBlock({
    required this.width,
    required this.height,
    required this.t,
  });

  final double width;
  final double height;
  final double t;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-1.0 + 2.0 * t, -0.2),
              end: Alignment(1.0 + 2.0 * t, 0.2),
              colors: const [
                Color(0xFFE8EFE6),
                Color(0xFFF3F7F1),
                Color(0xFFE8EFE6),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultContent extends StatelessWidget {
  const _ResultContent({required this.prediction, required this.reveal});

  final DiseasePrediction prediction;
  final AnimationController reveal;

  @override
  Widget build(BuildContext context) {
    final isHealthy = prediction.label == 'Healthy';
    final accent = isHealthy
        ? const Color(0xFF2E7D32)
        : const Color(0xFFC56A00);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accent.withValues(alpha: 0.25)),
          ),
          child: Row(
            children: [
              Icon(
                isHealthy
                    ? Icons.check_circle_outline
                    : Icons.warning_amber_rounded,
                color: accent,
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Predicted: ${prediction.label}',
                  style: GoogleFonts.poppins(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  ),
                ),
              ),
              Text(
                '${(prediction.confidence * 100).toStringAsFixed(2)}%',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Top-3 predictions',
          style: GoogleFonts.poppins(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF4B6053),
          ),
        ),
        const SizedBox(height: 8),
        ...prediction.topK.asMap().entries.map((entry) {
          final animation = CurvedAnimation(
            parent: reveal,
            curve: Interval(
              0.2 + (entry.key * 0.15),
              1.0,
              curve: Curves.easeOutCubic,
            ),
          );
          return _ProbabilityRow(
            label: entry.value.key,
            value: entry.value.value,
            animation: animation,
          );
        }),
      ],
    );
  }
}

class _ProbabilityRow extends StatelessWidget {
  const _ProbabilityRow({
    required this.label,
    required this.value,
    required this.animation,
  });

  final String label;
  final double value;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, child) {
          final shown = value * animation.value;
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF375143),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    '${(shown * 100).toStringAsFixed(2)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: const Color(0xFF375143),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: shown,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE8EFE4),
                  valueColor: const AlwaysStoppedAnimation<Color>(
                    Color(0xFF4CAF50),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFDCEADA);
    const gap = 24.0;
    for (double y = 8; y < size.height; y += gap) {
      for (double x = 8; x < size.width; x += gap) {
        canvas.drawCircle(Offset(x, y), 1.6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
