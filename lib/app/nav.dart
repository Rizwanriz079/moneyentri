import 'package:flutter/material.dart';

import '../screens/bill_detail_screen.dart';
import '../screens/bill_form_screen.dart';
import '../screens/budget_form_screen.dart';
import '../screens/goal_detail_screen.dart';
import '../screens/goal_form_screen.dart';
import '../screens/loan_detail_screen.dart';
import '../screens/loan_form_screen.dart';
import '../screens/pay_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/transaction_form_screen.dart';

/// Root navigator, used to open screens from notification taps.
final navigatorKey = GlobalKey<NavigatorState>();

/// Which bottom tab and which sub-tab of Insights / Payments is showing.
/// Kept in one place so any screen can jump to e.g. "Insights → Budgets".
class TabNav extends ChangeNotifier {
  int tab = 0;
  String insightsTab = 'analytics';
  String paymentsTab = 'calendar';

  void go(int index) {
    tab = index;
    notifyListeners();
  }

  void insights(String sub) {
    insightsTab = sub;
    tab = 2;
    notifyListeners();
  }

  void payments(String sub) {
    paymentsTab = sub;
    tab = 3;
    notifyListeners();
  }
}

/// Typed entry points for every pushed screen. Forms open as full-screen dialogs.
class Routes {
  static Future<T?> _push<T>(BuildContext context, Widget page, {bool modal = false}) =>
      Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => page, fullscreenDialog: modal));

  static Future<void> transactionForm(BuildContext c, {String? id}) => _push(c, TransactionFormScreen(id: id), modal: true);
  static Future<void> pay(BuildContext c, {required String kind, required String id, required String due}) =>
      _push(c, PayScreen(kind: kind, refId: id, dueDate: due), modal: true);
  static Future<void> loanForm(BuildContext c, {String? id}) => _push(c, LoanFormScreen(id: id), modal: true);
  static Future<void> billForm(BuildContext c, {String? id}) => _push(c, BillFormScreen(id: id), modal: true);
  static Future<void> goalForm(BuildContext c, {String? id}) => _push(c, GoalFormScreen(id: id), modal: true);
  static Future<void> budgetForm(BuildContext c) => _push(c, const BudgetFormScreen(), modal: true);
  static Future<void> loan(BuildContext c, String id) => _push(c, LoanDetailScreen(id: id));
  static Future<void> bill(BuildContext c, String id) => _push(c, BillDetailScreen(id: id));
  static Future<void> goal(BuildContext c, String id) => _push(c, GoalDetailScreen(id: id));
  static Future<void> profile(BuildContext c) => _push(c, const ProfileScreen());

  /// Replace the current screen with a loan or bill detail screen.
  static void replaceWithItem(BuildContext c, String kind, String id) => Navigator.of(c).pushReplacement(
    MaterialPageRoute(
      builder: (_) => kind == 'loan' ? LoanDetailScreen(id: id) : BillDetailScreen(id: id),
    ),
  );
}
