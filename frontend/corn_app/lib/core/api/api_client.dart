import 'dart:convert';
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

  // Later POST for image upload / prediction.
}
