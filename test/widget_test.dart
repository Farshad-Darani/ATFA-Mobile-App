// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';

import 'package:atfa/main.dart';

void main() {
  testWidgets('ATFA app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ATFAApp());

    // Verify that the app has the bottom navigation.
    expect(find.text('Connect'), findsOneWidget);
    expect(find.text('Live Data'), findsOneWidget);
    expect(find.text('More'), findsOneWidget);

    // Verify that the Connect page is initially shown.
    expect(find.text('Connect to OBD-II'), findsOneWidget);
  });
}
