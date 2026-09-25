import 'package:flutter_test/flutter_test.dart';

import 'package:mobile/app/smriti_app.dart';

void main() {
  testWidgets('SMRITI app loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const SmritiApp());

    expect(find.text('SMRITI'), findsOneWidget);
    expect(find.text('Your Name'), findsOneWidget);
    expect(find.text('My Family'), findsOneWidget);
    expect(find.text('My Memories'), findsOneWidget);
    expect(find.text("Let's Play"), findsOneWidget);
  });
}