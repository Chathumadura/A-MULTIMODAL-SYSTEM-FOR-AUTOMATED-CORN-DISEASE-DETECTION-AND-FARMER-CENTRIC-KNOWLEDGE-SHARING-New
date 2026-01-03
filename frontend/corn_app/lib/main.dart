import 'package:flutter/material.dart';
import 'core/api/api_client.dart';

void main() {
  runApp(const CornNutrientApp());
}

class CornNutrientApp extends StatelessWidget {
  const CornNutrientApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Corn Nutrient Analyzer',
      theme: ThemeData(primarySwatch: Colors.green, useMaterial3: true),
      home: const HealthCheckPage(),
    );
  }
}

class HealthCheckPage extends StatefulWidget {
  const HealthCheckPage({super.key});

  @override
  State<HealthCheckPage> createState() => _HealthCheckPageState();
}

class _HealthCheckPageState extends State<HealthCheckPage> {
  final ApiClient _apiClient = ApiClient();
  String _statusText = 'Checking backend...';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkHealth();
  }

  Future<void> _checkHealth() async {
    try {
      final data = await _apiClient.get('/health');
      setState(() {
        _statusText = 'Backend status: ${data['status']}';
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _statusText = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Corn Nutrient Analyzer')),
      body: Center(
        child: _isLoading
            ? const CircularProgressIndicator()
            : Text(_statusText, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}
