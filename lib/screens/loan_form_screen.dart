import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/categories.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../domain/schedule.dart';
import '../services/notification_service.dart';
import '../widgets/form_scaffold.dart';
import '../widgets/pickers.dart';
import '../widgets/ui.dart';

/// Add or edit a loan, with an EMI calculator and reminder settings.
class LoanFormScreen extends StatefulWidget {
  const LoanFormScreen({super.key, this.id});
  final String? id;

  @override
  State<LoanFormScreen> createState() => _LoanFormScreenState();
}

class _LoanFormScreenState extends State<LoanFormScreen> {
  Loan? existing;
  bool hasPayments = false;
  String type = 'car', name = '', bank = '', total = '', balance = '', emi = '', rate = '', tenure = '';
  String startDate = addMonthsClamped(todayISO(), 1);
  bool remindersOn = true;
  List<int> offsets = defaultReminderOffsets;

  @override
  void initState() {
    super.initState();
    final s = context.read<AppStore>();
    existing = widget.id == null ? null : s.loans.where((l) => l.id == widget.id).firstOrNull;
    hasPayments = widget.id != null && s.payments.any((p) => p.kind == 'loan' && p.refId == widget.id);
    final e = existing;
    if (e != null) {
      type = e.type;
      name = e.name;
      bank = e.bank;
      total = numText(e.totalAmount);
      balance = numText(e.openingBalance);
      emi = numText(e.emi);
      rate = numText(e.interestRate);
      tenure = '${e.tenureMonths}';
      startDate = e.startDate;
      remindersOn = e.reminders.enabled;
      offsets = e.reminders.offsets;
    }
  }

  Future<void> _save() async {
    final nTotal = parseAmount(total);
    final nBalance = balance.isEmpty ? nTotal : parseAmount(balance);
    final nEmi = parseAmount(emi);
    final nRate = rate.isEmpty ? 0.0 : (double.tryParse(rate) ?? double.nan);
    final nTenure = int.tryParse(tenure) ?? 0;

    final errors = <String>[
      if (name.trim().isEmpty) 'Loan name',
      if (!(nTotal > 0)) 'Total loan amount',
      if (!(nEmi > 0)) 'EMI amount',
      if (nTenure <= 0) 'Tenure in months',
      if (nRate.isNaN || nRate < 0 || nRate > 60) 'Interest rate (0–60%)',
      if (!(nBalance > 0) || nBalance > nTotal * 1.5) 'Remaining balance',
    ];
    if (errors.isNotEmpty) {
      await infoDialog(context, 'Please check these fields', errors.join('\n'));
      return;
    }

    final s = context.read<AppStore>();
    final reminders = ReminderConfig(enabled: remindersOn, paused: existing?.reminders.paused ?? false, offsets: offsets);
    if (existing != null) {
      s.updateLoan(
        existing!.id,
        (l) => l.copyWith(
          type: type,
          name: name.trim(),
          bank: bank.trim(),
          totalAmount: nTotal,
          openingBalance: round2(nBalance),
          emi: nEmi,
          interestRate: nRate,
          startDate: startDate,
          tenureMonths: nTenure,
          reminders: reminders,
        ),
      );
    } else {
      s.addLoan(
        Loan(
          id: uid(),
          name: name.trim(),
          type: type,
          bank: bank.trim(),
          totalAmount: nTotal,
          openingBalance: round2(nBalance),
          emi: nEmi,
          interestRate: nRate,
          startDate: startDate,
          tenureMonths: nTenure,
          reminders: reminders,
          trackingFrom: startDate,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    }

    if (remindersOn && offsets.isNotEmpty) {
      final perm = await NotificationService.instance.requestPermission();
      if (perm == NotifPermission.denied && mounted) {
        await infoDialog(
          context,
          'Notifications are blocked',
          'Your loan was saved. Enable notifications for FinTrack in system settings to receive EMI reminders.',
        );
      }
      if (mounted) NotificationService.instance.sync(context.read<AppStore>());
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final currency = context.select<AppStore, String>((s) => s.settings.currency);
    final sym = currencySymbol(currency).trim();
    final nTotal = parseAmount(total);
    final nEmi = parseAmount(emi);
    final nRate = double.tryParse(rate) ?? 0;
    final nTenure = int.tryParse(tenure) ?? 0;
    final suggested = calcEmi(nTotal, nRate, nTenure);
    final lastEmi = nTenure > 0 ? addMonthsClamped(startDate, nTenure - 1) : null;

    Widget half(String label, Widget child) => Expanded(
      child: Field(label: label, child: child),
    );

    return FormScaffold(
      title: existing != null ? 'Edit loan' : 'Add loan',
      subtitle: 'Track EMIs and remaining balance',
      footer: AppButton(title: existing != null ? 'Save changes' : 'Add loan', icon: 'checkmark', onTap: _save),
      children: [
        Field(
          label: 'Loan type',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in loanTypes)
                AppChip(
                  label: t.name,
                  icon: t.icon,
                  color: hex(t.color),
                  active: type == t.id,
                  onTap: () => setState(() {
                    type = t.id;
                    if (name.isEmpty || loanTypes.any((x) => x.name == name)) name = t.name;
                  }),
                ),
            ],
          ),
        ),
        Field(
          label: 'Loan name',
          child: AppInput(icon: 'pricetag-outline', placeholder: 'e.g. Car Loan', value: name, onChanged: (v) => name = v),
        ),
        Field(
          label: 'Bank / lender',
          child: AppInput(icon: 'business-outline', placeholder: 'e.g. HDFC Bank', value: bank, onChanged: (v) => bank = v),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            half(
              'Total loan ($sym)',
              AppInput(
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                placeholder: '500000',
                value: total,
                onChanged: (v) => setState(() => total = v),
              ),
            ),
            const SizedBox(width: 12),
            half(
              'Remaining ($sym)',
              AppInput(
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                placeholder: total.isNotEmpty ? total : 'Same as total',
                value: balance,
                enabled: !hasPayments,
                onChanged: (v) => balance = v,
              ),
            ),
          ],
        ),
        if (hasPayments) const T('The remaining balance is now calculated from your recorded payments.', v: TV.caption, faint: true),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            half(
              'Interest rate (% p.a.)',
              AppInput(
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                placeholder: '9.5',
                value: rate,
                onChanged: (v) => setState(() => rate = v),
              ),
            ),
            const SizedBox(width: 12),
            half(
              'Tenure (months)',
              AppInput(keyboard: TextInputType.number, placeholder: '60', value: tenure, onChanged: (v) => setState(() => tenure = v)),
            ),
          ],
        ),
        Field(
          label: 'Monthly EMI ($sym)',
          child: AppInput(
            keyboard: const TextInputType.numberWithOptions(decimal: true),
            placeholder: '12500',
            value: emi,
            onChanged: (v) => setState(() => emi = v),
          ),
        ),
        if (suggested > 0 && (suggested - (nEmi.isNaN ? 0 : nEmi)).abs() > 1)
          GestureDetector(
            onTap: () => setState(() => emi = numText(suggested)),
            child: T(
              'Calculated EMI: ${formatMoney(suggested, currency)} · tap to use',
              v: TV.caption,
              color: c.primary,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        Field(
          label: 'First EMI date',
          hint: lastEmi != null ? 'EMIs repeat monthly on this day until ${fmtDate(lastEmi)}.' : 'EMIs repeat monthly on this day.',
          child: DateField(value: startDate, onChanged: (d) => setState(() => startDate = d)),
        ),
        AppCard(
          child: Column(
            children: [
              ToggleRow(
                icon: 'notifications-outline',
                label: 'EMI reminders',
                hint: 'Local notifications before each due date',
                value: remindersOn,
                onChanged: (v) => setState(() => remindersOn = v),
              ),
              if (remindersOn) ...[
                const SizedBox(height: 10),
                ReminderOffsets(value: offsets, onChanged: (v) => setState(() => offsets = v)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
