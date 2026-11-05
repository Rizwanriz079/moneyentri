import 'dart:math';

import '../core/dates.dart';
import '../core/format.dart';
import '../data/models.dart';
import '../data/store.dart';

/// Realistic sample data spanning the last ~6 months.
AppData buildDemoData() {
  final today = todayISO();
  final tx = <Transaction>[];
  void add(String type, double amount, String categoryId, String date, String note, String method) => tx.add(
    Transaction(
      id: uid(),
      type: type,
      amount: round2(amount),
      categoryId: categoryId,
      date: date,
      note: note,
      method: method,
      createdAt: parseISO(date).millisecondsSinceEpoch,
    ),
  );

  double seed(int i) {
    final x = sin(i * 9301 + 49297) * 233280;
    return x - x.floorToDouble();
  }

  bool le(String a, String b) => a.compareTo(b) <= 0;

  for (var m = 5; m >= 0; m--) {
    final first = addMonthsClamped('${monthKey(today)}-01', -m);
    if (le(first, today)) add('income', 85000, 'salary', first, 'Monthly salary', 'bank');
    if (m % 2 == 0 && le(addDays(first, 14), today)) {
      add('income', 12000 + seed(m) * 8000, 'freelance', addDays(first, 14), 'Design project', 'upi');
    }
    final rentDay = addDays(first, 4);
    if (le(rentDay, today) && m > 0) add('expense', 22000, 'rent', rentDay, 'House rent', 'bank');
    for (var d = 0; d < 30; d++) {
      final date = addDays(first, d);
      if (!le(date, today) || monthKey(date) != monthKey(first)) continue;
      final r = seed(m * 31 + d);
      if (r < 0.55) {
        add('expense', 120 + r * 600, 'food', date, const ['Swiggy order', 'Lunch', 'Cafe Coffee Day', 'Dinner out'][d % 4], 'upi');
      }
      if (d % 6 == 2) add('expense', 900 + r * 1800, 'groceries', date, 'BigBasket', 'card');
      if (d % 4 == 1) add('expense', 150 + r * 400, 'transport', date, d % 8 == 1 ? 'Uber' : 'Metro card', 'upi');
      if (d % 11 == 5) add('expense', 1200 + r * 3500, 'shopping', date, 'Amazon', 'card');
      if (d % 13 == 7) add('expense', 400 + r * 900, 'entertainment', date, 'Movie night', 'card');
      if (d == 18 && m % 3 == 0) add('expense', 800 + r * 1500, 'health', date, 'Pharmacy', 'cash');
    }
  }

  final now = DateTime.now().millisecondsSinceEpoch;
  const reminders = ReminderConfig(offsets: defaultReminderOffsets);
  final loans = [
    Loan(
      id: uid(),
      name: 'Car Loan',
      type: 'car',
      bank: 'HDFC Bank',
      totalAmount: 650000,
      openingBalance: 540000,
      emi: 13800,
      interestRate: 9.2,
      startDate: addMonthsClamped(today, -10, 5),
      tenureMonths: 60,
      reminders: reminders,
      trackingFrom: addDays(today, -20),
      createdAt: now,
    ),
    Loan(
      id: uid(),
      name: 'Gold Loan',
      type: 'gold',
      bank: 'Muthoot Finance',
      totalAmount: 120000,
      openingBalance: 120000,
      emi: 10600,
      interestRate: 10.5,
      startDate: addMonthsClamped(today, 0, min(28, parseISO(today).day + 3)),
      tenureMonths: 12,
      reminders: reminders,
      trackingFrom: today,
      createdAt: now,
    ),
  ];

  Bill bill(String name, String category, double amount, int day, [String frequency = 'monthly']) {
    final start = addMonthsClamped(today, parseISO(today).day > day ? 1 : 0, day);
    return Bill(
      id: uid(),
      name: name,
      category: category,
      amount: amount,
      frequency: frequency,
      startDate: start,
      reminders: const ReminderConfig(offsets: [3, 1, 0]),
      trackingFrom: start,
      note: '',
      createdAt: now,
    );
  }

  final bills = [
    bill('House Rent', 'rent', 22000, 5),
    bill('Electricity', 'electricity', 2400, 12),
    bill('Airtel Fiber', 'internet', 999, 18),
    bill('Netflix', 'subscription', 649, 22),
    bill('Health Insurance', 'insurance', 18500, 28, 'yearly'),
  ];

  final goals = [
    Goal(
      id: uid(),
      name: 'Goa Trip',
      target: 60000,
      deadline: addMonthsClamped(today, 4),
      icon: 'airplane',
      color: '#0EA5E9',
      entries: [
        GoalEntry(id: uid(), amount: 15000, date: addDays(today, -60), note: 'Initial savings'),
        GoalEntry(id: uid(), amount: 12000, date: addDays(today, -20), note: ''),
      ],
      createdAt: now,
    ),
    Goal(
      id: uid(),
      name: 'Emergency Fund',
      target: 300000,
      icon: 'umbrella',
      color: '#22C55E',
      entries: [GoalEntry(id: uid(), amount: 145000, date: addDays(today, -90), note: 'Initial savings')],
      createdAt: now,
    ),
    Goal(
      id: uid(),
      name: 'New MacBook',
      target: 150000,
      deadline: addMonthsClamped(today, 8),
      icon: 'laptop',
      color: '#6366F1',
      entries: [GoalEntry(id: uid(), amount: 32000, date: addDays(today, -30), note: '')],
      createdAt: now,
    ),
  ];

  tx.sort((a, b) {
    final c = b.date.compareTo(a.date);
    return c != 0 ? c : b.createdAt.compareTo(a.createdAt);
  });

  return AppData(
    transactions: tx,
    budget: const Budget(
      monthly: 60000,
      categories: {'food': 8000, 'groceries': 9000, 'shopping': 6000, 'transport': 3000, 'entertainment': 2500},
    ),
    goals: goals,
    loans: loans,
    bills: bills,
  );
}
