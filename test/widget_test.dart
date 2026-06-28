import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:swasthya_tap/main.dart';
import 'package:swasthya_tap/providers/swasthya_tap_provider.dart';

void main() {
  testWidgets('Swasthya Tap smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => SwasthyaTapProvider(),
        child: const SwasthyaTapApp(),
      ),
    );

    // Verify that our main title is found.
    expect(find.text('SwasthyaTap'), findsWidgets);

    // Let the timer fire and transition to next screen
    await tester.pump(const Duration(seconds: 4));

    // Clean up the widget tree and allow infinite animation timers to dispose cleanly
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
