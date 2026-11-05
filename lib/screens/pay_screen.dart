import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/format.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../data/categories.dart';
import '../data/store.dart';
import '../domain/schedule.dart';
import '../widgets/form_scaffold.dart';
import '../widgets/pickers.dart';
import '../widgets/rows.dart';
import '../widgets/animations.dart';
import '../widgets/ui.dart';

/// Record (or review / undo) the payment of one EMI or bill installment.
class PayScreen extends StatefulWidget {
  const PayScreen({super.key, required this.kind, required this.refId, required this.dueDate});
  final String kind, refId, dueDate;

  @override
  State<PayScreen> createState() => _PayScreenState();
}

class _PayScreenState extends State<PayScreen> {
  late String amount;
  String paidOn = todayISO();
  late String method = widget.kind == 'loan' ? 'bank' : 'upi';
  String note = '';

  @override
  void initState() {
    super.initState();
    final s = context.read<AppStore>();
    final loan = s.loans.where((l) => l.id == widget.refId).firstOrNull;
    final bill = s.bills.where((b) => b.id == widget.refId).firstOrNull;
    final initial = widget.kind == 'loan' ? (loan == null ? 0.0 : suggestedEmi(loan, s.payments)) : (bill?.amount ?? 0.0);
    amount = initial > 0 ? numText(initial) : '';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.watch<AppStore>();
    final currency = s.settings.currency;
    final occ = findOccurrence(s.loans, s.bills, s.payments, widget.kind, widget.refId, widget.dueDate);
    final loan = widget.kind == 'loan' ? s.loans.where((l) => l.id == widget.refId).firstOrNull : null;
    final bill = widget.kind == 'bill' ? s.bills.where((b) => b.id == widget.refId).firstOrNull : null;

    if (occ == null || (loan == null && bill == null)) {
      return const FormScaffold(
        title: 'Payment',
        children: [
          EmptyState(
            icon: 'alert-circle-outline',
            title: 'Installment not found',
            message: 'This payment may have been deleted or the loan is already closed.',
          ),
        ],
      );
    }

    final value = parseAmount(amount);
    final remaining = loan != null ? loanRemaining(loan, s.payments) : 0.0;
    final split = loan != null && value > 0 ? splitPayment(remaining, loan.interestRate, value) : null;
    final st = statusStyle(occ, c);
    final title = loan != null ? '${loan.name} EMI' : bill!.name;

    final header = AppCard(
      child: Column(
        children: [
          Row(
            children: [
              IconBadge(icon: occ.icon, color: hex(occ.color), size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    T(title, v: TV.h3),
                    T(
                      '${occ.subtitle}${occ.installment != null && loan != null ? ' · EMI ${occ.installment} of ${loan.tenureMonths}' : ''}',
                      v: TV.caption,
                      muted: true,
                    ),
                  ],
                ),
              ),
              Pill(label: st.label, color: st.color),
            ],
          ),
          const SizedBox(height: 12),
          const HairDivider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const T('Due date', v: TV.caption, muted: true),
              T(fmtLong(occ.dueDate), v: TV.label),
            ],
          ),
          if (occ.status != OccStatus.paid) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const T('Status', v: TV.caption, muted: true),
                T(dueLabel(occ.daysLeft), v: TV.label, color: occ.status == OccStatus.overdue ? c.expense : c.text),
              ],
            ),
          ],
        ],
      ),
    );

    if (occ.status == OccStatus.paid) {
      final p = occ.payment!;
      return FormScaffold(
        title: 'Payment details',
        footer: AppButton(
          title: 'Mark as pending',
          icon: 'arrow-undo',
          variant: BtnVariant.danger,
          onTap: () async {
            final ok = await confirmDialog(
              context,
              title: 'Mark as pending?',
              message: 'The payment record and its expense transaction will be removed.',
              confirm: 'Mark pending',
            );
            if (!ok || !context.mounted) return;
            context.read<AppStore>().revertPayment(p.id);
            Navigator.pop(context);
          },
        ),
        children: [
          header,
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(appIcon('checkmark-circle'), size: 22, color: c.income),
                    const SizedBox(width: 10),
                    T('Paid ${formatMoney(p.amount, currency)}', v: TV.h3),
                  ],
                ),
                const SizedBox(height: 12),
                DetailRow('Paid on', fmtLong(p.paidOn)),
                DetailRow('Method', methodName(p.method)),
                if (p.interest != null) DetailRow('Interest', formatMoney(p.interest!, currency)),
                if (p.principal != null) DetailRow('Principal', formatMoney(p.principal!, currency)),
                if (p.balanceAfter != null) DetailRow('Balance after', formatMoney(p.balanceAfter!, currency)),
              ],
            ),
          ),
        ],
      );
    }

    return FormScaffold(
      title: 'Record payment',
      footer: AppButton(
        title: 'Mark as paid',
        icon: 'checkmark-circle',
        variant: BtnVariant.success,
        disabled: !(value > 0),
        onTap: () async {
          final store = context.read<AppStore>();
          final res = store.recordPayment(
            kind: widget.kind,
            refId: widget.refId,
            dueDate: occ.dueDate,
            amount: value,
            paidOn: paidOn,
            method: method,
            note: note.trim().isEmpty ? null : note.trim(),
          );
          if (!res.ok) {
            infoDialog(context, 'Could not record payment', res.error);
            return;
          }
          FocusScope.of(context).unfocus();
          await showSuccessAnimation(
            context,
            title: 'Payment recorded',
            subtitle: formatMoney(value, store.settings.currency),
            color: context.colors.income,
          );
          if (context.mounted) Navigator.pop(context);
        },
      ),
      children: [
        header,
        AmountInput(value: amount, onChanged: (v) => setState(() => amount = v), symbol: currencySymbol(currency)),
        if (split != null && loan != null)
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const T('How this payment is applied', v: TV.label, muted: true),
                const SizedBox(height: 8),
                DetailRow(
                  'Interest (${numText(loan.interestRate)}% p.a. on ${formatMoney(remaining, currency)})',
                  formatMoney(split.interest, currency),
                ),
                DetailRow('Principal', formatMoney(split.principal, currency)),
                DetailRow('Balance after payment', formatMoney(round2(remaining - split.principal), currency), strong: true),
                if (value < split.interest)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: T(
                      'This amount doesn’t cover the month’s interest, so the balance won’t go down.',
                      v: TV.caption,
                      color: c.expense,
                    ),
                  ),
              ],
            ),
          ),
        Field(
          label: 'Paid on',
          child: DateField(value: paidOn, onChanged: (d) => setState(() => paidOn = d)),
        ),
        Field(
          label: 'Payment method',
          child: MethodPicker(value: method, onChanged: (m) => setState(() => method = m)),
        ),
        Field(
          label: 'Note (optional)',
          child: AppInput(icon: 'create-outline', placeholder: 'Reference number, remarks…', value: note, onChanged: (v) => note = v),
        ),
        const T('An expense of this amount will be added to your transactions automatically.', v: TV.caption, faint: true),
      ],
    );
  }
}
