// Opens every screen on small phones (with normal and large text) and fails on
// any layout overflow, i.e. content that would be cut off on a real device.
import 'package:fintrack/app/nav.dart';
import 'package:fintrack/app/shell.dart';
import 'package:fintrack/core/theme.dart';
import 'package:fintrack/data/store.dart';
import 'package:fintrack/domain/demo.dart';
import 'package:fintrack/domain/schedule.dart';
import 'package:fintrack/screens/bill_detail_screen.dart';
import 'package:fintrack/screens/bill_form_screen.dart';
import 'package:fintrack/screens/budget_form_screen.dart';
import 'package:fintrack/screens/goal_detail_screen.dart';
import 'package:fintrack/screens/goal_form_screen.dart';
import 'package:fintrack/screens/loan_detail_screen.dart';
import 'package:fintrack/screens/loan_form_screen.dart';
import 'package:fintrack/screens/pay_screen.dart';
import 'package:fintrack/screens/privacy_screen.dart';
import 'package:fintrack/screens/profile_screen.dart';
import 'package:fintrack/screens/transaction_form_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _phones = {'320x568': Size(320, 568), '360x640': Size(360, 640)};
const _textScales = [1.0, 1.3];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  final demo = AppStore()..replaceData(buildDemoData());
  final loan = demo.loans.first;
  final bill = demo.bills.first;
  final goal = demo.goals.first;
  final tx = demo.transactions.first;
  final due = loanInstallments(loan, demo.payments).firstWhere((o) => o.status != OccStatus.paid).dueDate;

  // name → (sample data?, tab setup, screen)
  final screens = <String, (bool, void Function(TabNav), Widget)>{
    'home (empty)': (false, (n) => n.go(0), const Shell()),
    'home': (true, (n) => n.go(0), const Shell()),
    'history': (true, (n) => n.go(1), const Shell()),
    'history (empty)': (false, (n) => n.go(1), const Shell()),
    'insights analytics': (true, (n) => n.insights('analytics'), const Shell()),
    'insights budgets': (true, (n) => n.insights('budgets'), const Shell()),
    'insights goals': (true, (n) => n.insights('goals'), const Shell()),
    'payments calendar': (true, (n) => n.payments('calendar'), const Shell()),
    'payments loans': (true, (n) => n.payments('loans'), const Shell()),
    'payments bills': (true, (n) => n.payments('bills'), const Shell()),
    'profile': (true, (_) {}, const ProfileScreen()),
    'privacy policy': (true, (_) {}, const PrivacyScreen()),
    'add transaction': (true, (_) {}, const TransactionFormScreen()),
    'edit transaction': (true, (_) {}, TransactionFormScreen(id: tx.id)),
    'add loan': (true, (_) {}, const LoanFormScreen()),
    'edit loan': (true, (_) {}, LoanFormScreen(id: loan.id)),
    'loan detail': (true, (_) {}, LoanDetailScreen(id: loan.id)),
    'pay EMI': (true, (_) {}, PayScreen(kind: 'loan', refId: loan.id, dueDate: due)),
    'add bill': (true, (_) {}, const BillFormScreen()),
    'edit bill': (true, (_) {}, BillFormScreen(id: bill.id)),
    'bill detail': (true, (_) {}, BillDetailScreen(id: bill.id)),
    'add goal': (true, (_) {}, const GoalFormScreen()),
    'goal detail': (true, (_) {}, GoalDetailScreen(id: goal.id)),
    'budget form': (true, (_) {}, const BudgetFormScreen()),
  };

  for (final MapEntry(key: phone, value: size) in _phones.entries) {
    for (final scale in _textScales) {
      for (final MapEntry(key: name, value: (sample, tab, screen)) in screens.entries) {
        testWidgets('$name fits on $phone at ${(scale * 100).round()}% text', (tester) async {
          final errors = <String>[];
          final previous = FlutterError.onError;
          FlutterError.onError = (d) {
            final msg = d.exceptionAsString();
            // Only layout problems matter here (plugins aren't available in tests).
            if (msg.contains('overflow') || msg.contains('RenderFlex') || msg.contains('constraints')) {
              final where = RegExp(r'lib/[a-z_/]+\.dart:\d+').firstMatch(d.toString())?.group(0) ?? '?';
              errors.add('${msg.split('\n').first} @ $where');
            }
          };
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);

          final store = AppStore();
          if (sample) store.replaceData(buildDemoData());
          final nav = TabNav();
          tab(nav);
          await tester.pumpWidget(
            MultiProvider(
              providers: [ChangeNotifierProvider.value(value: store), ChangeNotifierProvider.value(value: nav)],
              child: MaterialApp(
                theme: buildTheme(AppColors.light),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: screen,
              ),
            ),
          );
          for (var i = 0; i < 10; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          // Scroll to the bottom so lower content is laid out and checked too.
          final scrollables = find.byType(Scrollable);
          if (scrollables.evaluate().isNotEmpty) {
            await tester.drag(scrollables.first, const Offset(0, -3000), warnIfMissed: false);
            for (var i = 0; i < 6; i++) {
              await tester.pump(const Duration(milliseconds: 100));
            }
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 2));
          FlutterError.onError = previous;
          expect(errors.toSet(), isEmpty, reason: '$name on $phone at ${scale}x text');
        });
      }
    }
  }
}
