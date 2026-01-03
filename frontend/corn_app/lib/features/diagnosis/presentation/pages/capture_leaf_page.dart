import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'nutrient_prediction_page.dart';

class CaptureLeafPage extends StatefulWidget {
  const CaptureLeafPage({super.key});

  @override
  State<CaptureLeafPage> createState() => _CaptureLeafPageState();
}

class _CaptureLeafPageState extends State<CaptureLeafPage> {
  final ImagePicker _picker = ImagePicker();
  File? _image;
  bool _isPicking = false;

  Future<void> _pick(ImageSource source) async {
    if (_isPicking) return;
    setState(() => _isPicking = true);
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked != null) {
        setState(() => _image = File(picked.path));
      }
    } finally {
      setState(() => _isPicking = false);
    }
  }

  void _goAnalyze() {
    if (_image == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NutrientPredictionPage(initialImagePath: _image!.path),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060912),
      appBar: AppBar(
        backgroundColor: const Color(0xFF060912),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text('Scan Leaf', style: TextStyle(color: Colors.white)),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0E172C), Color(0xFF0C3528)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    children: [
                      if (_image != null)
                        Positioned.fill(
                          child: Image.file(
                            _image!,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.photo_camera_back_outlined,
                                  size: 72, color: Colors.white.withOpacity(0.6)),
                              const SizedBox(height: 14),
                              Text(
                                'Capture a leaf photo',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.8),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Use camera or gallery to proceed',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (_isPicking)
                        Container(
                          color: Colors.black.withOpacity(0.5),
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF00D9A0),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isPicking ? null : () => _pick(ImageSource.gallery),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF00D9A0),
                      side: const BorderSide(color: Color(0xFF00D9A0)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.photo_library_outlined),
                    label: const Text('Gallery'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isPicking ? null : () => _pick(ImageSource.camera),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D9A0),
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('Camera'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (_image != null && !_isPicking) ? _goAnalyze : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D9A0),
                  disabledBackgroundColor: const Color(0xFF1E2433),
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward),
                label: const Text(
                  'Continue to Analysis',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
