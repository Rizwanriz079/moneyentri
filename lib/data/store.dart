import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/dates.dart';
import '../core/format.dart';
import '../domain/schedule.dart';
import 'categories.dart';
import 'models.dart';

const defaultReminderOffsets = [7, 3, 1, 0];

/// Result of an action that can fail with a user-facing message.
class ActionResult {
  const ActionResult.ok() : error = null;
  const ActionResult.fail(this.error);
  final String? error;
  bool get ok => error == null;
}

/// Single source of truth for all app data, persisted on the device.
///
/// Every mutation replaces the affected list with a new list, so listeners
/// can detect what changed by identity (used by the reminder sync).
class AppStore extends ChangeNotifier {
  static const _storageKey = 'fintrack:state:v1';

  bool hydrated = false;
  Settings settings = const Settings();
  List<Transaction> transactions = const [];
  Budget budget = const Budget();
  List<Goal> goals = const [];
  List<Loan> loans = const [];
  List<Bill> bills = const [];
  List<Payment> payments = const [];

  Timer? _persistTimer;

  // ───────────────────────── Persistence ─────────────────────────

  /// Saved-data format version. 2: theme default changed from system to light.
  static const _dataVersion = 2;

  Future<void> hydrate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      var migrated = false;
      if (raw != null) {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        List<T> list<T>(String k, T Function(Map<String, dynamic>) f) => [
          for (final e in (j[k] as List? ?? [])) f(Map<String, dynamic>.from(e)),
        ];
        settings = Settings.fromJson(Map<String, dynamic>.from(j['settings'] ?? {}));
        // Data saved before version 2 had "system" as the automatic default
        // theme, not as a user choice. The default is now light.
        if ((j['version'] as num? ?? 1) < 2 && settings.theme == 'system') {
          settings = settings.copyWith(theme: 'light');
          migrated = true;
        }
        transactions = list('transactions', Transaction.fromJson);
        budget = Budget.fromJson(Map<String, dynamic>.from(j['budget'] ?? {}));
        goals = list('goals', Goal.fromJson);
        loans = list('loans', Loan.fromJson);
        bills = list('bills', Bill.fromJson);
        payments = list('payments', Payment.fromJson);
      }
      // Save the upgraded data right away.
      if (migrated) await prefs.setString(_storageKey, jsonEncode(toJson()));
    } catch (e) {
      debugPrint('Failed to load data: $e');
    }
    hydrated = true;
    notifyListeners();
  }

  Map<String, dynamic> toJson() => {
    'version': _dataVersion,
    'settings': settings.toJson(),
    'transactions': transactions.map((e) => e.toJson()).toList(),
    'budget': budget.toJson(),
    'goals': goals.map((e) => e.toJson()).toList(),
    'loans': loans.map((e) => e.toJson()).toList(),
    'bills': bills.map((e) => e.toJson()).toList(),
    'payments': payments.map((e) => e.toJson()).toList(),
  };

  Future<void> flush() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    if (!hydrated) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(toJson()));
    } catch (e) {
      debugPrint('Failed to save data: $e');
    }
  }

  void _changed() {
    notifyListeners();
    if (!hydrated) return;
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 250), flush);
  }

  // ───────────────────────── Settings ─────────────────────────

  void updateSettings(Settings Function(Settings s) update) {
    settings = update(settings);
    _changed();
  }

  void resetAllData() => replaceData(const AppData());

  void replaceData(AppData d) {
    transactions = d.transactions;
    budget = d.budget;
    goals = d.goals;
    loans = d.loans;
    bills = d.bills;
    payments = d.payments;
    _changed();
  }

  // ───────────────────────── Transactions ─────────────────────────

  Transaction addTransaction({
    required String type,
    required double amount,
    required String categoryId,
    required String date,
    required String method,
    required String note,
  }) {
    final tx = Transaction(
      id: uid(),
      type: type,
      amount: round2(amount),
      categoryId: categoryId,
      date: date,
      note: note,
      method: method,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    transactions = [tx, ...transactions];
    _changed();
    return tx;
  }

  /// For transactions created by an EMI/bill payment, amount, type and
  /// category are owned by the payment; date, method and note stay in sync.
  void updateTransaction(String id, {String? type, double? amount, String? categoryId, String? date, String? method, String? note}) {
    final tx = transactions.where((t) => t.id == id).firstOrNull;
    if (tx == null) return;
    final next = tx.link != null
        ? tx.copyWith(date: date, method: method, note: note)
        : tx.copyWith(
            type: type,
            amount: amount == null ? null : round2(amount),
            categoryId: categoryId,
            date: date,
            method: method,
            note: note,
          );
    transactions = [for (final t in transactions) t.id == id ? next : t];
    if (tx.link != null) {
      payments = [for (final p in payments) p.id == tx.link!.paymentId ? p.copyWith(paidOn: next.date, method: next.method) : p];
    }
    _changed();
  }

  /// Deleting a payment-linked expense also reverts that installment to pending.
  void deleteTransaction(String id) {
    final tx = transactions.where((t) => t.id == id).firstOrNull;
    transactions = transactions.where((t) => t.id != id).toList();
    if (tx?.link != null) payments = payments.where((p) => p.id != tx!.link!.paymentId).toList();
    _changed();
  }

  // ───────────────────────── Budget & goals ─────────────────────────

  void setBudget(Budget b) {
    budget = b;
    _changed();
  }

  void addGoal({
    required String name,
    required double target,
    String? deadline,
    required String icon,
    required String color,
    double initial = 0,
  }) {
    final now = DateTime.now().millisecondsSinceEpoch;
    goals = [
      ...goals,
      Goal(
        id: uid(),
        name: name,
        target: target,
        deadline: deadline,
        icon: icon,
        color: color,
        entries: initial > 0 ? [GoalEntry(id: uid(), amount: round2(initial), date: todayISO(), note: 'Initial savings')] : [],
        createdAt: now,
      ),
    ];
    _changed();
  }

  void updateGoal(String id, Goal Function(Goal g) update) {
    goals = [for (final g in goals) g.id == id ? update(g) : g];
    _changed();
  }

  void deleteGoal(String id) {
    goals = goals.where((g) => g.id != id).toList();
    _changed();
  }

  void addGoalEntry(String goalId, double amount, String note) {
    final entry = GoalEntry(id: uid(), amount: round2(amount), date: todayISO(), note: note);
    updateGoal(goalId, (g) => g.copyWith(entries: [entry, ...g.entries]));
  }

  // ───────────────────────── Loans ─────────────────────────

  /// EMIs dated before today are assumed already settled outside the app,
  /// unless the loan starts in the future.
  void addLoan(Loan input) {
    final today = todayISO();
    loans = [...loans, input.copyWith(trackingFrom: input.startDate.compareTo(today) > 0 ? input.startDate : today)];
    _changed();
  }

  void updateLoan(String id, Loan Function(Loan l) update) {
    loans = [for (final l in loans) l.id == id ? update(l) : l];
    _changed();
  }

  /// Removes the loan and its payment records. Past expenses remain as plain expenses.
  void deleteLoan(String id) {
    loans = loans.where((l) => l.id != id).toList();
    payments = payments.where((p) => !(p.kind == 'loan' && p.refId == id)).toList();
    transactions = [for (final t in transactions) t.link?.kind == 'loan' && t.link?.refId == id ? t.copyWith(clearLink: true) : t];
    _changed();
  }

  // ───────────────────────── Bills ─────────────────────────

  /// A first due date within the last month can still be caught up on;
  /// anything older is treated as settled before the bill was added.
  void addBill(Bill input) {
    final today = todayISO();
    final from = input.startDate.compareTo(addDays(today, -31)) >= 0 ? input.startDate : today;
    bills = [
      ...bills,
      Bill(
        id: input.id,
        name: input.name,
        category: input.category,
        amount: input.amount,
        frequency: input.frequency,
        startDate: input.startDate,
        endDate: input.endDate,
        reminders: input.reminders,
        trackingFrom: from,
        note: input.note,
        createdAt: input.createdAt,
      ),
    ];
    _changed();
  }

  void updateBill(String id, Bill Function(Bill b) update) {
    bills = [for (final b in bills) b.id == id ? update(b) : b];
    _changed();
  }

  void deleteBill(String id) {
    bills = bills.where((b) => b.id != id).toList();
    payments = payments.where((p) => !(p.kind == 'bill' && p.refId == id)).toList();
    transactions = [for (final t in transactions) t.link?.kind == 'bill' && t.link?.refId == id ? t.copyWith(clearLink: true) : t];
    _changed();
  }

  void setReminderPaused(String kind, String id, bool paused) {
    if (kind == 'loan') {
      updateLoan(id, (l) => l.copyWith(reminders: l.reminders.copyWith(paused: paused)));
    } else {
      updateBill(id, (b) => b.copyWith(reminders: b.reminders.copyWith(paused: paused)));
    }
  }

  // ───────────────────────── Payments (EMI + bills) ─────────────────────────

  /// Record an installment as paid. Creates exactly one linked expense
  /// transaction and, for loans, reduces the outstanding principal.
  ActionResult recordPayment({
    required String kind,
    required String refId,
    required String dueDate,
    required double amount,
    required String paidOn,
    required String method,
    String? note,
  }) {
    final occ = findOccurrence(loans, bills, payments, kind, refId, dueDate);
    if (occ == null) return const ActionResult.fail('This installment no longer exists.');
    if (occ.status == OccStatus.paid) return const ActionResult.fail('This installment is already marked as paid.');
    if (!(amount > 0)) return const ActionResult.fail('Enter an amount greater than zero.');

    final value = round2(amount);
    final paymentId = uid(), txId = uid();
    final now = DateTime.now().millisecondsSinceEpoch;
    late Payment payment;
    late Transaction tx;

    if (kind == 'loan') {
      final loan = loans.firstWhere((l) => l.id == refId);
      final remaining = loanRemaining(loan, payments);
      final split = splitPayment(remaining, loan.interestRate, value);
      payment = Payment(
        id: paymentId,
        kind: 'loan',
        refId: loan.id,
        dueDate: occ.dueDate,
        period: occ.period,
        amount: value,
        principal: split.principal,
        interest: split.interest,
        balanceAfter: round2(remaining - split.principal),
        paidOn: paidOn,
        method: method,
        transactionId: txId,
        createdAt: now,
      );
      tx = Transaction(
        id: txId,
        type: 'expense',
        amount: value,
        categoryId: 'emi',
        date: paidOn,
        note: note ?? '${loan.name} EMI #${occ.installment}${loan.bank.isNotEmpty ? ' · ${loan.bank}' : ''}',
        method: method,
        createdAt: now,
        link: TxLink(kind: 'loan', refId: loan.id, paymentId: paymentId),
      );
    } else {
      final bill = bills.firstWhere((b) => b.id == refId);
      payment = Payment(
        id: paymentId,
        kind: 'bill',
        refId: bill.id,
        dueDate: occ.dueDate,
        period: periodKey(occ.dueDate, weekly: bill.frequency == 'weekly'),
        amount: value,
        paidOn: paidOn,
        method: method,
        transactionId: txId,
        createdAt: now,
      );
      tx = Transaction(
        id: txId,
        type: 'expense',
        amount: value,
        categoryId: billCategory(bill.category).expense,
        date: paidOn,
        note: note ?? bill.name,
        method: method,
        createdAt: now,
        link: TxLink(kind: 'bill', refId: bill.id, paymentId: paymentId),
      );
    }

    payments = [...payments, payment];
    transactions = [tx, ...transactions];
    _changed();
    return const ActionResult.ok();
  }

  /// Mark a paid installment as pending again: removes the payment and its expense.
  void revertPayment(String paymentId) {
    final p = payments.where((x) => x.id == paymentId).firstOrNull;
    if (p == null) return;
    payments = payments.where((x) => x.id != paymentId).toList();
    transactions = transactions.where((t) => t.id != p.transactionId).toList();
    _changed();
  }

  @override
  void dispose() {
    _persistTimer?.cancel();
    super.dispose();
  }
}
