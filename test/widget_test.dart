import 'package:flutter_test/flutter_test.dart';
import 'package:saengil_alrim/main.dart';

void main() {
  testWidgets('App renders successfully smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that our app header is shown
    expect(find.text('생일알림'), findsOneWidget);
  });
}
