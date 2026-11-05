import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/nav.dart';
import '../core/dates.dart';
import '../core/format.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../data/categories.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../domain/schedule.dart';
import '../widgets/pickers.dart';
import '../widgets/rows.dart';
import '../widgets/ui.dart';

class PaymentsScreen extends StatelessWidget {
  const PaymentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<TabNav>();
    return Screen(
      tabs: true,
      children: [
        const T('Payments', v: TV.h1),
        Segmented<String>(
          options: const [SegOption('calendar', 'Calendar'), SegOption('loans', 'Loans & EMI'), SegOption('bills', 'Bills')],
          value: nav.paymentsTab,
          onChanged: nav.payments,
        ),
        switch (nav.paymentsTab) {
          'loans' => const _LoansView(),
          'bills' => const _BillsView(),
          _ => const _CalendarView(),
        },
      ],
    );
  }
}

// ───────────────────────── Calendar ─────────────────────────

class _CalendarView extends StatefulWidget {
  const _CalendarView();

  @override
  State<_CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<_CalendarView> {
  String month = monthKey(todayISO());
  String selected = todayISO();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.watch<AppStore>();
    final currency = s.settings.currency;

    if (s.loans.isEmpty && s.bills.isEmpty) {
      return AppCard(
        child: Column(
          children: [
            const EmptyState(
              icon: 'calendar-outline',
              title: 'No scheduled payments',
              message: 'Add a loan or a recurring bill to see due dates on the calendar and get reminders.',
            ),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    title: 'Add loan',
                    icon: 'card-outline',
                    variant: BtnVariant.secondary,
                    onTap: () => Routes.loanForm(context),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: AppButton(
                    title: 'Add bill',
                    icon: 'receipt-outline',
                    variant: BtnVariant.secondary,
                    onTap: () => Routes.billForm(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    final items = occurrencesInRange(s.loans, s.bills, s.payments, '$month-01', '$month-31');
    final selectedItems = items.where((o) => o.dueDate == selected).toList();
    final due = items.fold(0.0, (a, o) => a + o.amount);
    final paid = items.where((o) => o.status == OccStatus.paid).fold(0.0, (a, o) => a + o.amount);
    final overdue = items.where((o) => o.status == OccStatus.overdue).length;

    return Column(
      children: gap([
        FadeIn(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                T('Due in ${monthLabel(month, long: true)}', v: TV.caption, muted: true),
                T(formatMoney(due, currency), v: TV.h1),
                const SizedBox(height: 12),
                ProgressBar(value: due > 0 ? paid / due : 0, color: c.income),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: T(
                        '${formatMoney(paid, currency)} paid · ${formatMoney(due - paid, currency)} remaining',
                        v: TV.caption,
                        muted: true,
                      ),
                    ),
                    if (overdue > 0) Pill(label: '$overdue overdue', color: c.expense),
                  ],
                ),
              ],
            ),
          ),
        ),
        FadeIn(
          index: 1,
          child: AppCard(
            child: Column(
              children: [
                MonthCalendar(
                  month: month,
                  onMonthChange: (m) => setState(() {
                    month = m;
                    selected = '$m-01';
                  }),
                  selected: selected,
                  onSelect: (d) => setState(() => selected = d),
                  items: items,
                ),
                const SizedBox(height: 8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 14,
                  runSpacing: 6,
                  children: [
                    LegendDot(color: c.orange, label: 'Pending', round: true),
                    LegendDot(color: c.income, label: 'Paid', round: true),
                    LegendDot(color: c.expense, label: 'Overdue', round: true),
                  ],
                ),
              ],
            ),
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              T(fmtLong(selected), v: TV.h3),
              if (selectedItems.isNotEmpty)
                for (final o in selectedItems) PaymentRow(o: o)
              else
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: T('Nothing due on this day.', v: TV.caption, muted: true),
                ),
            ],
          ),
        ),
        if (items.isNotEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                T('All payments in ${monthLabel(month)}', v: TV.h3),
                for (final o in items) PaymentRow(o: o),
              ],
            ),
          ),
      ], Space.lg),
    );
  }
}

// ───────────────────────── Loans ─────────────────────────

class _LoansView extends StatelessWidget {
  const _LoansView();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.watch<AppStore>();
    final currency = s.settings.currency;
    final summaries = [for (final l in s.loans) (loan: l, sum: loanSummary(l, s.payments))];
    final outstanding = summaries.fold(0.0, (a, x) => a + x.sum.remaining);
    final monthlyEmi = summaries.where((x) => !x.sum.completed).fold(0.0, (a, x) => a + x.loan.emi);

    return Column(
      children: gap([
        if (s.loans.isNotEmpty)
          FadeIn(
            child: AppCard(
              color: c.primary,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const T('Total outstanding', v: TV.caption, color: Color(0xBFFFFFFF)),
                        T(formatMoney(outstanding, currency), v: TV.h2, color: Colors.white, maxLines: 1),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const T('Monthly EMIs', v: TV.caption, color: Color(0xBFFFFFFF)),
                        T(formatMoney(monthlyEmi, currency), v: TV.h2, color: Colors.white, maxLines: 1),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        for (var i = 0; i < summaries.length; i++)
          FadeIn(
            index: i + 1,
            child: _LoanCard(loan: summaries[i].loan, sum: summaries[i].sum),
          ),
        if (s.loans.isEmpty)
          AppCard(
            child: EmptyState(
              icon: 'card-outline',
              title: 'No loans added',
              message: 'Track car, personal, gold or home loans, get EMI reminders and watch your balance go down.',
              action: 'Add loan',
              onAction: () => Routes.loanForm(context),
            ),
          )
        else
          AppButton(title: 'Add loan', icon: 'add', variant: BtnVariant.secondary, onTap: () => Routes.loanForm(context)),
      ], Space.lg),
    );
  }
}

class _LoanCard extends StatelessWidget {
  const _LoanCard({required this.loan, required this.sum});
  final Loan loan;
  final LoanSummary sum;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final currency = useCurrency(context);
    final lt = loanType(loan.type);
    final next = sum.next;
    return AppCard(
      onTap: () => Routes.loan(context, loan.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: lt.icon, color: hex(lt.color)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    T(loan.name, v: TV.h3, maxLines: 1),
                    T(
                      '${loan.bank.isNotEmpty ? loan.bank : lt.name} · ${numText(loan.interestRate)}% p.a.',
                      v: TV.caption,
                      muted: true,
                      maxLines: 1,
                    ),
                  ],
                ),
              ),
              if (sum.completed)
                Pill(label: 'Completed', color: c.income)
              else if (loan.reminders.paused)
                Pill(label: 'Paused', color: c.textMuted)
              else if (next != null)
                Pill(label: statusStyle(next, c).label, color: statusStyle(next, c).color),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(child: T('Outstanding', v: TV.caption, muted: true)),
              const SizedBox(width: 8),
              Flexible(child: T('${(sum.progress * 100).round()}% repaid', v: TV.caption, muted: true, align: TextAlign.end)),
            ],
          ),
          const SizedBox(height: 8),
          T(formatMoney(sum.remaining, currency), v: TV.h2),
          const SizedBox(height: 8),
          ProgressBar(value: sum.progress, color: hex(lt.color)),
          if (next != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: c.cardAlt, borderRadius: BorderRadius.circular(AppRadius.md)),
              child: Row(
                children: [
                  Icon(appIcon('calendar-outline'), size: 16, color: c.textMuted),
                  const SizedBox(width: 8),
                  Expanded(child: T('Next EMI ${formatMoney(next.amount, currency)} on ${fmtShort(next.dueDate)}', v: TV.caption)),
                  T(
                    dueLabel(next.daysLeft),
                    v: TV.caption,
                    color: next.status == OccStatus.overdue ? c.expense : c.textMuted,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ───────────────────────── Bills ─────────────────────────

class _BillsView extends StatelessWidget {
  const _BillsView();

  @override
  Widget build(BuildContext context) {
    final s = context.watch<AppStore>();
    final currency = s.settings.currency;
    const factor = {'weekly': 52 / 12, 'monthly': 1.0, 'quarterly': 1 / 3, 'yearly': 1 / 12};
    final monthly = s.bills.fold(0.0, (a, b) => a + b.amount * (factor[b.frequency] ?? 1));

    return Column(
      children: gap([
        if (s.bills.isNotEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const T('Recurring bills · approx. per month', v: TV.caption, muted: true),
                T(formatMoney(monthly.round(), currency), v: TV.h1),
              ],
            ),
          ),
        for (var i = 0; i < s.bills.length; i++)
          FadeIn(
            index: i,
            child: _BillCard(bill: s.bills[i], payments: s.payments),
          ),
        if (s.bills.isEmpty)
          AppCard(
            child: EmptyState(
              icon: 'receipt-outline',
              title: 'No bills yet',
              message: 'Add rent, electricity, internet, insurance or subscriptions and never miss a due date.',
              action: 'Add bill',
              onAction: () => Routes.billForm(context),
            ),
          )
        else
          AppButton(title: 'Add bill', icon: 'add', variant: BtnVariant.secondary, onTap: () => Routes.billForm(context)),
      ], Space.lg),
    );
  }
}

class _BillCard extends StatelessWidget {
  const _BillCard({required this.bill, required this.payments});
  final Bill bill;
  final List<Payment> payments;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final currency = useCurrency(context);
    final bc = billCategory(bill.category);
    final sum = billSummary(bill, payments);
    final st = sum.next != null ? statusStyle(sum.next!, c) : null;
    return AppCard(
      onTap: () => Routes.bill(context, bill.id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: bc.icon, color: hex(bc.color)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    T(bill.name, v: TV.h3, maxLines: 1),
                    T(
                      '${frequencyLabels[bill.frequency]} · ${bc.name}${bill.reminders.paused ? ' · Reminders paused' : ''}',
                      v: TV.caption,
                      muted: true,
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  T(formatMoney(bill.amount, currency), v: TV.h3),
                  const SizedBox(height: 4),
                  if (sum.ended) Pill(label: 'Ended', color: c.textMuted) else if (st != null) Pill(label: st.label, color: st.color),
                ],
              ),
            ],
          ),
          if (sum.next != null) ...[
            const SizedBox(height: 10),
            T('Next due ${fmtLong(sum.next!.dueDate)} · ${dueLabel(sum.next!.daysLeft)}', v: TV.caption, muted: true),
          ],
        ],
      ),
    );
  }
}
