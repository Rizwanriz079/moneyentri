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

const _freq = {'weekly': 'Every week', 'monthly': 'Every month', 'quarterly': 'Every 3 months', 'yearly': 'Every year'};

class BillDetailScreen extends StatelessWidget {
  const BillDetailScreen({super.key, required this.id});
  final String id;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.watch<AppStore>();
    final currency = s.settings.currency;
    final bill = s.bills.where((b) => b.id == id).firstOrNull;

    if (bill == null) {
      return const Screen(
        header: AppHeader(title: 'Bill'),
        children: [EmptyState(icon: 'alert-circle-outline', title: 'Bill not found', message: 'It may have been deleted.')],
      );
    }

    final today = todayISO();
    final sum = billSummary(bill, s.payments, today);
    final upcoming = billOccurrences(
      bill,
      s.payments,
      addDays(today, -120),
      addDays(today, 400),
      today,
    ).where((o) => o.status != OccStatus.paid).take(5).toList();
    final history = s.payments.where((p) => p.kind == 'bill' && p.refId == bill.id).toList()
      ..sort((a, b) => b.dueDate.compareTo(a.dueDate));
    final bc = billCategory(bill.category);
    final next = sum.next;
    final active = bill.reminders.enabled && !bill.reminders.paused;
    final totalPaid = history.fold(0.0, (a, p) => a + p.amount);

    Future<void> remove() async {
      final ok = await confirmDialog(
        context,
        title: 'Delete this bill?',
        message: 'Its schedule, reminders and payment history will be removed. Recorded expenses stay in your transactions.',
      );
      if (!ok || !context.mounted) return;
      final store = context.read<AppStore>();
      Navigator.pop(context);
      store.deleteBill(bill.id);
    }

    return Screen(
      header: AppHeader(
        title: bill.name,
        subtitle: bc.name,
        actions: [
          AppIconButton(
            icon: 'create-outline',
            onTap: () => Routes.billForm(context, id: bill.id),
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
                  IconBadge(icon: bc.icon, color: hex(bc.color), size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        T(formatMoney(bill.amount, currency), v: TV.h1),
                        T(
                          '${_freq[bill.frequency]}${bill.endDate != null ? ' until ${fmtDate(bill.endDate!)}' : ''}',
                          v: TV.caption,
                          muted: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (next != null) ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(appIcon('calendar-outline'), size: 16, color: c.textMuted),
                    const SizedBox(width: 8),
                    Expanded(child: T('Next due ${fmtLong(next.dueDate)}', v: TV.label)),
                    T(
                      dueLabel(next.daysLeft),
                      v: TV.caption,
                      color: next.status == OccStatus.overdue ? c.expense : c.textMuted,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                AppButton(
                  title: 'Mark as paid',
                  icon: 'checkmark-circle',
                  variant: next.status == OccStatus.overdue ? BtnVariant.danger : BtnVariant.success,
                  onTap: () => Routes.pay(context, kind: 'bill', id: bill.id, due: next.dueDate),
                ),
              ] else
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: T(sum.ended ? 'This bill has ended.' : 'All caught up.', v: TV.caption, muted: true),
                ),
              if (bill.note.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: T(bill.note, v: TV.caption, muted: true),
                ),
            ],
          ),
        ),
        AppCard(
          child: ToggleRow(
            icon: active ? 'notifications' : 'notifications-off-outline',
            label: 'Reminders',
            hint: !bill.reminders.enabled
                ? 'Turned off. Edit the bill to enable reminders.'
                : bill.reminders.paused
                ? 'Paused. No notifications will be sent.'
                : 'Active: ${offsetsLabel(bill.reminders.offsets)}',
            value: active,
            onChanged: (v) {
              if (!bill.reminders.enabled) {
                Routes.billForm(context, id: bill.id);
                return;
              }
              context.read<AppStore>().setReminderPaused('bill', bill.id, !v);
            },
          ),
        ),
        if (upcoming.isNotEmpty)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Upcoming'),
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
                  child: T('No payments recorded yet.', v: TV.caption, muted: true),
                )
              else ...[
                const SizedBox(height: 2),
                T(
                  '${formatMoney(totalPaid, currency)} paid across ${history.length} payment${history.length > 1 ? 's' : ''}',
                  v: TV.caption,
                  muted: true,
                ),
                const SizedBox(height: 4),
                for (var i = 0; i < history.length; i++) ...[
                  if (i > 0) const HairDivider(),
                  ScalePress(
                    onTap: () => Routes.pay(context, kind: 'bill', id: bill.id, due: history[i].dueDate),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        children: [
                          Icon(appIcon('checkmark-circle'), size: 18, color: c.income),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                T('Due ${fmtDate(history[i].dueDate)}', v: TV.label),
                                T('Paid ${fmtDate(history[i].paidOn)} · ${methodName(history[i].method)}', v: TV.caption, muted: true),
                              ],
                            ),
                          ),
                          T(formatMoney(history[i].amount, currency), v: TV.label),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ],
    );
  }
}
