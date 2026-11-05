import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/dates.dart';
import '../core/format.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../data/categories.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../widgets/form_scaffold.dart';
import '../widgets/pickers.dart';
import '../widgets/ui.dart';

class GoalFormScreen extends StatefulWidget {
  const GoalFormScreen({super.key, this.id});
  final String? id;

  @override
  State<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends State<GoalFormScreen> {
  Goal? existing;
  String name = '', target = '', initial = '';
  String icon = goalIcons.first, color = goalColors.first;
  bool hasDeadline = true;
  String deadline = addMonthsClamped(todayISO(), 6);

  @override
  void initState() {
    super.initState();
    existing = widget.id == null ? null : context.read<AppStore>().goals.where((g) => g.id == widget.id).firstOrNull;
    final e = existing;
    if (e != null) {
      name = e.name;
      target = numText(e.target);
      icon = e.icon;
      color = e.color;
      hasDeadline = e.deadline != null;
      deadline = e.deadline ?? deadline;
    }
  }

  void _save() {
    final t = parseAmount(target);
    if (name.trim().isEmpty) {
      infoDialog(context, 'Name your goal', 'e.g. "Goa trip" or "Emergency fund".');
      return;
    }
    if (!(t > 0)) {
      infoDialog(context, 'Set a target', 'The target amount must be greater than zero.');
      return;
    }
    final s = context.read<AppStore>();
    if (existing != null) {
      s.updateGoal(
        existing!.id,
        (g) => g.copyWith(
          name: name.trim(),
          target: t,
          icon: icon,
          color: color,
          deadline: hasDeadline ? deadline : null,
          clearDeadline: !hasDeadline,
        ),
      );
    } else {
      final init = parseAmount(initial);
      s.addGoal(
        name: name.trim(),
        target: t,
        icon: icon,
        color: color,
        deadline: hasDeadline ? deadline : null,
        initial: init.isNaN ? 0 : init,
      );
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final currency = context.select<AppStore, String>((s) => s.settings.currency);
    final accent = hex(color);
    return FormScaffold(
      title: existing != null ? 'Edit goal' : 'New savings goal',
      footer: AppButton(title: existing != null ? 'Save changes' : 'Create goal', icon: 'checkmark', onTap: _save),
      children: [
        Field(
          label: 'Target amount',
          child: AmountInput(
            value: target,
            onChanged: (v) => target = v,
            symbol: currencySymbol(currency),
            color: accent,
            autofocus: existing == null,
          ),
        ),
        Field(
          label: 'Goal name',
          child: AppInput(icon: 'flag-outline', placeholder: 'e.g. Goa trip', value: name, onChanged: (v) => name = v),
        ),
        if (existing == null)
          Field(
            label: 'Already saved (optional)',
            child: AppInput(
              icon: 'wallet-outline',
              keyboard: const TextInputType.numberWithOptions(decimal: true),
              placeholder: '0',
              value: initial,
              onChanged: (v) => initial = v,
            ),
          ),
        Field(
          label: 'Icon',
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final i in goalIcons)
                GestureDetector(
                  onTap: () {
                    haptic();
                    setState(() => icon = i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: icon == i ? tint(accent, 0.13) : c.card,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(color: icon == i ? accent : c.border, width: 1.5),
                    ),
                    child: Icon(appIcon(i), size: 22, color: icon == i ? accent : c.textMuted),
                  ),
                ),
            ],
          ),
        ),
        Field(
          label: 'Colour',
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final col in goalColors)
                GestureDetector(
                  onTap: () {
                    haptic();
                    setState(() => color = col);
                  },
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: hex(col),
                      shape: BoxShape.circle,
                      border: Border.all(color: color == col ? c.text : Colors.transparent, width: 3),
                    ),
                  ),
                ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            children: [
              ToggleRow(
                icon: 'calendar-outline',
                label: 'Target date',
                hint: 'See how much to save each month',
                value: hasDeadline,
                onChanged: (v) => setState(() => hasDeadline = v),
              ),
              if (hasDeadline) ...[
                const SizedBox(height: 10),
                DateField(value: deadline, minimumDate: todayISO(), onChanged: (d) => setState(() => deadline = d)),
              ],
            ],
          ),
        ),
        const T('Savings goals track money you set aside. They don’t change your transaction balance.', v: TV.caption, faint: true),
      ],
    );
  }
}
