import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/categories.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../services/notification_service.dart';
import '../widgets/form_scaffold.dart';
import '../widgets/pickers.dart';
import '../widgets/ui.dart';

/// Add or edit a recurring bill.
class BillFormScreen extends StatefulWidget {
  const BillFormScreen({super.key, this.id});
  final String? id;

  @override
  State<BillFormScreen> createState() => _BillFormScreenState();
}

class _BillFormScreenState extends State<BillFormScreen> {
  Bill? existing;
  String category = 'electricity', name = '', amount = '', frequency = 'monthly', note = '';
  String startDate = addDays(todayISO(), 7);
  bool hasEnd = false;
  String endDate = addDays(todayISO(), 365);
  bool remindersOn = true;
  List<int> offsets = const [3, 1, 0];

  @override
  void initState() {
    super.initState();
    existing = widget.id == null ? null : context.read<AppStore>().bills.where((b) => b.id == widget.id).firstOrNull;
    final e = existing;
    if (e != null) {
      category = e.category;
      name = e.name;
      amount = numText(e.amount);
      frequency = e.frequency;
      startDate = e.startDate;
      hasEnd = e.endDate != null;
      endDate = e.endDate ?? endDate;
      remindersOn = e.reminders.enabled;
      offsets = e.reminders.offsets;
      note = e.note;
    }
  }

  Future<void> _save() async {
    final value = parseAmount(amount);
    if (name.trim().isEmpty) return infoDialog(context, 'Add a name', 'Give this bill a name, e.g. "Electricity".');
    if (!(value > 0)) return infoDialog(context, 'Enter an amount', 'The amount must be greater than zero.');
    if (hasEnd && endDate.compareTo(startDate) < 0) {
      return infoDialog(context, 'Check the end date', 'The end date must be after the first due date.');
    }
    final s = context.read<AppStore>();
    final reminders = ReminderConfig(enabled: remindersOn, paused: existing?.reminders.paused ?? false, offsets: offsets);
    if (existing != null) {
      s.updateBill(
        existing!.id,
        (b) => b.copyWith(
          name: name.trim(),
          category: category,
          amount: value,
          frequency: frequency,
          startDate: startDate,
          endDate: hasEnd ? endDate : null,
          clearEnd: !hasEnd,
          reminders: reminders,
          note: note.trim(),
        ),
      );
    } else {
      s.addBill(
        Bill(
          id: uid(),
          name: name.trim(),
          category: category,
          amount: value,
          frequency: frequency,
          startDate: startDate,
          endDate: hasEnd ? endDate : null,
          reminders: reminders,
          trackingFrom: startDate,
          note: note.trim(),
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
          'Your bill was saved. Enable notifications for FinTrack in system settings to get reminders.',
        );
      }
      if (mounted) NotificationService.instance.sync(context.read<AppStore>());
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final currency = context.select<AppStore, String>((s) => s.settings.currency);
    return FormScaffold(
      title: existing != null ? 'Edit bill' : 'Add bill',
      subtitle: 'Recurring payment with reminders',
      footer: AppButton(title: existing != null ? 'Save changes' : 'Add bill', icon: 'checkmark', onTap: _save),
      children: [
        Field(
          label: 'Type',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final b in billCategories)
                AppChip(
                  label: b.name,
                  icon: b.icon,
                  color: hex(b.color),
                  active: category == b.id,
                  onTap: () => setState(() {
                    category = b.id;
                    if (name.isEmpty || billCategories.any((x) => x.name == name)) name = b.name;
                  }),
                ),
            ],
          ),
        ),
        AmountInput(value: amount, onChanged: (v) => amount = v, symbol: currencySymbol(currency)),
        Field(
          label: 'Name',
          child: AppInput(
            icon: 'pricetag-outline',
            placeholder: 'e.g. Electricity, Netflix, Rent',
            value: name,
            onChanged: (v) => name = v,
          ),
        ),
        Field(
          label: 'Repeats',
          child: Segmented<String>(
            options: const [
              SegOption('weekly', 'Weekly'),
              SegOption('monthly', 'Monthly'),
              SegOption('quarterly', 'Quarterly'),
              SegOption('yearly', 'Yearly'),
            ],
            value: frequency,
            onChanged: (f) => setState(() => frequency = f),
          ),
        ),
        Field(
          label: 'Next due date',
          hint: 'Future due dates repeat from this date.',
          child: DateField(value: startDate, onChanged: (d) => setState(() => startDate = d)),
        ),
        AppCard(
          child: Column(
            children: [
              ToggleRow(
                icon: 'flag-outline',
                label: 'Ends on a date',
                hint: 'e.g. a fixed-term plan',
                value: hasEnd,
                onChanged: (v) => setState(() => hasEnd = v),
              ),
              if (hasEnd) ...[
                const SizedBox(height: 10),
                DateField(value: endDate, minimumDate: startDate, onChanged: (d) => setState(() => endDate = d)),
              ],
            ],
          ),
        ),
        AppCard(
          child: Column(
            children: [
              ToggleRow(
                icon: 'notifications-outline',
                label: 'Reminders',
                hint: 'Notify me before the deadline',
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
        Field(
          label: 'Note (optional)',
          child: AppInput(icon: 'create-outline', placeholder: 'Account number, provider…', value: note, onChanged: (v) => note = v),
        ),
      ],
    );
  }
}
