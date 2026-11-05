import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/nav.dart';
import '../core/dates.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/store.dart';
import '../widgets/charts.dart';
import '../widgets/ui.dart';

class GoalDetailScreen extends StatefulWidget {
  const GoalDetailScreen({super.key, required this.id});
  final String id;

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  String mode = 'add';
  String amount = '', note = '';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.watch<AppStore>();
    final currency = s.settings.currency;
    final goal = s.goals.where((g) => g.id == widget.id).firstOrNull;

    if (goal == null) {
      return const Screen(
        header: AppHeader(title: 'Goal'),
        children: [EmptyState(icon: 'alert-circle-outline', title: 'Goal not found')],
      );
    }

    final saved = goal.saved;
    final left = max(0.0, goal.target - saved);
    final daysLeft = goal.deadline != null ? diffDays(todayISO(), goal.deadline!) : null;
    final perMonth = daysLeft != null && daysLeft > 0 && left > 0 ? left / max(1, (daysLeft / 30).ceil()) : 0.0;
    final color = hex(goal.color);
    final pct = goal.target > 0 ? saved / goal.target : 0.0;

    Future<void> submit() async {
      final v = parseAmount(amount);
      if (!(v > 0)) return infoDialog(context, 'Enter an amount');
      if (mode == 'withdraw' && v > saved) {
        return infoDialog(context, 'Not enough saved', 'You can withdraw up to ${formatMoney(saved, currency)}.');
      }
      s.addGoalEntry(goal.id, mode == 'add' ? v : -v, note.trim());
      setState(() {
        amount = '';
        note = '';
      });
      FocusScope.of(context).unfocus();
      if (mode == 'add' && saved < goal.target && saved + v >= goal.target) {
        await infoDialog(context, 'Goal achieved! 🎉', "You've reached your ${goal.name} target.");
      }
    }

    Future<void> remove() async {
      final ok = await confirmDialog(context, title: 'Delete goal?', message: 'All savings entries for this goal will be removed.');
      if (!ok || !context.mounted) return;
      final store = context.read<AppStore>();
      Navigator.pop(context);
      store.deleteGoal(goal.id);
    }

    Widget mini(String label, String value) => Expanded(
      child: Column(
        children: [
          T(label, v: TV.caption, muted: true),
          const SizedBox(height: 2),
          T(value, v: TV.label, style: const TextStyle(fontSize: 15)),
        ],
      ),
    );

    return Screen(
      header: AppHeader(
        title: goal.name,
        subtitle: goal.deadline != null ? 'Target ${fmtDate(goal.deadline!)}' : 'Savings goal',
        actions: [
          AppIconButton(
            icon: 'create-outline',
            onTap: () => Routes.goalForm(context, id: goal.id),
            tooltip: 'Edit',
          ),
          AppIconButton(icon: 'trash-outline', color: c.expense, onTap: remove, tooltip: 'Delete'),
        ],
      ),
      children: [
        AppCard(
          child: Column(
            children: [
              ProgressRing(
                progress: pct,
                color: color,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconBadge(icon: goal.icon, color: color, size: 40),
                    const SizedBox(height: 6),
                    T('${(pct * 100).round()}%', v: TV.h2),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              T(formatMoney(saved, currency), v: TV.h1),
              T('of ${formatMoney(goal.target, currency)}', v: TV.label, muted: true),
              const SizedBox(height: 16),
              Row(
                children: [
                  mini('Still needed', formatMoney(left, currency)),
                  mini('Days left', daysLeft == null ? '—' : (daysLeft < 0 ? 'Past due' : '$daysLeft')),
                  mini('Per month', perMonth > 0 ? formatMoney(perMonth.ceil(), currency) : '—'),
                ],
              ),
            ],
          ),
        ),
        AppCard(
          child: Column(
            children: gap([
              Segmented<String>(
                options: const [SegOption('add', 'Add money'), SegOption('withdraw', 'Withdraw')],
                value: mode,
                onChanged: (m) => setState(() => mode = m),
              ),
              AppInput(
                icon: 'cash-outline',
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                placeholder: 'Amount',
                value: amount,
                onChanged: (v) => amount = v,
              ),
              AppInput(icon: 'create-outline', placeholder: 'Note (optional)', value: note, onChanged: (v) => note = v),
              AppButton(
                title: mode == 'add' ? 'Add to savings' : 'Withdraw',
                icon: mode == 'add' ? 'add-circle' : 'remove-circle',
                variant: mode == 'add' ? BtnVariant.success : BtnVariant.danger,
                onTap: submit,
              ),
            ], 12),
          ),
        ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Activity'),
              if (goal.entries.isEmpty)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: T('No savings yet. Add your first contribution above.', v: TV.caption, muted: true),
                )
              else
                for (var i = 0; i < goal.entries.length; i++) ...[
                  if (i > 0) const HairDivider(),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              T(
                                goal.entries[i].note.isNotEmpty
                                    ? goal.entries[i].note
                                    : (goal.entries[i].amount > 0 ? 'Deposit' : 'Withdrawal'),
                                v: TV.label,
                              ),
                              T(fmtDate(goal.entries[i].date), v: TV.caption, muted: true),
                            ],
                          ),
                        ),
                        T(
                          formatMoney(goal.entries[i].amount, currency, sign: true),
                          v: TV.label,
                          color: goal.entries[i].amount > 0 ? c.income : c.expense,
                        ),
                      ],
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
