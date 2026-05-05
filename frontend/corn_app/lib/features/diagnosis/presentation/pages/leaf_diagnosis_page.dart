import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/api/api_client.dart';
import '../../../../core/localization/app_localizations.dart';
import 'nutrient_prediction_page.dart';
import '../../../disease_detection/corn_disease_detection_screen.dart';

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

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return null;
}

double _confidenceAsPercent(dynamic value) {
  if (value is num) {
    final v = value.toDouble();
    return v <= 1 ? v * 100 : v;
  }

  final parsed = double.tryParse(value?.toString() ?? '') ?? 0.0;
  return parsed <= 1 ? parsed * 100 : parsed;
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

  Map<String, dynamic> _buildNutritionResultForRedirect(
    Map<String, dynamic> result,
  ) {
    final nutritionResult = Map<String, dynamic>.from(
      _asMap(result['nutrition_result']) ?? const <String, dynamic>{},
    );

    nutritionResult['predicted_class'] ??= result['final_prediction'];
    nutritionResult['confidence'] ??= result['confidence'];

    nutritionResult['fertilizer_recommendations'] =
        result['fertilizer_recommendations'];

    if (nutritionResult['all_probabilities'] == null &&
        nutritionResult['predicted_class'] != null) {
      nutritionResult['all_probabilities'] = {
        nutritionResult['predicted_class']:
            nutritionResult['confidence'] ?? 1.0,
      };
    }

    return nutritionResult;
  }

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
        _errorMessage = null;
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
    });

    try {
      final data = await _apiClient.predictLeafDiagnosis(_selectedImage!);
      if (!mounted) return;

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

    var type = _readString(result, ['final_diagnosis_type']) ?? 'uncertain';
    final finalPrediction = _readString(result, ['final_prediction']);
    final confidencePercent = _confidenceAsPercent(result['confidence']);
    if (finalPrediction == 'Healthy') {
      type = 'healthy';
    }
    if (confidencePercent < 50) {
      type = 'uncertain';
    }
    final accentColor = _colorForType(type);

    String titleText;
    String popupBodySinhala;
    String? cautionSinhala;
    String buttonLabel;
    bool shouldShowBackButton = true;

    switch (type) {
      case 'nutrient_deficiency':
        titleText = 'Nutrient Deficiency';
        popupBodySinhala =
            'මෙම පත්‍රයේ පෙනෙන ලක්ෂණ Nutrient Deficiency එකකට වැඩි වශයෙන් අදාල වේ. '
            'වැඩිදුර විස්තර සහ පොහොර නිර්දේශ ලබා ගැනීමට Nutrient Prediction section එකට යන්න.';
        cautionSinhala =
            'ඉදිරියේදී Disease තත්ත්වයක ලක්ෂණද පෙන්විය හැකිය. '
            'පත්‍රයේ ලප, වියළීම, හෝ පැතිරීම වැඩි වුවහොත් Disease Detection section එකෙන් නැවත පරීක්ෂා කරන්න. '
            'සැලකිල්ලෙන් ඉන්න.';
        buttonLabel = 'පොහොර නිර්දේශ බලන්න';
        break;

      case 'disease':
        titleText = 'Disease';
        popupBodySinhala =
            'මෙම පත්‍රයේ පෙනෙන ලක්ෂණ Disease තත්ත්වයකට වැඩි වශයෙන් අදාල වේ. '
            'වැඩිදුර විස්තර සහ රෝගයට අදාල උපදෙස් ලබා ගැනීමට Disease Detection section එකට යන්න.';
        cautionSinhala =
            'ඉදිරියේදී Nutrient Deficiency ලක්ෂණද පෙන්විය හැකිය. '
            'පත්‍රයේ කහවීම, වර්ධනය අඩුවීම, හෝ Nutrient Deficiency වලට සමාන ලක්ෂණ වැඩි වුවහොත් '
            'Nutrient Prediction section එකෙන් නැවත පරීක්ෂා කරන්න. සැලකිල්ලෙන් ඉන්න.';
        buttonLabel = 'රෝග විස්තර බලන්න';
        break;

      case 'healthy':
        titleText = 'Healthy Leaf';
        popupBodySinhala =
            'මෙම පත්‍රය සෞඛ්‍ය සම්පන්න ලෙස පෙනේ. ප්‍රබල Nutrient Deficiency හෝ Disease තත්ත්වයක් පෙන්වන්නේ නැත.';
        cautionSinhala = null;
        buttonLabel = 'හරි';
        shouldShowBackButton = false;
        break;

      case 'invalid_image':
        titleText = 'Invalid Image';
        popupBodySinhala =
            'කරුණාකර පැහැදිලි බඩඉරිඟු පත්‍රයක රූපයක් upload කරන්න.';
        cautionSinhala = null;
        buttonLabel = 'නැවත උත්සාහ කරන්න';
        shouldShowBackButton = false;
        break;

      case 'uncertain':
      default:
        titleText = 'Uncertain Result';
        popupBodySinhala =
            'ප්‍රතිඵලය නිශ්චිත නැත. කරුණාකර වැඩි ආලෝකයක් සහිත පැහැදිලි බඩඉරිඟු පත්‍රයක රූපයක් නැවත upload කරන්න.';
        cautionSinhala = null;
        buttonLabel = 'නැවත උත්සාහ කරන්න';
        shouldShowBackButton = false;
        break;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(sheetContext).size.height * 0.85,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE0E0E0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    titleText,
                    style: GoogleFonts.poppins(
                      fontSize: 22,
                      height: 1.35,
                      color: accentColor,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    popupBodySinhala,
                    style: GoogleFonts.notoSansSinhala(
                      fontSize: 15,
                      height: 1.65,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (cautionSinhala != null) ...[
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.amber.withOpacity(0.45),
                          width: 1.2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFC58A00),
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'අමතර සැලකිල්ල',
                                style: GoogleFonts.notoSansSinhala(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFFC58A00),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            cautionSinhala,
                            style: GoogleFonts.notoSansSinhala(
                              fontSize: 14,
                              height: 1.6,
                              color: Colors.black87,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      if (shouldShowBackButton) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.of(sheetContext).pop(),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.black54,
                              side: const BorderSide(
                                color: Color(0xFFDDD8D8),
                                width: 1.2,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              'ආපසු',
                              style: GoogleFonts.notoSansSinhala(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                      ],
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(sheetContext).pop();

                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!mounted) return;
                              _handlePopupMainAction(result);
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 2,
                          ),
                          child: Text(
                            buttonLabel,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.notoSansSinhala(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _handlePopupMainAction(Map<String, dynamic> result) {
    var type = _readString(result, ['final_diagnosis_type']) ?? 'uncertain';
    final finalPrediction = _readString(result, ['final_prediction']);

    if (finalPrediction == 'Healthy') {
      type = 'healthy';
    }

    if (type == 'nutrient_deficiency') {
      final nutritionResult = _buildNutritionResultForRedirect(result);

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => NutrientPredictionPage(
            imageFile: _selectedImage,
            precomputedResult: nutritionResult,
            skipApiCall: true,
            showAutoResultSheet: true,
          ),
        ),
      );
      return;
    }

    if (type == 'disease') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              CornDiseaseDetectionScreen(initialImageFile: _selectedImage),
        ),
      );
      return;
    }

    _clearFeedback();
  }

  void _clearFeedback() {
    setState(() {
      _errorMessage = null;
    });
  }

  String _friendlyErrorMessage(Object error) {
    final raw = error.toString();

    if (raw.contains('SocketException') ||
        raw.contains('Failed host lookup') ||
        raw.toLowerCase().contains('connection refused')) {
      return 'Backend server එකට සම්බන්ධ වීමට නොහැකි විය. Internet connection එක සහ server URL එක පරීක්ෂා කරන්න.';
    }

    if (raw.contains('503') ||
        raw.toLowerCase().contains('service unavailable')) {
      return 'Backend service එක දැනට ලබාගත නොහැක. කරුණාකර ටික වේලාවකින් නැවත උත්සාහ කරන්න.';
    }

    if (raw.contains('TimeoutException') ||
        raw.toLowerCase().contains('timeout')) {
      return 'Request timed out. The server may be waking up, so please try again.';
    }

    return 'විශ්ලේෂණය අසාර්ථක විය. කරුණාකර පැහැදිලි බඩඉරිඟු පත්‍ර රූපයක් නැවත upload කරන්න.';
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
                    title: loc.translate('leaf_diagnosis_warning'),
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
                if (!_isAnalyzing && _errorMessage == null) ...[
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
                  style: GoogleFonts.notoSansSinhala(
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
                      style: GoogleFonts.notoSansSinhala(
                        fontWeight: FontWeight.w700,
                      ),
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
