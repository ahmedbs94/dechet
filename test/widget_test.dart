// Basic Flutter widget test for EcoRewind app.

import 'package:flutter_test/flutter_test.dart';
import 'package:tri_dechet/main.dart';

void main() {
  testWidgets('App launches successfully', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const EcoRewindApp());

    // Verify that the app builds without crashing.
    expect(find.byType(EcoRewindApp), findsOneWidget);
  });
}
