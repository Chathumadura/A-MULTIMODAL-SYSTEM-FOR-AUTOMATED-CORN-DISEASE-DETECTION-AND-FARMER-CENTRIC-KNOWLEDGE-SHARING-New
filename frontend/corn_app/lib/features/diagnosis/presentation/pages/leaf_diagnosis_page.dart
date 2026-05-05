import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/localization/app_localizations.dart';
import 'nutrient_prediction_page.dart';

String? _readString(Map<String, dynamic> map, List<String> keys) {
  for (final key in keys) {
    final value = map[key];
    if (value == null) continue;
    final text = value.toString().trim();
    if (text.isNotEmpty && text != 'null') {
      return text;
    }
  }
  return null;
}

double? _confidencePercent(dynamic value) {
  if (value is num) {
    final number = value.toDouble();
    return number <= 1 ? number * 100 : number;
  }
  final parsed = double.tryParse(value?.toString() ?? '');
  if (parsed == null) return null;
  return parsed <= 1 ? parsed * 100 : parsed;
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

class LeafDiagnosisPage extends StatefulWidget {
  const LeafDiagnosisPage({super.key});

  @override
  State<LeafDiagnosisPage> createState() => _LeafDiagnosisPageState();
}

class _LeafDiagnosisPageState extends State<LeafDiagnosisPage> {
  final ImagePicker _picker = ImagePicker();
  final ApiClient _apiClient = ApiClient();

  File? _selectedImage;
  bool _isPicking = false;
  bool _isAnalyzing = false;
  String? _errorMessage;
  Map<String, dynamic>? _result;

  Future<void> _pickImage(ImageSource source) async {
    if (_isPicking || _isAnalyzing) return;

    setState(() {
      _isPicking = true;
      _errorMessage = null;
    });

    try {
      final picked = await _picker.pickImage(source: source, imageQuality: 92);
      if (picked == null) return;
      if (!mounted) return;

      setState(() {
        _selectedImage = File(picked.path);
        _result = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to pick image. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isPicking = false;
        });
      }
    }
  }

  Future<void> _analyzeLeaf() async {
    if (_isAnalyzing) return;

    if (_selectedImage == null) {
      setState(() {
        _errorMessage = 'Please pick or capture a leaf image first.';
      });
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final data = await _apiClient.predictLeafDiagnosis(_selectedImage!);
      if (!mounted) return;
      setState(() {
        _result = data;
      });
      // Show diagnosis popup first
      await _showDiagnosisPopup(data);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _friendlyErrorMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
        });
      }
    }
  }

  Future<void> _showDiagnosisPopup(Map<String, dynamic> result) async {
    if (!mounted) return;

    final type = _readString(result, ['final_diagnosis_type']) ?? 'uncertain';
    final issue = _readString(result, ['final_prediction']) ?? 'Unknown';
    final confidence = _confidencePercent(result['confidence']);
    final message = _readString(result, ['message']) ?? '';
    final accentColor = _colorForType(type);
    final label = _labelForDiagnosisCategory(type);
    final nutrition = _asMap(result['nutrition_result']);
    final disease = _asMap(result['disease_result']);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: 20 + MediaQuery.of(sheetContext).padding.bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Diagnosis Found',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: accentColor.withOpacity(0.20)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: accentColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Detected: $issue',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    if (confidence != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Confidence: ${confidence.toStringAsFixed(1)}%',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (message.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  message,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    height: 1.5,
                    color: Colors.black87,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _buildDiagnosisExplanation(type, nutrition, disease),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.black54,
                        side: const BorderSide(color: Color(0xFFDDD8D8)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'Close',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          _openResultDetails(result);
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accentColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        'View Details',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  String _labelForDiagnosisCategory(String type) {
    switch (type) {
      case 'nutrient_deficiency':
        return 'Nutrient Deficiency Detected';
      case 'disease':
        return 'Disease Detected';
      case 'healthy':
        return 'Healthy Leaf';
      case 'invalid_image':
        return 'Invalid Image';
      case 'uncertain':
        return 'Uncertain Result';
      default:
        return 'Analysis Result';
    }
  }

  Widget _buildDiagnosisExplanation(
    String type,
    Map<String, dynamic>? nutrition,
    Map<String, dynamic>? disease,
  ) {
    if (type == 'nutrient_deficiency') {
      final nutLabel = nutrition != null
          ? _readString(nutrition, ['predicted_class', 'final_prediction']) ??
                '-'
          : '-';
      final nutConf = _confidencePercent(nutrition?['confidence']);
      final disConf = _confidencePercent(disease?['confidence']);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why this diagnosis:',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Backend final diagnosis: nutrient deficiency',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Nutrition model: $nutLabel${nutConf != null ? " (${nutConf.toStringAsFixed(1)}%)" : ""}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The backend combined the model outputs and returned nutrient deficiency as the final diagnosis.',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    height: 1.4,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (type == 'disease') {
      final disLabel = disease != null
          ? _readString(disease, ['predicted_class', 'final_prediction']) ?? '-'
          : '-';
      final disConf = _confidencePercent(disease?['confidence']);
      final nutConf = _confidencePercent(nutrition?['confidence']);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF5F5F5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Why this diagnosis:',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Backend final diagnosis: disease',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Disease model: $disLabel${disConf != null ? " (${disConf.toStringAsFixed(1)}%)" : ""}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'The backend combined the model outputs and returned disease as the final diagnosis.',
                  style: GoogleFonts.poppins(
                    fontSize: 11.5,
                    height: 1.4,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }
    if (type == 'healthy') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'No strong nutrient deficiency or disease signal was detected. The leaf appears healthy.',
          style: GoogleFonts.poppins(
            fontSize: 12,
            height: 1.4,
            color: Colors.black87,
          ),
        ),
      );
    }
    if (type == 'invalid_image') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'The uploaded image does not appear to be a valid corn leaf. Please upload a clear corn leaf image.',
          style: GoogleFonts.poppins(
            fontSize: 12,
            height: 1.4,
            color: Colors.black87,
          ),
        ),
      );
    }
    if (type == 'uncertain') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'The system could not confidently decide. Please upload a clearer image with good lighting and visible symptoms.',
          style: GoogleFonts.poppins(
            fontSize: 12,
            height: 1.4,
            color: Colors.black87,
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Future<void> _openResultDetails(Map<String, dynamic> result) async {
    final type = _readString(result, ['final_diagnosis_type']) ?? 'uncertain';

    if (type == 'nutrient_deficiency') {
      final nutritionResult = Map<String, dynamic>.from(
        _asMap(result['nutrition_result']) ?? const <String, dynamic>{},
      );
      nutritionResult['fertilizer_recommendations'] =
          result['fertilizer_recommendations'];

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NutrientPredictionPage(
            imageFile: _selectedImage,
            precomputedResult: nutritionResult,
            skipApiCall: true,
          ),
        ),
      );
    }
  }

  void _clearFeedback() {
    setState(() {
      _errorMessage = null;
      _result = null;
    });
  }

  String _friendlyErrorMessage(Object error) {
    final raw = error.toString();

    // Network/connection errors
    if (raw.contains('SocketException') || raw.contains('Failed host lookup')) {
      return 'Cannot connect to backend. Please check internet connection or backend server URL.';
    }
    if (raw.contains('TimeoutException') ||
        raw.toLowerCase().contains('timeout')) {
      return 'Request timed out. The server may be waking up, so please try again.';
    }
    if (raw.contains('Connection refused') ||
        raw.contains('connection refused')) {
      return 'Cannot connect to backend. Backend server may be offline.';
    }

    // HTTP and other errors
    return raw.startsWith('Exception: ') ? raw.substring(11) : raw;
  }

  Color _colorForType(String type) {
    switch (type) {
      case 'invalid_image':
        return const Color(0xFFC56A00);
      case 'uncertain':
        return const Color(0xFF1565C0);
      case 'disease':
        return const Color(0xFFC62828);
      case 'nutrient_deficiency':
        return const Color(0xFF2E7D32);
      case 'healthy':
        return const Color(0xFF1B5E20);
      default:
        return const Color(0xFF1B5E20);
    }
  }

  String _labelForType(AppLocalizations loc, String type) {
    switch (type) {
      case 'invalid_image':
        return loc.translate('leaf_diagnosis_invalid_image_title');
      case 'uncertain':
        return loc.translate('leaf_diagnosis_uncertain_title');
      default:
        return type.replaceAll('_', ' ').trim().toUpperCase();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final type =
        _readString(_result ?? const <String, dynamic>{}, [
          'final_diagnosis_type',
        ]) ??
        '';
    final accentColor = _colorForType(type);
    final diagnosisLabel = type.isEmpty
        ? loc.translate('leaf_diagnosis_final_title')
        : _labelForType(loc, type);

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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F5E9), Color(0xFFF7FBF4), Colors.white],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderCard(
                  title: loc.translate('leaf_diagnosis_title'),
                  subtitle: loc.translate('leaf_diagnosis_subtitle'),
                  chipText: loc.translate('leaf_diagnosis_chip'),
                ),
                const SizedBox(height: 16),
                _ImageCard(
                  image: _selectedImage,
                  isBusy: _isPicking || _isAnalyzing,
                  loc: loc,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: (_isPicking || _isAnalyzing)
                              ? null
                              : () => _pickImage(ImageSource.gallery),
                          icon: const Icon(
                            Icons.photo_library_outlined,
                            size: 18,
                          ),
                          label: Text(
                            loc.translate('leaf_diagnosis_pick'),
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1B5E20),
                            side: const BorderSide(color: Color(0xFFB9D9BC)),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 46,
                        child: OutlinedButton.icon(
                          onPressed: (_isPicking || _isAnalyzing)
                              ? null
                              : () => _pickImage(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt_outlined, size: 18),
                          label: Text(
                            loc.translate('leaf_diagnosis_capture'),
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1B5E20),
                            side: const BorderSide(color: Color(0xFFB9D9BC)),
                            backgroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton.icon(
                    onPressed: _isAnalyzing ? null : _analyzeLeaf,
                    icon: _isAnalyzing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Icon(Icons.analytics_outlined),
                    label: Text(
                      loc.translate('leaf_diagnosis_analyze'),
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: const Color(0xFFA8C8AA),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 3,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (_errorMessage != null) ...[
                  _NoticeCard(
                    title: type == 'invalid_image'
                        ? loc.translate('leaf_diagnosis_invalid_image_title')
                        : loc.translate('leaf_diagnosis_warning'),
                    message: _errorMessage!,
                    color: Colors.deepOrange,
                    icon: Icons.warning_amber_outlined,
                    actionLabel: loc.translate('leaf_diagnosis_try_again'),
                    onActionTap: _clearFeedback,
                  ),
                  const SizedBox(height: 16),
                ],
                if (_isAnalyzing) ...[
                  const _LoadingCard(),
                  const SizedBox(height: 16),
                ],
                if (_result != null) ...[
                  _FinalDiagnosisCard(
                    result: _result!,
                    accentColor: accentColor,
                    title: loc.translate('leaf_diagnosis_final_title'),
                    diagnosisLabel: diagnosisLabel,
                    loc: loc,
                  ),
                  const SizedBox(height: 14),
                  _ModelResultCard(
                    title: loc.translate('leaf_diagnosis_nutrition_title'),
                    data: _asMap(_result!['nutrition_result']),
                    accentColor: const Color(0xFF2E7D32),
                  ),
                  const SizedBox(height: 12),
                  _ModelResultCard(
                    title: loc.translate('leaf_diagnosis_disease_title'),
                    data: _asMap(_result!['disease_result']),
                    accentColor: const Color(0xFF1565C0),
                  ),
                  const SizedBox(height: 12),
                  if (_result!['fertilizer_recommendations'] != null)
                    _FertilizerCard(
                      title: loc.translate('leaf_diagnosis_fertilizer_title'),
                      recommendation: _result!['fertilizer_recommendations'],
                    ),
                  if (_result!['fertilizer_recommendations'] != null)
                    const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: _clearFeedback,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(
                        loc.translate('leaf_diagnosis_try_again'),
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF1B5E20),
                      ),
                    ),
                  ),
                ],
                if (_result == null &&
                    _errorMessage == null &&
                    !_isAnalyzing) ...[
                  const SizedBox(height: 4),
                  Text(
                    loc.translate('leaf_diagnosis_selected_image'),
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF5D6D60),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pick or capture one clear corn leaf, then tap Analyze Leaf.',
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      height: 1.5,
                      color: const Color(0xFF5D6D60),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.title,
    required this.subtitle,
    required this.chipText,
  });

  final String title;
  final String subtitle;
  final String chipText;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1B5E20), Color(0xFF388E3C), Color(0xFF66BB6A)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1B5E20).withOpacity(0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.95),
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    chipText,
                    style: GoogleFonts.poppins(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Colors.white.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: const Icon(
              Icons.biotech_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageCard extends StatelessWidget {
  const _ImageCard({
    required this.image,
    required this.isBusy,
    required this.loc,
  });

  final File? image;
  final bool isBusy;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD7E8D8), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                loc.translate('leaf_diagnosis_selected_image'),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1B1B1B),
                ),
              ),
              const Spacer(),
              if (image != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Ready',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: const Color(0xFF1B5E20),
                    ),
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
                  fit: StackFit.expand,
                  children: [
                    if (image == null)
                      Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFF1F8F1),
                              Color(0xFFE8F5E9),
                              Color(0xFFDFF0DE),
                            ],
                          ),
                        ),
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
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: Text(
                                'Choose a clear corn leaf image from gallery or camera.',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: const Color(0xFF5B7160),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else
                      Image.file(image!, fit: BoxFit.cover),
                    if (isBusy)
                      Container(
                        color: Colors.black.withOpacity(0.22),
                        child: const Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
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

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDBE7D8)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2.4),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              loc.translate('leaf_diagnosis_analyze'),
              style: GoogleFonts.poppins(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1B1B1B),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
    this.actionLabel,
    this.onActionTap,
  });

  final String title;
  final String message;
  final Color color;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onActionTap;

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
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    height: 1.45,
                    color: const Color(0xFF3E453F),
                  ),
                ),
                if (actionLabel != null && onActionTap != null) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: onActionTap,
                    style: TextButton.styleFrom(
                      foregroundColor: color,
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      actionLabel!,
                      style: GoogleFonts.poppins(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalDiagnosisCard extends StatelessWidget {
  const _FinalDiagnosisCard({
    required this.result,
    required this.accentColor,
    required this.title,
    required this.diagnosisLabel,
    required this.loc,
  });

  final Map<String, dynamic> result;
  final Color accentColor;
  final String title;
  final String diagnosisLabel;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final finalPrediction = result['final_prediction']?.toString() ?? '-';
    final confidence = _confidencePercent(result['confidence']);
    final message = result['message']?.toString() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: accentColor.withOpacity(0.20), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                  color: accentColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.health_and_safety, color: accentColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1B1B1B),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      diagnosisLabel,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
              ),
              if (confidence != null)
                Text(
                  '${confidence.toStringAsFixed(1)}%',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          _FieldRow(label: 'Final prediction', value: finalPrediction),
          const SizedBox(height: 8),
          _FieldRow(
            label: 'Confidence',
            value: confidence != null
                ? '${confidence.toStringAsFixed(1)}%'
                : '-',
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.5,
                color: const Color(0xFF3E453F),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _Badge(
                label: loc.translate('leaf_diagnosis_final_title'),
                color: accentColor,
              ),
              if (result['final_diagnosis_type'] != null)
                _Badge(
                  label: result['final_diagnosis_type'].toString(),
                  color: accentColor.withOpacity(0.85),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ModelResultCard extends StatelessWidget {
  const _ModelResultCard({
    required this.title,
    required this.data,
    required this.accentColor,
  });

  final String title;
  final Map<String, dynamic>? data;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    if (data == null || data!.isEmpty) {
      return const SizedBox.shrink();
    }

    final prediction =
        _readString(data!, [
          'final_prediction',
          'predicted_class',
          'prediction',
        ]) ??
        '-';
    final confidence = _confidencePercent(data!['confidence']);
    final message = _readString(data!, ['message', 'summary']) ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
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
          const SizedBox(height: 10),
          _FieldRow(label: 'Prediction', value: prediction),
          if (confidence != null) ...[
            const SizedBox(height: 8),
            _FieldRow(
              label: 'Confidence',
              value: '${confidence.toStringAsFixed(1)}%',
            ),
          ],
          if (message.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              message,
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.45,
                color: const Color(0xFF444444),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _FertilizerCard extends StatelessWidget {
  const _FertilizerCard({required this.title, required this.recommendation});

  final String title;
  final dynamic recommendation;

  @override
  Widget build(BuildContext context) {
    if (recommendation == null) return const SizedBox.shrink();

    if (recommendation is! Map) {
      final text = recommendation.toString().trim();
      if (text.isEmpty || text == 'null') return const SizedBox.shrink();
      return _simpleRecommendationCard(title: title, text: text);
    }

    final data = Map<String, dynamic>.from(recommendation as Map);
    if (data.isEmpty) return const SizedBox.shrink();

    final summary = _readString(data, ['summary', 'message']) ?? '';
    final fertilizer = _readString(data, ['fertilizer', 'recommendation']);
    final applicationRate = _readString(data, ['application_rate']);
    final applicationTiming = _readString(data, ['application_timing']);
    final tips = data['additional_tips'];
    const accentColor = Color(0xFFC56A00);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withOpacity(0.18)),
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
          if (summary.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              summary,
              style: GoogleFonts.poppins(
                fontSize: 13,
                height: 1.45,
                color: const Color(0xFF4B4330),
              ),
            ),
          ],
          if (fertilizer != null) ...[
            const SizedBox(height: 10),
            _FieldRow(label: 'Fertilizer', value: fertilizer),
          ],
          if (applicationRate != null) ...[
            const SizedBox(height: 8),
            _FieldRow(label: 'Application rate', value: applicationRate),
          ],
          if (applicationTiming != null) ...[
            const SizedBox(height: 8),
            _FieldRow(label: 'Application timing', value: applicationTiming),
          ],
          if (tips is List && tips.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Tips',
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF7A5D16),
              ),
            ),
            const SizedBox(height: 8),
            ...tips.map(
              (tip) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '• ${tip.toString()}',
                  style: GoogleFonts.poppins(
                    fontSize: 12.5,
                    height: 1.4,
                    color: const Color(0xFF4B4330),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _simpleRecommendationCard({
    required String title,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFC56A00).withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFC56A00),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 13,
              height: 1.45,
              color: const Color(0xFF4B4330),
            ),
          ),
        ],
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF5E6D60),
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1B1B1B),
            ),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
