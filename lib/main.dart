import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';

import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const CornApp());
}

class CornApp extends StatelessWidget {
  const CornApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Corn Disease Detection',
      debugShowCheckedModeBanner: false,
      home: const HomeScreen(),
    );
  }
}

// ---------------- HOME SCREEN ----------------

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Corn Disease Detection'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'Welcome to Corn Disease Detection App',
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 30),

            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DetectDiseaseScreen(),
                  ),
                );
              },
              child: const Text('Detect Corn Disease'),
            ),

            const SizedBox(height: 15),

            ElevatedButton(
              onPressed: () {
                // Farmer knowledge hub – future work
              },
              child: const Text('Farmer Knowledge Hub'),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- DETECT DISEASE SCREEN ----------------

class DetectDiseaseScreen extends StatefulWidget {
  const DetectDiseaseScreen({super.key});

  @override
  State<DetectDiseaseScreen> createState() => _DetectDiseaseScreenState();
}

class _DetectDiseaseScreenState extends State<DetectDiseaseScreen> {
  File? _selectedImage;
  String? _diseaseResult;
  double? _confidence;
  bool _isLoading = false;

  final ImagePicker _picker = ImagePicker();

  // Pick from gallery (may not work on emulator – OK)
  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _selectedImage = File(image.path);
        _diseaseResult = null;
        _confidence = null;
      });
    }
  }

  // Load bundled test image (PROTOTYPE MODE)
  Future<void> _loadTestImage() async {
    final bytes = await DefaultAssetBundle.of(
      context,
    ).load('assets/images/corn_leaf_test.jpg');

    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/corn_leaf_test.jpg');

    await file.writeAsBytes(bytes.buffer.asUint8List());

    setState(() {
      _selectedImage = file;
      _diseaseResult = null;
      _confidence = null;
    });
  }

  // 🔗 REAL BACKEND INTEGRATION
  Future<void> _detectDisease() async {
    setState(() {
      _isLoading = true;
      _diseaseResult = null;
      _confidence = null;
    });

    try {
      final response = await http.post(
        Uri.parse('http://10.0.2.2:8000/predict'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        setState(() {
          _diseaseResult = data['disease'];
          _confidence = data['confidence'];
        });
      } else {
        throw Exception('Prediction failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detect Corn Disease')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton(
              onPressed: _pickImage,
              child: const Text('Select Corn Leaf Image'),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: _loadTestImage,
              child: const Text('Load Test Image (Prototype)'),
            ),

            const SizedBox(height: 20),

            _selectedImage != null
                ? Image.file(_selectedImage!, height: 250)
                : const Text('No image selected', textAlign: TextAlign.center),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: (_selectedImage == null || _isLoading)
                  ? null
                  : _detectDisease,
              child: _isLoading
                  ? const CircularProgressIndicator()
                  : const Text('Detect Disease'),
            ),

            const SizedBox(height: 20),

            if (_diseaseResult != null && _confidence != null)
              Column(
                children: [
                  Text(
                    'Disease: $_diseaseResult',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Confidence: ${(_confidence! * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 16),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
