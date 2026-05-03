import 'package:coathematchmaker/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('App starts on auth flow', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const CoaMatchmakerApp());
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Login'), findsOneWidget);
  });
}
