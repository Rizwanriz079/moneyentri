import 'package:fintrack/core/dates.dart';
import 'package:fintrack/core/format.dart';
import 'package:fintrack/data/models.dart';
import 'package:fintrack/data/store.dart';
import 'package:fintrack/domain/schedule.dart';
import 'package:fintrack/services/notification_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Loan _loan({String start = '', double balance = 100000, double emi = 10000, double rate = 12, int tenure = 12}) {
  final today = todayISO();
  return Loan(
    id: 'L1',
    name: 'Car Loan',
    type: 'car',
    bank: 'HDFC',
    totalAmount: balance,
    openingBalance: balance,
    emi: emi,
    interestRate: rate,
    startDate: start.isEmpty ? addDays(today, 5) : start,
    tenureMonths: tenure,
    reminders: const ReminderConfig(offsets: [7, 3, 1, 0]),
    trackingFrom: today,
    createdAt: 0,
  );
}

Bill _bill({String frequency = 'monthly', String? start}) => Bill(
      id: 'B1',
      name: 'Electricity',
      category: 'electricity',
      amount: 2400,
      frequency: frequency,
      startDate: start ?? addDays(todayISO(), 3),
      reminders: const ReminderConfig(offsets: [3, 1, 0]),
      trackingFrom: start ?? addDays(todayISO(), 3),
      note: '',
      createdAt: 0,
    );

void main() {
  group('formatting', () {
    test('Indian digit grouping for INR', () {
      expect(formatMoney(295211.63, 'INR'), '₹2,95,211.63');
      expect(formatMoney(1234567, 'USD'), r'$1,234,567');
      expect(formatMoney(-500, 'INR'), '- ₹500');
      expect(formatMoney(500, 'INR', sign: true), '+ ₹500');
      expect(formatSigned(5000, 'INR', income: true), '+ ₹5,000');
      expect(formatSigned(554, 'INR', income: false), '- ₹554');
      expect(formatCompact(-650000, 'INR'), '- ₹6.5L');
      expect(formatCompact(650000, 'INR'), '₹6.5L');
      expect(formatCompact(12000000, 'INR'), '₹1.2Cr');
    });

    test('month arithmetic clamps to month length', () {
      expect(addMonthsClamped('2026-01-31', 1), '2026-02-28');
      expect(addMonthsClamped('2026-01-31', 2, 31), '2026-03-31');
      expect(addMonthsClamped('2026-12-15', 1), '2027-01-15');
      expect(diffDays('2026-11-05', '2026-12-05'), 30);
    });
  });

  group('amortization', () {
    test('interest is outstanding × rate / 1200, the rest is principal', () {
      final s = splitPayment(540000, 9.2, 13800);
      expect(s.interest, 4140);
      expect(s.principal, 9660);
    });

    test('final EMI is suggested at the smaller remaining amount', () {
      final loan = _loan(balance: 5000, emi: 10000, rate: 12);
      expect(suggestedEmi(loan, const []), 5050); // 5000 + 1% interest
    });

    test('standard EMI calculator', () {
      expect(calcEmi(100000, 12, 12), closeTo(8884.88, 0.01));
      expect(calcEmi(120000, 0, 12), 10000);
    });
  });

  group('store: payments stay in sync with expenses', () {
    late AppStore s;
    setUp(() {
      s = AppStore();
      s.addLoan(_loan());
    });

    test('recording an EMI creates one linked expense and lowers the balance', () {
      final occ = loanInstallments(s.loans.first, s.payments).first;
      final res = s.recordPayment(kind: 'loan', refId: 'L1', dueDate: occ.dueDate, amount: 10000, paidOn: todayISO(), method: 'bank');
      expect(res.ok, isTrue);
      expect(s.payments, hasLength(1));
      expect(s.transactions, hasLength(1));
      expect(s.transactions.first.categoryId, 'emi');
      expect(s.transactions.first.link?.paymentId, s.payments.first.id);
      expect(loanRemaining(s.loans.first, s.payments), 91000); // 10000 - 1000 interest
    });

    test('paying the same installment twice is rejected', () {
      final due = loanInstallments(s.loans.first, s.payments).first.dueDate;
      s.recordPayment(kind: 'loan', refId: 'L1', dueDate: due, amount: 10000, paidOn: todayISO(), method: 'bank');
      final again = s.recordPayment(kind: 'loan', refId: 'L1', dueDate: due, amount: 10000, paidOn: todayISO(), method: 'bank');
      expect(again.ok, isFalse);
      expect(s.transactions, hasLength(1));
    });

    test('deleting the linked expense reverts the installment to pending', () {
      final due = loanInstallments(s.loans.first, s.payments).first.dueDate;
      s.recordPayment(kind: 'loan', refId: 'L1', dueDate: due, amount: 10000, paidOn: todayISO(), method: 'bank');
      s.deleteTransaction(s.transactions.first.id);
      expect(s.payments, isEmpty);
      expect(loanRemaining(s.loans.first, s.payments), 100000);
    });

    test('editing a linked expense only changes date/method and syncs the payment', () {
      final due = loanInstallments(s.loans.first, s.payments).first.dueDate;
      s.recordPayment(kind: 'loan', refId: 'L1', dueDate: due, amount: 10000, paidOn: todayISO(), method: 'bank');
      final tx = s.transactions.first;
      s.updateTransaction(tx.id, amount: 1, categoryId: 'food', date: addDays(todayISO(), -1), method: 'upi');
      expect(s.transactions.first.amount, 10000);
      expect(s.transactions.first.categoryId, 'emi');
      expect(s.payments.first.paidOn, addDays(todayISO(), -1));
      expect(s.payments.first.method, 'upi');
    });

    test('revertPayment removes payment and its expense', () {
      final due = loanInstallments(s.loans.first, s.payments).first.dueDate;
      s.recordPayment(kind: 'loan', refId: 'L1', dueDate: due, amount: 10000, paidOn: todayISO(), method: 'bank');
      s.revertPayment(s.payments.first.id);
      expect(s.payments, isEmpty);
      expect(s.transactions, isEmpty);
    });

    test('moving the EMI day keeps an already-paid month paid', () {
      final first = loanInstallments(s.loans.first, s.payments).first;
      s.recordPayment(kind: 'loan', refId: 'L1', dueDate: first.dueDate, amount: 10000, paidOn: todayISO(), method: 'bank');
      // Move the due day by one day within the same month.
      final moved = parseISO(first.dueDate).day < 28 ? addDays(s.loans.first.startDate, 1) : addDays(s.loans.first.startDate, -1);
      s.updateLoan('L1', (l) => l.copyWith(startDate: moved));
      final inst = loanInstallments(s.loans.first, s.payments);
      expect(inst.first.status, OccStatus.paid);
      expect(inst.first.period, first.period);
    });

    test('deleting a loan keeps past expenses but unlinks them', () {
      final due = loanInstallments(s.loans.first, s.payments).first.dueDate;
      s.recordPayment(kind: 'loan', refId: 'L1', dueDate: due, amount: 10000, paidOn: todayISO(), method: 'bank');
      s.deleteLoan('L1');
      expect(s.payments, isEmpty);
      expect(s.transactions, hasLength(1));
      expect(s.transactions.first.link, isNull);
    });

    test('bill payment uses the mapped expense category', () {
      s.addBill(_bill());
      final due = billOccurrences(s.bills.first, s.payments, todayISO(), addDays(todayISO(), 60)).first.dueDate;
      s.recordPayment(kind: 'bill', refId: 'B1', dueDate: due, amount: 2400, paidOn: todayISO(), method: 'upi');
      expect(s.transactions.first.categoryId, 'bills');
      expect(billSummary(s.bills.first, s.payments).next?.dueDate, isNot(due));
    });
  });

  group('recurrence', () {
    test('weekly bills match payments by exact date', () {
      final b = _bill(frequency: 'weekly');
      final occ = billOccurrences(b, const [], todayISO(), addDays(todayISO(), 30));
      expect(occ.length, greaterThanOrEqualTo(4));
      expect(occ[1].period, occ[1].dueDate);
      expect(diffDays(occ[0].dueDate, occ[1].dueDate), 7);
    });

    test('bills stop after their end date', () {
      final b = _bill().copyWith(endDate: addDays(todayISO(), 40));
      final occ = billOccurrences(b, const [], todayISO(), addDays(todayISO(), 400));
      expect(occ.length, lessThanOrEqualTo(2));
    });

    test('loan installments stop once the balance is cleared', () {
      final s = AppStore()..addLoan(_loan(balance: 10000, emi: 10000, rate: 0));
      final due = loanInstallments(s.loans.first, s.payments).first.dueDate;
      s.recordPayment(kind: 'loan', refId: 'L1', dueDate: due, amount: 10000, paidOn: todayISO(), method: 'bank');
      final sum = loanSummary(s.loans.first, s.payments);
      expect(sum.completed, isTrue);
      expect(sum.installments.where((o) => o.status != OccStatus.paid), isEmpty);
    });
  });

  group('reminder planning', () {
    final now = DateTime.now();

    test('plans 7/3/1/0-day reminders for the next unpaid installments only', () {
      final s = AppStore()..addLoan(_loan(start: addDays(todayISO(), 10)));
      final plan = planReminders(s, now: now);
      // 3 installments × 4 offsets, minus any already in the past.
      expect(plan.length, inInclusiveRange(10, 12));
      expect(plan.every((p) => p.fireAt.isAfter(now)), isTrue);
      // Private reminders (the default) leave the amount out of the notification.
      expect(plan.first.body, isNot(contains('₹')));
      expect(plan.first.body, contains('Open FinTrack'));
      s.updateSettings((x) => x.copyWith(privateReminders: false));
      final shown = planReminders(s, now: now);
      expect(shown.first.body, contains('₹10,000'));
      expect(shown.first.key, isNot(plan.first.key), reason: 'changing the text reschedules the reminder');
      expect(plan.map((p) => p.id).toSet().length, plan.length, reason: 'no duplicate ids');
    });

    test('planning is deterministic, so re-syncing never duplicates', () {
      final s = AppStore()..addLoan(_loan());
      final a = planReminders(s, now: now).map((p) => p.key).toList();
      final b = planReminders(s, now: now).map((p) => p.key).toList();
      expect(a, b);
    });

    test('changing the amount or date changes the reminder keys (reschedule)', () {
      final s = AppStore()..addLoan(_loan());
      // Private reminders (default): moving the date reschedules.
      final before = planReminders(s, now: now).map((p) => p.key).toSet();
      s.updateLoan('L1', (l) => l.copyWith(startDate: addDays(l.startDate, 2)));
      final moved = planReminders(s, now: now).map((p) => p.key).toSet();
      expect(before.intersection(moved), isEmpty);
      // Amounts shown: changing the amount reschedules too.
      s.updateSettings((x) => x.copyWith(privateReminders: false));
      final shown = planReminders(s, now: now).map((p) => p.key).toSet();
      s.updateLoan('L1', (l) => l.copyWith(emi: 12000));
      final after = planReminders(s, now: now).map((p) => p.key).toSet();
      expect(shown.intersection(after), isEmpty);
    });

    test('paused, disabled or paid installments get no reminders', () {
      final s = AppStore()..addLoan(_loan());
      s.setReminderPaused('loan', 'L1', true);
      expect(planReminders(s, now: now), isEmpty);
      s.setReminderPaused('loan', 'L1', false);
      final first = loanInstallments(s.loans.first, s.payments).first;
      s.recordPayment(kind: 'loan', refId: 'L1', dueDate: first.dueDate, amount: 10000, paidOn: todayISO(), method: 'bank');
      expect(planReminders(s, now: now).any((p) => p.target.dueDate == first.dueDate), isFalse);
      s.updateSettings((x) => x.copyWith(notificationsEnabled: false));
      expect(planReminders(s, now: now), isEmpty);
    });

    test('a reminder firing never marks anything as paid', () {
      final s = AppStore()..addLoan(_loan());
      planReminders(s, now: now);
      expect(s.payments, isEmpty);
    });

    test('total scheduled reminders are capped', () {
      final s = AppStore();
      for (var i = 0; i < 30; i++) {
        s.addBill(Bill(
          id: 'B$i',
          name: 'Bill $i',
          category: 'other',
          amount: 100,
          frequency: 'weekly',
          startDate: addDays(todayISO(), 8),
          reminders: const ReminderConfig(offsets: [7, 3, 1, 0]),
          trackingFrom: todayISO(),
          note: '',
          createdAt: 0,
        ));
      }
      expect(planReminders(s, now: now).length, maxScheduled);
    });
  });

  group('theme', () {
    test('a new install defaults to the light theme', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppStore();
      await s.hydrate();
      expect(s.settings.theme, 'light');
    });

    test('old saved data with the automatic "system" theme opens in light', () async {
      SharedPreferences.setMockInitialValues({
        'fintrack:state:v1': '{"version":1,"settings":{"theme":"system","currency":"INR"}}',
      });
      final s = AppStore();
      await s.hydrate();
      expect(s.settings.theme, 'light');
      final saved = (await SharedPreferences.getInstance()).getString('fintrack:state:v1')!;
      expect(saved, contains('"theme":"light"'));
      expect(saved, contains('"version":2'));
    });

    test('a theme the user picked is kept, including system', () async {
      for (final pick in ['dark', 'system']) {
        SharedPreferences.setMockInitialValues({
          'fintrack:state:v1': '{"version":2,"settings":{"theme":"$pick","currency":"INR"}}',
        });
        final s = AppStore();
        await s.hydrate();
        expect(s.settings.theme, pick);
      }
    });

    test('security settings default to private reminders on, app lock off, and are saved', () async {
      SharedPreferences.setMockInitialValues({});
      final s = AppStore();
      await s.hydrate();
      expect(s.settings.privateReminders, isTrue);
      expect(s.settings.appLock, isFalse);
      final j = s.settings.copyWith(appLock: true, privateReminders: false).toJson();
      final back = Settings.fromJson(j);
      expect(back.appLock, isTrue);
      expect(back.privateReminders, isFalse);
    });

    test('the saved data records the new format version', () {
      expect(AppStore().toJson()['version'], 2);
    });
  });
}
