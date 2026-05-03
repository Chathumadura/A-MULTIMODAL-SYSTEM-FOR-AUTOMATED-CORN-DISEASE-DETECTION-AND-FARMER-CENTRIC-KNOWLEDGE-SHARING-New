import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/localization/app_localizations.dart';

class LeafDiagnosisPage extends StatefulWidget {
  const LeafDiagnosisPage({super.key});

  @override
  State<LeafDiagnosisPage> createState() => _LeafDiagnosisPageState();
}

class _LeafDiagnosisPageState extends State<LeafDiagnosisPage> {
  final ImagePicker _picker = ImagePicker();
  final ApiClient _apiClient = ApiClient();

  File? _image;
  bool _loading = false;
  String? _error;
  Map<String, dynamic>? _result;

  Future<void> _pickImage(ImageSource source) async {
    final picked = await _picker.pickImage(source: source);
    if (picked == null) {
      return;
    }

    setState(() {
      _image = File(picked.path);
      _result = null;
      _error = null;
    });
  }

  Future<void> _runDiagnosis() async {
    if (_image == null || _loading) {
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final data = await _apiClient.predictLeafDiagnosis(_image!);
      if (!mounted) return;
      setState(() {
        _result = data;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF1B1B1B),
        title: Text(
          loc.translate('leaf_diagnosis_title'),
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: const Color(0xFF1B1B1B),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFF1B5E20),
                      Color(0xFF2E7D32),
                      Color(0xFF66BB6A),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1B5E20).withOpacity(0.25),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.translate('leaf_diagnosis_title'),
                      style: GoogleFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loc.translate('leaf_diagnosis_subtitle'),
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withOpacity(0.95),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _ImagePanel(
                image: _image,
                loading: _loading,
                onPickCamera: () => _pickImage(ImageSource.camera),
                onPickGallery: () => _pickImage(ImageSource.gallery),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: (_image == null || _loading)
                      ? null
                      : _runDiagnosis,
                  icon: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.analytics_outlined),
                  label: Text(
                    loc.translate('leaf_diagnosis_run'),
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                _MessageCard(
                  title: 'Error',
                  message: _error!,
                  color: Colors.red.shade700,
                  icon: Icons.error_outline,
                ),
              ],
              if (_result != null) ...[
                const SizedBox(height: 16),
                _FinalDiagnosisCard(result: _result!, loc: loc),
                const SizedBox(height: 16),
                _ModelResultCard(
                  title: loc.translate('leaf_diagnosis_nutrition_title'),
                  modelResult:
                      _result!['nutrition_result'] as Map<String, dynamic>?,
                  accentColor: const Color(0xFF2E7D32),
                ),
                const SizedBox(height: 12),
                _ModelResultCard(
                  title: loc.translate('leaf_diagnosis_disease_title'),
                  modelResult:
                      _result!['disease_result'] as Map<String, dynamic>?,
                  accentColor: const Color(0xFF1565C0),
                ),
                if (_result!['final_diagnosis_type'] == 'nutrient_deficiency' &&
                    _result!['fertilizer_recommendations'] != null) ...[
                  const SizedBox(height: 12),
                  _RecommendationCard(
                    title: loc.translate('leaf_diagnosis_fertilizer_title'),
                    recommendation:
                        _result!['fertilizer_recommendations']
                            as Map<String, dynamic>,
                  ),
                ],
                if (_result!['final_diagnosis_type'] == 'invalid_image') ...[
                  const SizedBox(height: 12),
                  _MessageCard(
                    title: loc.translate('leaf_diagnosis_warning'),
                    message:
                        'The uploaded image does not appear to be a corn leaf. Please upload a clearer leaf image.',
                    color: Colors.orange.shade700,
                    icon: Icons.warning_amber_outlined,
                  ),
                ],
                if (_result!['final_diagnosis_type'] == 'uncertain') ...[
                  const SizedBox(height: 12),
                  _PossibleDiagnosesCard(result: _result!, loc: loc),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ImagePanel extends StatelessWidget {
  const _ImagePanel({
    required this.image,
    required this.loading,
    required this.onPickCamera,
    required this.onPickGallery,
  });

  final File? image;
  final bool loading;
  final VoidCallback onPickCamera;
  final VoidCallback onPickGallery;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.green.shade100, width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Leaf image',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF1B1B1B),
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: AspectRatio(
              aspectRatio: 4 / 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  image == null
                      ? Container(
                          color: const Color(0xFFF2F8F0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.photo_camera_outlined,
                                size: 52,
                                color: Colors.green.shade400,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Upload or capture a single leaf image once.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF4A5A4F),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Image.file(image!, fit: BoxFit.cover),
                  if (loading)
                    Container(
                      color: Colors.black.withOpacity(0.25),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: loading ? null : onPickCamera,
                  icon: const Icon(Icons.camera_alt_outlined, size: 18),
                  label: const Text('Capture'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: loading ? null : onPickGallery,
                  icon: const Icon(Icons.photo_library_outlined, size: 18),
                  label: const Text('Gallery'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinalDiagnosisCard extends StatelessWidget {
  const _FinalDiagnosisCard({required this.result, required this.loc});

  final Map<String, dynamic> result;
  final AppLocalizations loc;

  Color _colorForType(String type) {
    switch (type) {
      case 'healthy':
        return Colors.green;
      case 'nutrient_deficiency':
        return Colors.orange;
      case 'disease':
        return Colors.red;
      case 'invalid_image':
        return Colors.deepOrange;
      default:
        return Colors.blueGrey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final type = (result['final_diagnosis_type'] as String?) ?? 'uncertain';
    final color = _colorForType(type);
    final confidence = (result['confidence'] as num?)?.toDouble() ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withOpacity(0.22), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 14,
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
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.health_and_safety, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.translate('leaf_diagnosis_result_title'),
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1B1B1B),
                      ),
                    ),
                    Text(
                      type.replaceAll('_', ' ').toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '${(confidence * 100).toStringAsFixed(1)}%',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            (result['message'] as String?) ?? '',
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.5,
              color: const Color(0xFF414141),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Final prediction: ${result['final_prediction'] ?? '-'}',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B1B1B),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModelResultCard extends StatelessWidget {
  const _ModelResultCard({
    required this.title,
    required this.modelResult,
    required this.accentColor,
  });

  final String title;
  final Map<String, dynamic>? modelResult;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final prediction =
        modelResult?['predicted_class'] ?? modelResult?['prediction'] ?? '-';
    final confidence = (modelResult?['confidence'] as num?)?.toDouble();
    final top3 = modelResult?['top_3'] as List<dynamic>?;
    final allProbabilities =
        modelResult?['all_probabilities'] as Map<String, dynamic>?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: accentColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Prediction: $prediction',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (confidence != null) ...[
            const SizedBox(height: 4),
            Text(
              'Confidence: ${(confidence * 100).toStringAsFixed(1)}%',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
          ],
          if (modelResult?['message'] != null) ...[
            const SizedBox(height: 6),
            Text(
              modelResult!['message'].toString(),
              style: GoogleFonts.poppins(fontSize: 12.5, height: 1.45),
            ),
          ],
          if (top3 != null && top3.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Top possibilities',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...top3.take(3).map((item) {
              final map = item as Map<String, dynamic>;
              final label =
                  map['class'] ??
                  map['prediction'] ??
                  map['predicted_class'] ??
                  '-';
              final value =
                  (map['probability'] as num?)?.toDouble() ??
                  (map['confidence'] as num?)?.toDouble() ??
                  0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(label.toString())),
                    Text('${(value * 100).toStringAsFixed(1)}%'),
                  ],
                ),
              );
            }),
          ],
          if (allProbabilities != null && allProbabilities.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'All probabilities',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...allProbabilities.entries.map((entry) {
              final value = (entry.value as num?)?.toDouble() ?? 0.0;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(child: Text(entry.key)),
                    Text('${(value * 100).toStringAsFixed(1)}%'),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  const _RecommendationCard({
    required this.title,
    required this.recommendation,
  });

  final String title;
  final Map<String, dynamic> recommendation;

  @override
  Widget build(BuildContext context) {
    final additionalTips = recommendation['additional_tips'] as List<dynamic>?;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.orange.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            recommendation['summary']?.toString() ?? '',
            style: GoogleFonts.poppins(fontSize: 13, height: 1.45),
          ),
          if (recommendation['fertilizer'] != null) ...[
            const SizedBox(height: 8),
            Text(
              'Fertilizer: ${recommendation['fertilizer']}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (recommendation['application_rate'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Rate: ${recommendation['application_rate']}',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
          ],
          if (recommendation['application_timing'] != null) ...[
            const SizedBox(height: 4),
            Text(
              'Timing: ${recommendation['application_timing']}',
              style: GoogleFonts.poppins(fontSize: 13),
            ),
          ],
          if (additionalTips != null && additionalTips.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Tips',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            ...additionalTips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text('• ${tip.toString()}'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PossibleDiagnosesCard extends StatelessWidget {
  const _PossibleDiagnosesCard({required this.result, required this.loc});

  final Map<String, dynamic> result;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final possible = result['possible_diagnoses'] as List<dynamic>? ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            loc.translate('leaf_diagnosis_uncertain_title'),
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.blueGrey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          ...possible.map((item) {
            final map = item as Map<String, dynamic>;
            final source = map['source']?.toString() ?? '-';
            final prediction = map['prediction']?.toString() ?? '-';
            final confidence = (map['confidence'] as num?)?.toDouble() ?? 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '$source: $prediction',
                      style: GoogleFonts.poppins(fontSize: 13),
                    ),
                  ),
                  Text(
                    '${(confidence * 100).toStringAsFixed(1)}%',
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  const _MessageCard({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
  });

  final String title;
  final String message;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.18)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: GoogleFonts.poppins(fontSize: 13, height: 1.45),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
