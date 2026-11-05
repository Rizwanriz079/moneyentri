import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/nav.dart';
import '../core/dates.dart';
import '../core/format.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../data/categories.dart';
import '../data/store.dart';
import '../domain/schedule.dart';
import '../widgets/pickers.dart';
import '../widgets/rows.dart';
import '../widgets/ui.dart';

class LoanDetailScreen extends StatelessWidget {
  const LoanDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.watch<AppStore>();
    final currency = s.settings.currency;
    final loan = s.loans.where((l) => l.id == id).firstOrNull;

    if (loan == null) {
      return const Screen(
        header: AppHeader(title: 'Loan'),
        children: [EmptyState(icon: 'alert-circle-outline', title: 'Loan not found', message: 'It may have been deleted.')],
      );
    }

    final sum = loanSummary(loan, s.payments);
    final history = s.payments.where((p) => p.kind == 'loan' && p.refId == id).toList()..sort((a, b) => b.dueDate.compareTo(a.dueDate));
    final lt = loanType(loan.type);
    final upcoming = sum.installments.where((o) => o.status != OccStatus.paid).take(6).toList();
    final remindersActive = loan.reminders.enabled && !loan.reminders.paused && !sum.completed;

    Future<void> remove() async {
      final ok = await confirmDialog(
        context,
        title: 'Delete this loan?',
        message: 'Its EMI schedule, reminders and payment history will be removed. Expenses already recorded stay in your transactions.',
      );
      if (!ok || !context.mounted) return;
      final store = context.read<AppStore>();
      Navigator.pop(context);
      store.deleteLoan(loan.id);
    }

    Widget stat(String label, String value) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        T(label, v: TV.caption, muted: true),
        const SizedBox(height: 2),
        T(value, v: TV.label, style: const TextStyle(fontSize: 15)),
      ],
    );

    return Screen(
      header: AppHeader(
        title: loan.name,
        subtitle: loan.bank.isNotEmpty ? loan.bank : lt.name,
        actions: [
          AppIconButton(
            icon: 'create-outline',
            onTap: () => Routes.loanForm(context, id: loan.id),
            tooltip: 'Edit',
          ),
          AppIconButton(icon: 'trash-outline', color: c.expense, onTap: remove, tooltip: 'Delete'),
        ],
      ),
      children: [
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBadge(icon: lt.icon, color: hex(lt.color), size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const T('Outstanding balance', v: TV.caption, muted: true),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: T(formatMoney(sum.remaining, currency), v: TV.h1),
                        ),
                      ],
                    ),
                  ),
                  if (sum.completed) Pill(label: 'Completed 🎉', color: c.income),
                ],
              ),
              const SizedBox(height: 16),
              ProgressBar(value: sum.progress, color: hex(lt.color), height: 10),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  T('${(sum.progress * 100).round()}% repaid', v: TV.caption, muted: true),
                  T('of ${formatMoney(loan.openingBalance, currency)}', v: TV.caption, muted: true),
                ],
              ),
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (_, box) => Wrap(
                  runSpacing: 14,
                  children: [
                    for (final (l, v) in [
                      ('Monthly EMI', formatMoney(loan.emi, currency)),
                      ('Interest rate', '${numText(loan.interestRate)}% p.a.'),
                      ('Total loan', formatMoney(loan.totalAmount, currency)),
                      ('Tenure', '${loan.tenureMonths} months'),
                      ('EMIs paid (in app)', '${sum.paidCount}'),
                      ('EMIs remaining', '${sum.pendingCount}'),
                      ('Interest paid', formatMoney(sum.interestPaid, currency)),
                      ('EMI day', 'Day ${int.parse(loan.startDate.substring(8))} monthly'),
                    ])
                      SizedBox(width: box.maxWidth / 2, child: stat(l, v)),
                  ],
                ),
              ),
              if (sum.next != null) ...[
                const SizedBox(height: 18),
                AppButton(
                  title: 'Pay EMI · ${fmtShort(sum.next!.dueDate)}',
                  icon: 'checkmark-circle',
                  variant: sum.next!.status == OccStatus.overdue ? BtnVariant.danger : BtnVariant.primary,
                  onTap: () => Routes.pay(context, kind: 'loan', id: loan.id, due: sum.next!.dueDate),
                ),
              ],
            ],
          ),
        ),
        AppCard(
          child: ToggleRow(
            icon: remindersActive ? 'notifications' : 'notifications-off-outline',
            label: 'EMI reminders',
            hint: !loan.reminders.enabled
                ? 'Turned off. Edit the loan to enable reminders.'
                : sum.completed
                ? 'Loan completed, so no more reminders.'
                : loan.reminders.paused
                ? 'Paused. No notifications will be sent.'
                : 'Active: ${offsetsLabel(loan.reminders.offsets)}',
            value: remindersActive,
            onChanged: (v) {
              if (!loan.reminders.enabled) {
                Routes.loanForm(context, id: loan.id);
                return;
              }
              context.read<AppStore>().setReminderPaused('loan', loan.id, !v);
            },
          ),
        ),
        if (upcoming.isNotEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Upcoming EMIs'),
                for (final o in upcoming) PaymentRow(o: o, compact: true),
              ],
            ),
          ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Payment history'),
              if (history.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: T(
                    'No EMI payments recorded yet. Payments you mark as paid will appear here with their interest and principal split.',
                    v: TV.caption,
                    muted: true,
                  ),
                )
              else
                for (var i = 0; i < history.length; i++) ...[
                  if (i > 0) const HairDivider(),
                  ScalePress(
                    onTap: () => Routes.pay(context, kind: 'loan', id: loan.id, due: history[i].dueDate),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(appIcon('checkmark-circle'), size: 18, color: c.income),
                              const SizedBox(width: 8),
                              Expanded(child: T('EMI for ${fmtShort(history[i].dueDate)}', v: TV.label)),
                              T(formatMoney(history[i].amount, currency), v: TV.label),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 26),
                            child: Row(
                              children: [
                                Expanded(
                                  child: T(
                                    'Paid ${fmtDate(history[i].paidOn)} · ${methodName(history[i].method)}',
                                    v: TV.caption,
                                    muted: true,
                                  ),
                                ),
                                T('Bal. ${formatMoney(history[i].balanceAfter ?? 0, currency)}', v: TV.caption, muted: true),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Padding(
                            padding: const EdgeInsets.only(left: 26),
                            child: Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                _Tag('Principal ${formatMoney(history[i].principal ?? 0, currency)}'),
                                _Tag('Interest ${formatMoney(history[i].interest ?? 0, currency)}'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
    decoration: BoxDecoration(color: context.colors.cardAlt, borderRadius: BorderRadius.circular(AppRadius.sm)),
    child: T(text, v: TV.caption, muted: true),
  );
}
