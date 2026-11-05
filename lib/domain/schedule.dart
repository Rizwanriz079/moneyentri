import 'dart:math';

import '../core/dates.dart';
import '../core/format.dart';
import '../data/categories.dart';
import '../data/models.dart';

enum OccStatus { paid, pending, overdue }

/// One installment of a loan or a bill (paid or not).
class Occurrence {
  const Occurrence({
    required this.key,
    required this.kind,
    required this.refId,
    required this.name,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.dueDate,
    required this.period,
    required this.amount,
    this.installment,
    required this.status,
    this.payment,
    required this.daysLeft,
  });

  final String key, kind, refId, name, subtitle, icon, color, dueDate, period;
  final double amount;

  /// 1-based EMI number (loans only).
  final int? installment;
  final OccStatus status;
  final Payment? payment;
  final int daysLeft;
}

/// Installments are matched to payments by month, so moving the due day keeps paid EMIs paid.
String periodKey(String dueDate, {bool weekly = false}) => weekly ? dueDate : dueDate.substring(0, 7);

String _payKey(String kind, String refId, String period) => '$kind|$refId|$period';

Map<String, Payment> indexPayments(List<Payment> payments) => {for (final p in payments) _payKey(p.kind, p.refId, p.period): p};

// ───────────────────────── Loans ─────────────────────────

String loanDueDate(Loan loan, int i) => addMonthsClamped(loan.startDate, i, parseISO(loan.startDate).day);

double loanPrincipalPaid(String loanId, List<Payment> payments) =>
    payments.where((p) => p.kind == 'loan' && p.refId == loanId).fold(0.0, (s, p) => s + (p.principal ?? 0));

double loanRemaining(Loan loan, List<Payment> payments) => max(0, round2(loan.openingBalance - loanPrincipalPaid(loan.id, payments)));

class Split {
  const Split(this.interest, this.principal);
  final double interest, principal;
}

/// Monthly interest on the outstanding balance plus the principal share of a payment.
Split splitPayment(double remaining, double annualRate, double amount) {
  final interest = annualRate > 0 ? round2(remaining * annualRate / 1200) : 0.0;
  final principal = round2(max(0, min(remaining, amount - interest)));
  return Split(round2(min(interest, amount)), principal);
}

/// Suggested amount for the next EMI (the final EMI is usually smaller).
double suggestedEmi(Loan loan, List<Payment> payments) {
  final remaining = loanRemaining(loan, payments);
  final interest = splitPayment(remaining, loan.interestRate, double.maxFinite).interest;
  return round2(min(loan.emi, remaining + interest));
}

/// Standard reducing-balance EMI.
double calcEmi(double principal, double annualRate, int months) {
  if (!(principal > 0) || months <= 0) return 0;
  final r = annualRate / 1200;
  if (r == 0) return round2(principal / months);
  final f = pow(1 + r, months);
  return round2(principal * r * f / (f - 1));
}

List<Occurrence> loanInstallments(Loan loan, List<Payment> payments, [String? today]) {
  today ??= todayISO();
  final idx = indexPayments(payments);
  final lt = loanType(loan.type);
  final done = loanRemaining(loan, payments) <= 0.5;
  final out = <Occurrence>[];
  for (var i = 0; i < loan.tenureMonths; i++) {
    final due = loanDueDate(loan, i);
    if (due.compareTo(loan.trackingFrom) < 0) continue;
    final period = periodKey(due);
    final payment = idx[_payKey('loan', loan.id, period)];
    if (payment == null && done) continue; // balance cleared: nothing further is owed
    final daysLeft = diffDays(today, due);
    out.add(
      Occurrence(
        key: 'loan|${loan.id}|$period',
        kind: 'loan',
        refId: loan.id,
        name: loan.name,
        subtitle: loan.bank.isNotEmpty ? loan.bank : lt.name,
        icon: lt.icon,
        color: lt.color,
        dueDate: due,
        period: period,
        amount: payment?.amount ?? loan.emi,
        installment: i + 1,
        status: payment != null ? OccStatus.paid : (daysLeft < 0 ? OccStatus.overdue : OccStatus.pending),
        payment: payment,
        daysLeft: daysLeft,
      ),
    );
  }
  return out;
}

class LoanSummary {
  const LoanSummary({
    required this.remaining,
    required this.completed,
    required this.next,
    required this.pendingCount,
    required this.paidCount,
    required this.interestPaid,
    required this.progress,
    required this.installments,
  });
  final double remaining, interestPaid, progress;
  final bool completed;
  final Occurrence? next;
  final int pendingCount, paidCount;
  final List<Occurrence> installments;
}

LoanSummary loanSummary(Loan loan, List<Payment> payments, [String? today]) {
  final inst = loanInstallments(loan, payments, today);
  final remaining = loanRemaining(loan, payments);
  final unpaid = inst.where((o) => o.status != OccStatus.paid).toList();
  final completed = remaining <= 0.5 || unpaid.isEmpty;
  final mine = payments.where((p) => p.kind == 'loan' && p.refId == loan.id);
  return LoanSummary(
    remaining: remaining,
    completed: completed,
    next: completed ? null : unpaid.first,
    pendingCount: unpaid.length,
    paidCount: mine.length,
    interestPaid: round2(mine.fold(0.0, (s, p) => s + (p.interest ?? 0))),
    progress: loan.openingBalance > 0 ? min(1, 1 - remaining / loan.openingBalance) : 1,
    installments: inst,
  );
}

// ───────────────────────── Bills ─────────────────────────

String billDueDate(Bill bill, int i) {
  final day = parseISO(bill.startDate).day;
  switch (bill.frequency) {
    case 'weekly':
      return addDays(bill.startDate, 7 * i);
    case 'quarterly':
      return addMonthsClamped(bill.startDate, 3 * i, day);
    case 'yearly':
      return addMonthsClamped(bill.startDate, 12 * i, day);
    default:
      return addMonthsClamped(bill.startDate, i, day);
  }
}

List<Occurrence> billOccurrences(Bill bill, List<Payment> payments, String from, String to, [String? today]) {
  today ??= todayISO();
  final idx = indexPayments(payments);
  final bc = billCategory(bill.category);
  final weekly = bill.frequency == 'weekly';
  final out = <Occurrence>[];
  for (var i = 0; i < 5000; i++) {
    final due = billDueDate(bill, i);
    if (due.compareTo(to) > 0 || (bill.endDate != null && due.compareTo(bill.endDate!) > 0)) break;
    if (due.compareTo(from) < 0 || due.compareTo(bill.trackingFrom) < 0) continue;
    final period = periodKey(due, weekly: weekly);
    final payment = idx[_payKey('bill', bill.id, period)];
    final daysLeft = diffDays(today, due);
    out.add(
      Occurrence(
        key: 'bill|${bill.id}|$period',
        kind: 'bill',
        refId: bill.id,
        name: bill.name,
        subtitle: bc.name,
        icon: bc.icon,
        color: bc.color,
        dueDate: due,
        period: period,
        amount: payment?.amount ?? bill.amount,
        status: payment != null ? OccStatus.paid : (daysLeft < 0 ? OccStatus.overdue : OccStatus.pending),
        payment: payment,
        daysLeft: daysLeft,
      ),
    );
  }
  return out;
}

class BillSummary {
  const BillSummary(this.next, this.overdueCount, this.ended);
  final Occurrence? next;
  final int overdueCount;
  final bool ended;
}

BillSummary billSummary(Bill bill, List<Payment> payments, [String? today]) {
  today ??= todayISO();
  final past = billOccurrences(bill, payments, addDays(today, -120), addDays(today, -1), today);
  final future = billOccurrences(bill, payments, today, addDays(today, 400), today);
  final overdue = past.where((o) => o.status == OccStatus.overdue).toList();
  Occurrence? next = overdue.isNotEmpty ? overdue.first : null;
  if (next == null) {
    for (final o in future) {
      if (o.status != OccStatus.paid) {
        next = o;
        break;
      }
    }
  }
  return BillSummary(next, overdue.length, next == null && future.isEmpty);
}

// ───────────────────────── Combined views ─────────────────────────

/// All loan and bill installments due within [from, to].
List<Occurrence> occurrencesInRange(List<Loan> loans, List<Bill> bills, List<Payment> payments, String from, String to, [String? today]) {
  today ??= todayISO();
  final out = <Occurrence>[];
  for (final loan in loans) {
    for (final o in loanInstallments(loan, payments, today)) {
      if (o.dueDate.compareTo(from) >= 0 && o.dueDate.compareTo(to) <= 0) out.add(o);
    }
  }
  for (final bill in bills) {
    out.addAll(billOccurrences(bill, payments, from, to, today));
  }
  out.sort((a, b) => a.dueDate.compareTo(b.dueDate));
  return out;
}

/// Dashboard list: anything overdue in the last 60 days plus everything due in
/// the next [days] days (paid items stay visible with a Paid badge).
List<Occurrence> upcomingPayments(List<Loan> loans, List<Bill> bills, List<Payment> payments, {int days = 30, String? today}) {
  today ??= todayISO();
  return occurrencesInRange(
    loans,
    bills,
    payments,
    addDays(today, -60),
    addDays(today, days),
    today,
  ).where((o) => o.dueDate.compareTo(today!) >= 0 || o.status == OccStatus.overdue).toList();
}

/// The installment that matches (kind, refId, dueDate), if it still exists.
Occurrence? findOccurrence(List<Loan> loans, List<Bill> bills, List<Payment> payments, String kind, String refId, String dueDate) {
  if (kind == 'loan') {
    final loan = loans.where((l) => l.id == refId).firstOrNull;
    if (loan == null) return null;
    return loanInstallments(loan, payments).where((o) => o.dueDate == dueDate).firstOrNull;
  }
  final bill = bills.where((b) => b.id == refId).firstOrNull;
  if (bill == null) return null;
  return billOccurrences(bill, payments, dueDate, dueDate).firstOrNull;
}
