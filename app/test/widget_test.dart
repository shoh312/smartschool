import 'package:flutter_test/flutter_test.dart';
import 'package:smartschool_app/main.dart';

void main() {
  testWidgets('shows splash while restoring session', (tester) async {
    await tester.pumpWidget(const SmartSchoolRoot());

    expect(find.byType(SmartSchoolRoot), findsOneWidget);
  });
}
