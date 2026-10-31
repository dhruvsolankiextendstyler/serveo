import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/utils/theme_provider.dart';
import 'package:frontend/widgets/breakbite_textbox.dart';
import 'package:frontend/widgets/serveo_glass_container.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Global UI Refinement — AppTheme Design Tokens & Input Styling', () {
    test('AppTheme defines required rounded radii tokens', () {
      expect(AppTheme.radiusInput, 14.0);
      expect(AppTheme.radiusDropdown, 14.0);
      expect(AppTheme.radiusCard, 16.0);
      expect(AppTheme.radiusContainer, 18.0);
      expect(AppTheme.radiusDialog, 22.0);
      expect(AppTheme.radiusBottomSheet, 24.0);
    });

    test('Dark theme input decoration has softer rounded borders and filled surface', () {
      final inputTheme = AppTheme.darkTheme.inputDecorationTheme;
      expect(inputTheme.filled, isTrue);
      expect(inputTheme.fillColor, AppTheme.darkInputFill);
      expect(inputTheme.border, isA<OutlineInputBorder>());

      final border = inputTheme.border as OutlineInputBorder;
      expect(border.borderRadius, BorderRadius.circular(14.0));
      expect(border.borderSide.color, AppTheme.darkInputBorder);

      final focusedBorder = inputTheme.focusedBorder as OutlineInputBorder;
      expect(focusedBorder.borderRadius, BorderRadius.circular(14.0));
      expect(focusedBorder.borderSide.color, AppTheme.darkInputFocusedBorder);
    });

    test('Light theme input decoration has softer rounded borders and filled surface', () {
      final inputTheme = AppTheme.lightTheme.inputDecorationTheme;
      expect(inputTheme.filled, isTrue);
      expect(inputTheme.fillColor, AppTheme.lightInputFill);
      expect(inputTheme.border, isA<OutlineInputBorder>());

      final border = inputTheme.border as OutlineInputBorder;
      expect(border.borderRadius, BorderRadius.circular(14.0));
      expect(border.borderSide.color, AppTheme.lightInputBorder);

      final focusedBorder = inputTheme.focusedBorder as OutlineInputBorder;
      expect(focusedBorder.borderRadius, BorderRadius.circular(14.0));
      expect(focusedBorder.borderSide.color, AppTheme.lightInputFocusedBorder);
    });

    test('Dialog theme has softer rounded corners (22px)', () {
      final darkDialog = AppTheme.darkTheme.dialogTheme;
      expect(darkDialog.shape, isA<RoundedRectangleBorder>());
      final darkShape = darkDialog.shape as RoundedRectangleBorder;
      expect(darkShape.borderRadius, BorderRadius.circular(22.0));

      final lightDialog = AppTheme.lightTheme.dialogTheme;
      expect(lightDialog.shape, isA<RoundedRectangleBorder>());
      final lightShape = lightDialog.shape as RoundedRectangleBorder;
      expect(lightShape.borderRadius, BorderRadius.circular(22.0));
    });

    test('BottomSheet theme has softer top rounded corners (24px)', () {
      final darkSheet = AppTheme.darkTheme.bottomSheetTheme;
      expect(darkSheet.shape, isA<RoundedRectangleBorder>());
      final darkShape = darkSheet.shape as RoundedRectangleBorder;
      expect(darkShape.borderRadius, const BorderRadius.vertical(top: Radius.circular(24.0)));

      final lightSheet = AppTheme.lightTheme.bottomSheetTheme;
      expect(lightSheet.shape, isA<RoundedRectangleBorder>());
      final lightShape = lightSheet.shape as RoundedRectangleBorder;
      expect(lightShape.borderRadius, const BorderRadius.vertical(top: Radius.circular(24.0)));
    });
  });

  group('Global UI Refinement — ServeoGlassContainer & Backdrop Blur', () {
    testWidgets('ServeoGlassContainer wraps content with BackdropFilter and soft borders', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const Scaffold(
            body: ServeoGlassContainer(
              blur: 14.0,
              padding: EdgeInsets.all(16),
              child: Text("Glassmorphism Content"),
            ),
          ),
        ),
      );

      // Verify widget hierarchy
      expect(find.byType(ServeoGlassContainer), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(ClipRRect), findsOneWidget);
      expect(find.text("Glassmorphism Content"), findsOneWidget);

      final backdropFilter = tester.widget<BackdropFilter>(find.byType(BackdropFilter));
      expect(backdropFilter.filter, isNotNull);
    });

    testWidgets('showGlassDialog displays modal with soft blur and rounded dialog', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showGlassDialog(
                    context: ctx,
                    builder: (dCtx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.radiusDialog)),
                      title: const Text("Glass Dialog"),
                      content: const Text("Dialog body content"),
                    ),
                  );
                },
                child: const Text("Open Dialog"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open Dialog"));
      await tester.pumpAndSettle();

      expect(find.text("Glass Dialog"), findsOneWidget);
      expect(find.text("Dialog body content"), findsOneWidget);
      expect(find.byType(BackdropFilter), findsWidgets);
    });

    testWidgets('showGlassBottomSheet displays modal bottom sheet with soft blur', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Builder(
            builder: (ctx) => Scaffold(
              body: ElevatedButton(
                onPressed: () {
                  showGlassBottomSheet(
                    context: ctx,
                    builder: (sCtx) => const SizedBox(
                      height: 200,
                      child: Center(child: Text("Glass Bottom Sheet Content")),
                    ),
                  );
                },
                child: const Text("Open Sheet"),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text("Open Sheet"));
      await tester.pumpAndSettle();

      expect(find.text("Glass Bottom Sheet Content"), findsOneWidget);
      expect(find.byType(BackdropFilter), findsWidgets);
    });
  });

  group('Global UI Refinement — ServeoTextBox Component', () {
    testWidgets('Renders with soft input decoration and toggles obscure text', (tester) async {
      final controller = TextEditingController(text: "secret123");

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: ServeoTextBox(
                hint: "Enter Password",
                icon: Icons.lock_outline,
                obscure: true,
                cont: controller,
              ),
            ),
          ),
        ),
      );

      // Verify initial obscure state
      final editableTextFinder = find.byType(EditableText);
      expect(editableTextFinder, findsOneWidget);
      EditableText editableText = tester.widget<EditableText>(editableTextFinder);
      expect(editableText.obscureText, isTrue);

      // Find visibility toggle icon button and tap it
      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
      await tester.tap(find.byIcon(Icons.visibility_outlined));
      await tester.pumpAndSettle();

      // Verify text is now revealed
      editableText = tester.widget<EditableText>(editableTextFinder);
      expect(editableText.obscureText, isFalse);
      expect(find.byIcon(Icons.visibility_off_outlined), findsOneWidget);
    });
  });
}

