import 'package:flutter/material.dart';

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
                // TODO: Navigate to disease detection
              },
              child: const Text('Detect Corn Disease'),
            ),

            const SizedBox(height: 15),

            ElevatedButton(
              onPressed: () {
                // TODO: Navigate to knowledge hub
              },
              child: const Text('Farmer Knowledge Hub'),
            ),
          ],
        ),
      ),
    );
  }
}
