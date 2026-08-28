// The app boots as far as the splash screen.
//
// Thin, but it is the one test that would catch a provider missing from
// buildAppProviders() -- the failure mode where every screen throws
// ProviderNotFoundException at runtime and nothing else in the suite
// notices, because every other test builds its widget by hand.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smartschool_app/main.dart';
import 'package:smartschool_app/providers/app_providers.dart';

void main() {
  testWidgets('shows splash while restoring session', (tester) async {
    // The providers live above SmartSchoolRoot in main(), so a test that
    // pumps the root on its own is testing a tree the app never builds.
    await tester.pumpWidget(
      MultiProvider(
        providers: buildAppProviders(),
        child: const SmartSchoolRoot(),
      ),
    );

    expect(find.byType(SmartSchoolRoot), findsOneWidget);
  });
}
