import 'dart:math';

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
import '../domain/analytics.dart';
import '../widgets/charts.dart';
import '../widgets/ui.dart';

class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<TabNav>();
    return Screen(
      tabs: true,
      children: [
        const T('Insights', v: TV.h1),
        Segmented<String>(
          options: const [SegOption('analytics', 'Analytics'), SegOption('budgets', 'Budgets'), SegOption('goals', 'Goals')],
          value: nav.insightsTab,
          onChanged: nav.insights,
        ),
        ...switch (nav.insightsTab) {
          'budgets' => _budgets(context),
          'goals' => _goals(context),
          _ => [const _Analytics()],
        },
      ],
    );
  }
}

// ───────────────────────── Analytics ─────────────────────────

class _Analytics extends StatefulWidget {
  const _Analytics();

  @override
  State<_Analytics> createState() => _AnalyticsState();
}

class _AnalyticsState extends State<_Analytics> {
  String mode = 'monthly';
  String month = monthKey(todayISO());
  String weekStart = startOfWeek(todayISO());

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.watch<AppStore>();
    final txs = s.transactions;
    final currency = s.settings.currency;
    final today = todayISO();

    late List<Transaction> cur;
    late Totals t, p;
    late int days;
    late String label, prevLabel;
    if (mode == 'monthly') {
      cur = inMonth(txs, month);
      final isCurrent = month == monthKey(today);
      final day = today.substring(8);
      // For the month in progress, compare with last month up to the same day.
      final prev = inMonth(txs, shiftMonthKey(month, -1)).where((x) => !isCurrent || x.date.substring(8).compareTo(day) <= 0);
      final first = parseISO('$month-01');
      days = isCurrent ? int.parse(day) : daysInMonth(first.year, first.month);
      t = totals(cur);
      p = totals(prev);
      label = monthLabel(month, long: true);
      prevLabel = isCurrent ? 'the same period last month' : 'the previous month';
    } else {
      final end = addDays(weekStart, 6);
      cur = inRange(txs, weekStart, end);
      days = (diffDays(weekStart, today) + 1).clamp(1, 7);
      // Week in progress: compare the same number of days of the previous week.
      final prev = inRange(txs, addDays(weekStart, -7), addDays(weekStart, days - 8));
      t = totals(cur);
      p = totals(prev);
      label = '${fmtShort(weekStart)} – ${fmtShort(end)}';
      prevLabel = days < 7 ? 'the same days last week' : 'the previous week';
    }

    final slices = topSlices(categorySlices(cur), otherColor: '#94A3B8');
    final change = pctChange(t.expense, p.expense);
    final atEnd = mode == 'monthly' ? month.compareTo(monthKey(today)) >= 0 : weekStart.compareTo(startOfWeek(today)) >= 0;
    void shift(int n) => setState(() {
      if (mode == 'monthly') {
        month = shiftMonthKey(month, n);
      } else {
        weekStart = addDays(weekStart, 7 * n);
      }
    });
    final periodKey = ValueKey('$mode|$month|$weekStart|${txs.length}');

    return Column(
      children: gap([
        Segmented<String>(
          options: const [SegOption('monthly', 'Monthly report'), SegOption('weekly', 'Weekly report')],
          value: mode,
          onChanged: (m) => setState(() => mode = m),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppIconButton(icon: 'chevron-back', tooltip: 'Previous period', size: 36, onTap: () => shift(-1)),
            Expanded(child: T(label, v: TV.h3, align: TextAlign.center, maxLines: 1)),
            AppIconButton(
              icon: 'chevron-forward',
              tooltip: 'Next period',
              size: 36,
              color: atEnd ? c.textFaint : c.text,
              onTap: () {
                if (!atEnd) shift(1);
              },
            ),
          ],
        ),
        FadeIn(
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _Stat(label: 'Income', value: formatMoney(t.income, currency), color: c.income),
                    _Stat(label: 'Expenses', value: formatMoney(t.expense, currency), color: c.expense),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _Stat(label: 'Net', value: formatMoney(t.net, currency, sign: true)),
                    _Stat(label: 'Avg. daily spend', value: formatMoney((t.expense / days).round(), currency)),
                  ],
                ),
                if (p.expense > 0) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: change > 0 ? c.expenseSoft : c.incomeSoft,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Row(
                      children: [
                        Icon(appIcon(change > 0 ? 'trending-up' : 'trending-down'), size: 16, color: change > 0 ? c.expense : c.income),
                        const SizedBox(width: 6),
                        Expanded(
                          child: T(
                            'You spent ${change.abs().toStringAsFixed(0)}% ${change > 0 ? 'more' : 'less'} than $prevLabel (${formatMoney(p.expense, currency)})',
                            v: TV.caption,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (mode == 'monthly')
          FadeIn(
            index: 1,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Income vs expenses'),
                  const T('Last 6 months · tap a month for details', v: TV.caption, muted: true),
                  const SizedBox(height: 12),
                  GroupedBarChart(
                    key: periodKey,
                    data: monthlySeries(txs, endKey: month),
                    currency: currency,
                    labels: ('Income', 'Expenses'),
                    colors: (c.chartIncome, c.chartExpense),
                  ),
                ],
              ),
            ),
          )
        else
          FadeIn(
            index: 1,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Daily spending'),
                  T(label, v: TV.caption, muted: true),
                  const SizedBox(height: 12),
                  BarChart(
                    key: periodKey,
                    data: dailySpend(txs, end: addDays(weekStart, 6)),
                    color: c.chartExpense,
                    currency: currency,
                  ),
                ],
              ),
            ),
          ),
        FadeIn(
          index: 2,
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SectionHeader(title: 'Spending by category'),
                T(label, v: TV.caption, muted: true),
                const SizedBox(height: 12),
                if (slices.isNotEmpty)
                  DonutChart(key: periodKey, slices: slices, currency: currency, centerLabel: 'Spent')
                else
                  const EmptyState(icon: 'pie-chart-outline', title: 'No expenses', message: 'Expenses for this period will appear here.'),
              ],
            ),
          ),
        ),
        if (mode == 'weekly')
          FadeIn(
            index: 3,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Weekly trend'),
                  const T('Total spent per week', v: TV.caption, muted: true),
                  const SizedBox(height: 12),
                  BarChart(key: ValueKey('weeks${txs.length}'), data: weeklySeries(txs), color: c.chartExpense, currency: currency),
                ],
              ),
            ),
          ),
      ], Space.lg),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});
  final String label, value;
  final Color? color;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        T(label, v: TV.caption, muted: true),
        const SizedBox(height: 2),
        T(value, v: TV.h3, color: color, maxLines: 1),
      ],
    ),
  );
}

// ───────────────────────── Budgets ─────────────────────────

List<Widget> _budgets(BuildContext context) {
  final c = context.colors;
  final s = context.watch<AppStore>();
  final currency = s.settings.currency;
  final budget = s.budget;
  final month = monthKey(todayISO());
  final monthTx = inMonth(s.transactions, month);
  final spent = totals(monthTx).expense;
  final byCat = spendByCategory(monthTx);
  final first = parseISO('$month-01');
  final daysLeft = daysInMonth(first.year, first.month) - int.parse(todayISO().substring(8)) + 1;
  final limits = budget.categories.entries.where((e) => e.value > 0).toList();
  final pct = budget.monthly > 0 ? spent / budget.monthly : 0.0;
  Color barColor(double p) => p > 1 ? c.expense : (p > 0.85 ? c.orange : c.income);

  if (budget.monthly <= 0 && limits.isEmpty) {
    return [
      AppCard(
        child: EmptyState(
          icon: 'wallet-outline',
          title: 'No budget yet',
          message: 'Set a monthly budget and category limits to keep your spending on track.',
          action: 'Set budget',
          onAction: () => Routes.budgetForm(context),
        ),
      ),
    ];
  }

  final rows = limits.map((e) => (id: e.key, limit: e.value, used: byCat[e.key] ?? 0.0)).toList()
    ..sort((a, b) => (b.used / b.limit).compareTo(a.used / a.limit));

  return [
    FadeIn(
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      T('${monthLabel(month, long: true)} budget', v: TV.caption, muted: true),
                      T(formatMoney(budget.monthly, currency), v: TV.h1),
                    ],
                  ),
                ),
                AppButton(
                  small: true,
                  expand: false,
                  variant: BtnVariant.secondary,
                  icon: 'create-outline',
                  title: 'Edit',
                  onTap: () => Routes.budgetForm(context),
                ),
              ],
            ),
            if (budget.monthly > 0) ...[
              const SizedBox(height: 14),
              ProgressBar(value: pct, color: barColor(pct), height: 12),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(child: T('Spent ${formatMoney(spent, currency)} (${(pct * 100).round()}%)', v: TV.caption, muted: true)),
                  T(
                    pct > 1
                        ? 'Over by ${formatMoney(spent - budget.monthly, currency)}'
                        : '${formatMoney(budget.monthly - spent, currency)} left',
                    v: TV.caption,
                    color: pct > 1 ? c.expense : c.textMuted,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              if (pct <= 1 && daysLeft > 0) ...[
                const SizedBox(height: 8),
                T(
                  'You can spend about ${formatMoney(((budget.monthly - spent) / daysLeft).floor(), currency)} per day for the next $daysLeft days.',
                  v: TV.caption,
                  faint: true,
                ),
              ],
            ],
          ],
        ),
      ),
    ),
    FadeIn(
      index: 1,
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(title: 'Category limits', action: 'Manage', onAction: () => Routes.budgetForm(context)),
            if (rows.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: T('No category limits yet. Tap Manage to add some.', v: TV.caption, muted: true),
              )
            else
              for (final r in rows)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Builder(
                    builder: (context) {
                      final cat = getCategory(r.id);
                      final p = r.used / r.limit;
                      return Column(
                        children: [
                          Row(
                            children: [
                              IconBadge(icon: cat.icon, color: hex(cat.color), size: 36),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    T(cat.name, v: TV.label),
                                    T('${formatMoney(r.used, currency)} of ${formatMoney(r.limit, currency)}', v: TV.caption, muted: true),
                                  ],
                                ),
                              ),
                              if (p > 1)
                                Pill(label: 'Over limit', color: c.expense)
                              else if (p > 0.85)
                                Pill(label: 'Near limit', color: c.orange)
                              else
                                Flexible(
                                  child: T(
                                    '${formatMoney(r.limit - r.used, currency)} left',
                                    v: TV.caption,
                                    muted: true,
                                    align: TextAlign.end,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ProgressBar(value: p, color: barColor(p)),
                        ],
                      );
                    },
                  ),
                ),
          ],
        ),
      ),
    ),
  ];
}

// ───────────────────────── Goals ─────────────────────────

List<Widget> _goals(BuildContext context) {
  final c = context.colors;
  final s = context.watch<AppStore>();
  final currency = s.settings.currency;
  final goals = s.goals;
  final saved = goals.fold(0.0, (a, g) => a + g.saved);
  final target = goals.fold(0.0, (a, g) => a + g.target);

  return [
    if (goals.isNotEmpty)
      FadeIn(
        child: AppCard(
          color: c.primary,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const T('Total saved', v: TV.caption, color: Color(0xBFFFFFFF)),
              T(formatMoney(saved, currency), v: TV.h1, color: Colors.white),
              const SizedBox(height: 12),
              ProgressBar(value: target > 0 ? saved / target : 0, color: Colors.white, track: Colors.white.withValues(alpha: 0.25)),
              const SizedBox(height: 6),
              T(
                '${target > 0 ? (saved / target * 100).round() : 0}% of ${formatMoney(target, currency)} across ${goals.length} goal${goals.length > 1 ? 's' : ''}',
                v: TV.caption,
                color: const Color(0xCCFFFFFF),
              ),
            ],
          ),
        ),
      ),
    for (var i = 0; i < goals.length; i++)
      FadeIn(
        index: i + 1,
        child: _GoalCard(goal: goals[i]),
      ),
    if (goals.isEmpty)
      AppCard(
        child: EmptyState(
          icon: 'flag-outline',
          title: 'No savings goals',
          message: 'Create a goal for a trip, a gadget or an emergency fund and track your progress.',
          action: 'Create goal',
          onAction: () => Routes.goalForm(context),
        ),
      )
    else
      AppButton(title: 'New savings goal', icon: 'add', variant: BtnVariant.secondary, onTap: () => Routes.goalForm(context)),
  ];
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});
  final Goal goal;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final currency = context.select<AppStore, String>((s) => s.settings.currency);
    final saved = goal.saved;
    final p = goal.target > 0 ? saved / goal.target : 0.0;
    final done = saved >= goal.target;
    final monthsLeft = goal.deadline != null ? max(1, (diffDays(todayISO(), goal.deadline!) / 30).ceil()) : 0;
    final perMonth = goal.deadline != null && !done ? (goal.target - saved) / monthsLeft : 0.0;
    final color = hex(goal.color);
    return AppCard(
      onTap: () => Routes.goal(context, goal.id),
      child: Column(
        children: [
          Row(
            children: [
              IconBadge(icon: goal.icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    T(goal.name, v: TV.h3, maxLines: 1),
                    T(goal.deadline != null ? 'Target date ${fmtDate(goal.deadline!)}' : 'No deadline', v: TV.caption, muted: true),
                  ],
                ),
              ),
              if (done) Pill(label: 'Achieved 🎉', color: c.income) else T('${(p * 100).round()}%', v: TV.h3),
            ],
          ),
          const SizedBox(height: 14),
          ProgressBar(value: p, color: color, height: 10),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: formatMoney(saved, currency),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      TextSpan(text: ' of ${formatMoney(goal.target, currency)}'),
                    ],
                  ),
                  style: textStyle(TV.caption).copyWith(color: c.text),
                ),
              ),
              if (perMonth > 0) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: T(
                    '${formatMoney(perMonth.ceil(), currency)}/month needed',
                    v: TV.caption,
                    muted: true,
                    align: TextAlign.end,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
