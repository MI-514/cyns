import 'package:flutter_test/flutter_test.dart';
import 'package:cyns/main.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CynApp());

    // Verify CynApp inflates without exception
    expect(find.byType(CynApp), findsOneWidget);
  });
}
