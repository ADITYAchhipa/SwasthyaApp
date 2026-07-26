import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:swasthya_tap/models/models.dart';
import 'package:swasthya_tap/providers/swasthya_tap_provider.dart';
import 'package:swasthya_tap/screens/hospital_portal/nfc_writer_screen.dart';

void main() {
  testWidgets('NfcWriterScreen renders step 2 profile form and allows interaction without crashing',
      (WidgetTester tester) async {
    final provider = SwasthyaTapProvider();
    final citizen = MedicalProfile(
      id: 'x7k9m2',
      fullName: 'Rajesh Kumar',
      bloodGroup: 'O+',
      age: 35,
      address: '123 Main St, Bangalore',
      allergies: 'Penicillin',
      medications: 'Metformin 500mg daily',
      emergencyContacts: [
        EmergencyContact(name: 'Suresh Kumar', relation: 'Brother', phone: '9900112233')
      ],
      specialInstructions: 'Asthmatic',
      insuranceCompany: 'LIC',
      insurancePolicyNumber: 'POL12345',
      chronicConditions: 'Hypertension',
      lifeCredits: 100,
      isBloodDonor: false,
      donorRadiusKm: 5.0,
      homeLat: 12.9716,
      homeLng: 77.5946,
      phoneNumber: '9900112233',
      email: 'rajesh.kumar@gmail.com',
      isDnr: false,
      medicalReports: [],
      receipts: [],
      prescriptions: [],
    );

    // Build the widget tree
    await tester.pumpWidget(
      ChangeNotifierProvider<SwasthyaTapProvider>.value(
        value: provider,
        child: const MaterialApp(
          home: NfcWriterScreen(
            prefillSwasthyaId: 'x7k9m2',
          ),
        ),
      ),
    );

    // Get the state of NfcWriterScreen and trigger Step 2 transition
    final stateFinder = find.byType(NfcWriterScreen);
    expect(stateFinder, findsOneWidget);

    final dynamic state = tester.state(stateFinder);
    state.debugTransitionToStep2(citizen);

    // Rebuild the widget tree
    await tester.pump();

    // Verify profile details card header
    expect(find.text('Rajesh Kumar'), findsWidgets);
    expect(find.text('STUID: ST91-XXXX-XXXX-X7K9M2'), findsOneWidget);

    // Find the Allergies section tile, ensure visible, and tap it to expand
    final allergiesTile = find.text('3. Allergies');
    expect(allergiesTile, findsOneWidget);
    await tester.ensureVisible(allergiesTile);
    await tester.tap(allergiesTile);
    await tester.pump();

    // Now Penicillin should be visible and found in the TextFormField
    expect(find.text('Penicillin'), findsOneWidget);

    // Find the Medications section tile, ensure visible, and tap it to expand
    final medsTile = find.text('4. Current Medications');
    expect(medsTile, findsOneWidget);
    await tester.ensureVisible(medsTile);
    await tester.tap(medsTile);
    await tester.pump();

    // Now Metformin 500mg daily should be visible and found
    expect(find.text('Metformin 500mg daily'), findsOneWidget);

    // Clean up
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}
