import 'dart:io';
import 'package:http/http.dart' as http;

class ApiService {
  static const String apiUrl = "http://10.0.2.2:8000/predict";

  static Future<String> predict(File image) async {
    var request = http.MultipartRequest(
      'POST',
      Uri.parse(apiUrl),
    );

    request.files.add(
      await http.MultipartFile.fromPath('file', image.path),
    );

    var response = await request.send();

    if (response.statusCode == 200) {
      return await response.stream.bytesToString();
    } else {
      throw Exception("Prediction failed");
    }
  }
}
