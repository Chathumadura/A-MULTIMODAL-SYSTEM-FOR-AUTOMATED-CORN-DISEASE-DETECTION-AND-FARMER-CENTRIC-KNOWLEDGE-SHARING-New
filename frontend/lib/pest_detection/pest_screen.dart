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

  // ---------------- PICK IMAGE ----------------
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

  // ---------------- PREDICT ----------------
  Future<void> predictPest() async {
    if (_image == null) return;

    setState(() => _loading = true);

    try {
      final response = await ApiService.predict(_image!);
      final data = json.decode(response);

      if (data["prediction"] == "not_corn_leaf") {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text("Invalid Image"),
            content: Text(data["message"]),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("OK"),
              )
            ],
          ),
        );
      } else {
        setState(() {
          _result =
              "Pest: ${data['prediction']}\nConfidence: ${data['confidence']}%";
        });
      }
    } catch (e) {
      setState(() {
        _result = "Error: $e";
      });
    }

    setState(() => _loading = false);
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: const Text("Corn Pest Detection"),
        centerTitle: true,
        backgroundColor: Colors.green.shade700,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // -------- IMAGE CARD --------
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                height: 220,
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                child: _image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(_image!, fit: BoxFit.cover),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.image, size: 80, color: Colors.grey),
                          SizedBox(height: 10),
                          Text("No image selected",
                              style: TextStyle(color: Colors.grey)),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 20),

            // -------- BUTTONS --------
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.photo),
                  label: const Text("Pick Image"),
                  onPressed: pickImage,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),

                ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text("Detect"),
                  onPressed: predictPest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // -------- RESULT CARD --------
            Card(
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: _loading
                    ? const CircularProgressIndicator()
                    : Column(
                        children: [
                          const Text(
                            "Detection Result",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _result,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: _result.contains("Pest")
                                  ? Colors.green.shade700
                                  : Colors.red.shade700,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
