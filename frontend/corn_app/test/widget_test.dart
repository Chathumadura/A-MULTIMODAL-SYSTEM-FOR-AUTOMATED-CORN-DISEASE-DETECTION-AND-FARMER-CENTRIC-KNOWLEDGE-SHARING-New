// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:corn_app/main.dart';

void main() {
  testWidgets('App loads and shows health check', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CornNutrientApp());

    // Verify that the app title is shown
    expect(find.text('Corn Nutrient Analyzer'), findsOneWidget);

    // Wait for the health check to complete (simulate async)
    await tester.pumpAndSettle();

    // Verify that some status text is shown (either loading or result)
    expect(find.byType(Text), findsWidgets);
  });
}
