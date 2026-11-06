// Some Android phones keep reporting the keyboard as open after it closes.
// The main tabs must not shrink because of that (it left a blank area on Home).
import 'package:moneyentri/app/nav.dart';
import 'package:moneyentri/app/shell.dart';
import 'package:moneyentri/core/theme.dart';
import 'package:moneyentri/data/store.dart';
import 'package:moneyentri/domain/demo.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (tab, name) in [(0, 'Home'), (1, 'History'), (2, 'Insights'), (3, 'Payments')]) {
    testWidgets('$name keeps its full height when the phone reports a keyboard', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final store = AppStore()..replaceData(buildDemoData());
      final nav = TabNav()..go(tab);

      Future<double> viewportHeight(double keyboard) async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [ChangeNotifierProvider.value(value: store), ChangeNotifierProvider.value(value: nav)],
            child: MaterialApp(
              theme: buildTheme(AppColors.light),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(viewInsets: EdgeInsets.only(bottom: keyboard)),
                child: child!,
              ),
              home: const Shell(),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 800));
        final scrollables = find.byType(Scrollable).hitTestable();
        return tester.getSize(scrollables.first).height;
      }

      final normal = await viewportHeight(0);
      final ghostKeyboard = await viewportHeight(330);
      expect(ghostKeyboard, normal, reason: '$name shrank by ${normal - ghostKeyboard}px');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
