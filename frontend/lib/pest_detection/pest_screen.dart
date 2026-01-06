import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'api_service.dart';

class PestDetectionScreen extends StatefulWidget {
  const PestDetectionScreen({super.key});

  @override
  State<PestDetectionScreen> createState() => _PestDetectionScreenState();
}

class _PestDetectionScreenState extends State<PestDetectionScreen> {
  File? _image;
  String _result = "No result yet";
  bool _loading = false;

  final ImagePicker _picker = ImagePicker();

  Future<void> pickImage() async {
    final XFile? image =
        await _picker.pickImage(source: ImageSource.gallery);

    if (image != null) {
      setState(() {
        _image = File(image.path);
        _result = "Image selected";
      });
    }
  }

  Future<void> predictPest() async {
    if (_image == null) return;

    setState(() => _loading = true);

    try {
      final response = await ApiService.predict(_image!);
      final data = json.decode(response);

      setState(() {
        _result =
            "Pest: ${data['prediction']}\nConfidence: ${data['confidence']}%";
      });
    } catch (e) {
      setState(() {
        _result = "Error: $e";
      });
    }

    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pest Detection")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _image != null
                ? Image.file(_image!, height: 200)
                : const Icon(Icons.image, size: 150),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: pickImage,
              child: const Text("Pick Image"),
            ),

            const SizedBox(height: 10),

            ElevatedButton(
              onPressed: predictPest,
              child: const Text("Detect Pest"),
            ),

            const SizedBox(height: 20),

            _loading
                ? const CircularProgressIndicator()
                : Text(
                    _result,
                    style: const TextStyle(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
          ],
        ),
      ),
    );
  }
}
