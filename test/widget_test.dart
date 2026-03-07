import 'package:flutter_test/flutter_test.dart';
import 'package:khotaa_app/main.dart';

void main() {
  testWidgets('App builds smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const KhotaaApp());
    expect(find.byType(KhotaaApp), findsOneWidget);
  });
}
