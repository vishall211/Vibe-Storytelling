import 'package:flutter_test/flutter_test.dart';
import 'package:vibestory/main.dart';

void main() {
  testWidgets('shows auth screen on first launch', (WidgetTester tester) async {
    await tester.pumpWidget(const VibeStoryApp());

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
  });
}
