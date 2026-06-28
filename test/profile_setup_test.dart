import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:swasthya_tap/models/models.dart';
import 'package:swasthya_tap/providers/swasthya_tap_provider.dart';
import 'package:swasthya_tap/screens/citizen_portal/profile_setup_screen.dart';

void main() {
  testWidgets('ProfileSetupScreen renders all form fields and saves profile',
      (WidgetTester tester) async {
    final provider = SwasthyaTapProvider();
    final citizen = MedicalProfile(
      id: 'test_id',
      fullName: 'John Doe',
      bloodGroup: 'O+',
      allergies: 'None',
      medications: 'None',
      emergencyContacts: [],
      specialInstructions: 'None',
      phoneNumber: '1234567890',
    );

    // Build the widget tree
    await tester.pumpWidget(
      ChangeNotifierProvider<SwasthyaTapProvider>.value(
        value: provider,
        child: MaterialApp(
          home: ProfileSetupScreen(citizen: citizen),
        ),
      ),
    );

    // Verify initial values are loaded
    expect(find.text('John Doe'), findsOneWidget);
    expect(find.text('1234567890'), findsOneWidget);

    // Enter values into fields
    await tester.enterText(find.widgetWithText(TextFormField, 'Full Name'), 'Test Citizen');
    await tester.enterText(find.widgetWithText(TextFormField, 'Age'), '30');
    await tester.enterText(find.widgetWithText(TextFormField, 'Address'), '123 Test Street, Bangalore');
    await tester.enterText(find.widgetWithText(TextFormField, 'Phone Number'), '9876543210');
    await tester.enterText(find.widgetWithText(TextFormField, 'Emergency Contact Name'), 'Emergency Contact');
    await tester.enterText(find.widgetWithText(TextFormField, 'Emergency Contact Phone'), '9999999999');

    await tester.pumpAndSettle();

    // Verify values entered
    expect(find.text('Test Citizen'), findsOneWidget);
    expect(find.text('30'), findsOneWidget);
    expect(find.text('123 Test Street, Bangalore'), findsOneWidget);
    expect(find.text('9876543210'), findsOneWidget);
    expect(find.text('Emergency Contact'), findsOneWidget);
    expect(find.text('9999999999'), findsOneWidget);

    // Find the Save & Continue button
    final saveButton = find.widgetWithText(ElevatedButton, 'Save & Continue');
    expect(saveButton, findsOneWidget);

    // Scroll to the button to make it visible in the viewport
    await tester.ensureVisible(saveButton);
    await tester.pumpAndSettle();

    // Tap Save & Continue
    await tester.tap(saveButton);
    await tester.pumpAndSettle();

    // Verify that the provider has updated profile in its state
    final updated = provider.profiles.firstWhere((p) => p.id == 'test_id');
    expect(updated.fullName, 'Test Citizen');
    expect(updated.age, 30);
    expect(updated.address, '123 Test Street, Bangalore');
    expect(updated.phoneNumber, '9876543210');
    expect(updated.emergencyContacts[0].name, 'Emergency Contact');
    expect(updated.emergencyContacts[0].phone, '9999999999');
  });
}
