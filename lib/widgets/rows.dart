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
import 'ui.dart';

String useCurrency(BuildContext context) => context.select<AppStore, String>((s) => s.settings.currency);

class TransactionRow extends StatelessWidget {
  const TransactionRow({super.key, required this.tx, this.showDate = true, this.onLongPress});
  final Transaction tx;
  final bool showDate;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final currency = useCurrency(context);
    final cat = getCategory(tx.categoryId);
    final income = tx.isIncome;
    return ScalePress(
      onTap: () => Routes.transactionForm(context, id: tx.id),
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            IconBadge(icon: cat.icon, color: hex(cat.color)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  T(tx.note.isNotEmpty ? tx.note : cat.name, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Flexible(
                        child: T(
                          '${tx.note.isNotEmpty ? cat.name : methodName(tx.method)}${showDate ? ' · ${fmtRelative(tx.date)}' : ''}',
                          v: TV.caption,
                          muted: true,
                          maxLines: 1,
                        ),
                      ),
                      if (tx.link != null) ...[const SizedBox(width: 6), Icon(appIcon('link'), size: 12, color: c.primary)],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Large amounts scale down rather than push the row off screen.
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 150),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: T(
                  formatSigned(tx.amount, currency, income: income),
                  color: income ? c.income : c.expense,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class StatusStyle {
  const StatusStyle(this.label, this.color);
  final String label;
  final Color color;
}

StatusStyle statusStyle(Occurrence o, AppColors c) {
  if (o.status == OccStatus.paid) return StatusStyle('Paid', c.income);
  if (o.status == OccStatus.overdue) return StatusStyle('Overdue', c.expense);
  if (o.daysLeft <= 3) return StatusStyle('Due soon', c.orange);
  return StatusStyle('Pending', c.warning);
}

/// One EMI / bill installment. Tapping opens the payment sheet (or the item if paid).
class PaymentRow extends StatelessWidget {
  const PaymentRow({super.key, required this.o, this.compact = false});
  final Occurrence o;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final currency = useCurrency(context);
    final st = statusStyle(o, c);
    void open() {
      if (o.status == OccStatus.paid) {
        o.kind == 'loan' ? Routes.loan(context, o.refId) : Routes.bill(context, o.refId);
      } else {
        Routes.pay(context, kind: o.kind, id: o.refId, due: o.dueDate);
      }
    }

    final title = compact && o.installment != null ? 'EMI #${o.installment}' : '${o.name}${o.kind == 'loan' ? ' EMI' : ''}';
    final when = o.status == OccStatus.paid ? 'Paid ${fmtShort(o.payment!.paidOn)}' : dueLabel(o.daysLeft);
    return ScalePress(
      onTap: open,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            IconBadge(icon: o.icon, color: hex(o.color)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  T(title, maxLines: 1, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  T('${fmtShort(o.dueDate)} · $when${compact ? '' : ' · ${o.subtitle}'}', v: TV.caption, muted: true, maxLines: 1),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                T(formatMoney(o.amount, currency), style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Pill(label: st.label, color: st.color),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
