import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/widgets/breakbite_textbox.dart';

void main() {
  testWidgets('ServeoTextBox displays hint and text correctly', (WidgetTester tester) async {
    final controller = TextEditingController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ServeoTextBox(
            hint: 'Email',
            icon: Icons.email,
            cont: controller,
          ),
        ),
      ),
    );

    expect(find.text('Email'), findsOneWidget);
    expect(find.byIcon(Icons.email), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'test@example.com');
    expect(controller.text, equals('test@example.com'));
  });
}
