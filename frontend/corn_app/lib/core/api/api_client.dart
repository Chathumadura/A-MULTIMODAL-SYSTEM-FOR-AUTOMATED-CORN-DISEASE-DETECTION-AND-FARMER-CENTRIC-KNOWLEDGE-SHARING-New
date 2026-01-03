// lib/core/api/api_client.dart
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../config/env.dart';

class ApiClient {
  final String _baseUrl = Env.baseUrl;

  Future<Map<String, dynamic>> uploadImageForPrediction(File imageFile) async {
    try {
      final uri = Uri.parse('$_baseUrl/predict');

      final request = http.MultipartRequest('POST', uri)
        ..files.add(await http.MultipartFile.fromPath('file', imageFile.path));

      // Increase timeout for model loading and processing
      final streamed = await request.send().timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          throw Exception('Connection timeout - Please check if backend is running');
        },
      );
      
      final response = await http.Response.fromStream(
        streamed,
      ).timeout(
        const Duration(seconds: 120),
        onTimeout: () {
          throw Exception('Response timeout - Model processing took too long');
        },
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception(
          'Prediction failed: ${response.statusCode} ${response.body}',
        );
      }
    } on SocketException {
      throw Exception('Network error - Please check your connection and backend URL');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Unexpected error: $e');
    }
  }
}
