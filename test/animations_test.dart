import 'package:fintrack/core/theme.dart';
import 'package:fintrack/widgets/animations.dart';
import 'package:fintrack/widgets/ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) => MaterialApp(theme: buildTheme(AppColors.light), home: Scaffold(body: Center(child: child)));

void main() {
  testWidgets('amount field: typing updates the value, a second "." is rejected', (tester) async {
    var value = '';
    await tester.pumpWidget(_wrap(StatefulBuilder(
      builder: (context, setState) => AmountInput(value: value, onChanged: (v) => setState(() => value = v), symbol: '₹'),
    )));
    await tester.enterText(find.byType(TextField), '250.5');
    await tester.pump();
    expect(value, '250.5');
    await tester.enterText(find.byType(TextField), '250.5.');
    await tester.pumpAndSettle();
    expect(value, '250.5');
    await tester.enterText(find.byType(TextField), '250.555');
    await tester.pumpAndSettle();
    expect(value, '250.5', reason: 'at most 2 decimals');
  });

  testWidgets('wallet coins animate and clean up without errors', (tester) async {
    Widget wallet(double a, bool income) => _wrap(WalletCoins(amount: a, income: income, color: Colors.red));
    await tester.pumpWidget(wallet(0, false));
    for (final a in [2.0, 25.0, 250.0]) {
      await tester.pumpWidget(wallet(a, false));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpWidget(wallet(25, true)); // backspace
    await tester.pumpWidget(wallet(2500, true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('success animation shows the message and closes itself', (tester) async {
    await tester.pumpWidget(_wrap(Builder(
      builder: (context) => TextButton(
        onPressed: () => showSuccessAnimation(context, title: 'Expense added', subtitle: '-₹250', color: Colors.red),
        child: const Text('go'),
      ),
    )));
    await tester.tap(find.text('go'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('Expense added'), findsOneWidget);
    expect(find.text('-₹250'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.text('Expense added'), findsNothing);
  });

  testWidgets('a coin typed after a pause starts moving straight away (no freeze)', (tester) async {
    Widget wallet(double a) => _wrap(WalletCoins(amount: a, income: false, color: Colors.red));
    final coin = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_CoinFace');
    double coinY() => tester.getCenter(coin).dy;

    await tester.pumpWidget(wallet(0));
    await tester.pumpWidget(wallet(2));
    await tester.pumpAndSettle(); // first coin finishes, the ticker stops
    expect(coin, findsNothing);

    await tester.pump(const Duration(seconds: 2)); // the pause
    await tester.pumpWidget(wallet(25));
    await tester.pump(const Duration(milliseconds: 16));
    final y0 = coinY();
    await tester.pump(const Duration(milliseconds: 150));
    expect(coinY(), lessThan(y0 - 10), reason: 'the coin should already be rising');
    await tester.pumpAndSettle();
    expect(coin, findsNothing, reason: 'the coin is removed when its flight ends');
  });

  testWidgets('coins stay inside the wallet area', (tester) async {
    for (final income in [false, true]) {
      await tester.pumpWidget(_wrap(WalletCoins(amount: 0, income: income, color: Colors.red)));
      await tester.pumpWidget(_wrap(WalletCoins(amount: 5, income: income, color: Colors.red)));
      final area = tester.getRect(find.byType(WalletCoins));
      final coin = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_CoinFace');
      for (var i = 0; i < 12; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        if (coin.evaluate().isEmpty) break;
        final r = tester.getRect(coin);
        expect(r.top, greaterThanOrEqualTo(area.top - 0.5));
        expect(r.bottom, lessThanOrEqualTo(area.bottom + 0.5));
      }
      await tester.pumpAndSettle();
    }
  });

  testWidgets('fast typing never shows more than 5 coins at once', (tester) async {
    await tester.pumpWidget(_wrap(WalletCoins(amount: 0, income: false, color: Colors.red)));
    for (var i = 1; i <= 12; i++) {
      await tester.pumpWidget(_wrap(WalletCoins(amount: i * 10, income: false, color: Colors.red)));
      await tester.pump(const Duration(milliseconds: 10));
    }
    expect(find.byWidgetPredicate((w) => w.runtimeType.toString() == '_CoinFace').evaluate().length, lessThanOrEqualTo(5));
    await tester.pumpAndSettle();
  });

  group('liquid jar', () {
    Widget jar(double a, {bool reduce = false}) => MaterialApp(
      theme: buildTheme(AppColors.light),
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduce),
        child: Scaffold(body: Center(child: AmountJar(amount: a, color: Colors.red, symbol: '₹'))),
      ),
    );
    dynamic painter(WidgetTester t) =>
        t.widget<CustomPaint>(find.descendant(of: find.byType(AmountJar), matching: find.byType(CustomPaint))).painter;

    testWidgets('fills higher as the amount grows, and lower when it shrinks', (tester) async {
      await tester.pumpWidget(jar(0));
      final empty = painter(tester).level as double;
      await tester.pumpWidget(jar(500));
      await tester.pump(const Duration(milliseconds: 800));
      final mid = painter(tester).level as double;
      await tester.pumpWidget(jar(250000));
      await tester.pump(const Duration(milliseconds: 800));
      final full = painter(tester).level as double;
      await tester.pumpWidget(jar(5));
      await tester.pump(const Duration(milliseconds: 800));
      final low = painter(tester).level as double;
      expect(empty, lessThan(mid));
      expect(mid, lessThan(full));
      expect(full, lessThanOrEqualTo(0.95));
      expect(low, lessThan(mid));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('each keystroke adds bubbles that rise and then disappear', (tester) async {
      await tester.pumpWidget(jar(0));
      await tester.pumpWidget(jar(2));
      await tester.pump(const Duration(milliseconds: 200));
      expect((painter(tester).bubbles as List).length, greaterThan(0));
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 16));
      expect((painter(tester).bubbles as List), isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('a keystroke after a long pause animates straight away', (tester) async {
      await tester.pumpWidget(jar(0));
      await tester.pumpWidget(jar(2));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpWidget(jar(25));
      await tester.pump(const Duration(milliseconds: 100));
      expect((painter(tester).bubbles as List).length, greaterThan(0));
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('reduced motion: no waves or bubbles, level jumps straight to the value', (tester) async {
      await tester.pumpWidget(jar(0, reduce: true));
      await tester.pumpWidget(jar(5000, reduce: true));
      await tester.pump();
      expect((painter(tester).bubbles as List), isEmpty);
      expect(painter(tester).phase, 0);
      await tester.pumpAndSettle(); // nothing keeps animating
    });
  });
}
