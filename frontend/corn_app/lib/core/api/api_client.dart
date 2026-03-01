import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/env.dart';

class ApiClient {
  final String _baseUrl = Env.baseUrl;

  Future<Map<String, dynamic>> get(String path) async {
    final uri = Uri.parse('$_baseUrl$path');
    final response = await http.get(uri);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('GET $path failed: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> uploadImageForPrediction(File imageFile) async {
    final uri = Uri.parse('$_baseUrl/nutrition/predict');
    var request = http.MultipartRequest('POST', uri);

    request.files.add(
      await http.MultipartFile.fromPath('file', imageFile.path),
    );

    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception(
        'Upload failed: ${response.statusCode} - ${response.body}',
      );
    }
  }
}
