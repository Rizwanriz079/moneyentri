import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/nav.dart';
import '../core/dates.dart';
import '../core/format.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../data/store.dart';
import '../domain/analytics.dart';
import '../domain/demo.dart';
import '../domain/schedule.dart';
import '../services/notification_service.dart';
import '../widgets/charts.dart';
import '../widgets/rows.dart';
import '../widgets/ui.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  NotifPermission perm = NotifPermission.granted;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshPerm();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPerm();
  }

  Future<void> _refreshPerm() async {
    final p = await NotificationService.instance.getPermission();
    if (mounted) setState(() => perm = p);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.watch<AppStore>();
    final nav = context.read<TabNav>();
    final currency = s.settings.currency;
    final txs = s.transactions;

    final month = monthKey(todayISO());
    final all = totals(txs);
    final cur = totals(inMonth(txs, month));
    // Compare like with like: last month up to the same day of the month.
    final day = todayISO().substring(8);
    final prevToDate = totals(
      inMonth(txs, shiftMonthKey(month, -1)).where((t) => t.date.substring(8).compareTo(day) <= 0),
    );
    final week = dailySpend(txs);
    final weekTotal = week.fold(0.0, (a, d) => a + d.value);
    final upcoming = upcomingPayments(s.loans, s.bills, s.payments);
    final dueTotal = upcoming.where((o) => o.status != OccStatus.paid).fold(0.0, (a, o) => a + o.amount);
    final hasReminders = s.loans.length + s.bills.length > 0;
    final isEmpty = txs.isEmpty && !hasReminders;
    final budget = s.budget;
    final spentPct = budget.monthly > 0 ? cur.expense / budget.monthly : 0.0;
    final change = pctChange(cur.expense, prevToDate.expense);
    final name = s.settings.name.trim();

    return Screen(
      tabs: true,
      children: [
        // Header
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  T(greeting(), v: TV.label, muted: true),
                  T('${name.isNotEmpty ? name.split(' ').first : 'Welcome'} 👋', v: TV.h1),
                ],
              ),
            ),
            Builder(
              builder: (context) {
                final dark = Theme.of(context).brightness == Brightness.dark;
                return AppIconButton(
                  icon: dark ? 'sunny-outline' : 'moon-outline',
                  tooltip: dark ? 'Switch to light theme' : 'Switch to dark theme',
                  size: 44,
                  bg: c.card,
                  onTap: () => s.updateSettings((x) => x.copyWith(theme: dark ? 'light' : 'dark')),
                );
              },
            ),
            const SizedBox(width: 10),
            Semantics(
              button: true,
              container: true,
              excludeSemantics: true,
              onTap: () => Routes.profile(context),
              label: 'Profile and settings',
              child: ScalePress(
                onTap: () => Routes.profile(context),
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(16)),
                  child: name.isNotEmpty
                      ? T(name[0].toUpperCase(), v: TV.h3, color: c.primary)
                      : Icon(appIcon('person'), size: 20, color: c.primary),
                ),
              ),
            ),
          ],
        ),

        // Balance hero
        FadeIn(
          child: GradientPanel(
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(right: -62, top: -62, child: _bubble(160, 0.08)),
                Positioned(right: 18, bottom: -82, child: _bubble(140, 0.06)),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const T('Total balance', v: TV.label, color: Color(0xBFFFFFFF)),
                    const SizedBox(height: 4),
                    FittedBox(
                      child: T(formatMoney(all.net, currency), v: TV.display, color: Colors.white),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      children: [
                        Expanded(
                          child: _HeroStat(
                            icon: 'arrow-down',
                            label: 'Income',
                            value: formatMoney(cur.income, currency),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _HeroStat(
                            icon: 'arrow-up',
                            label: 'Expenses',
                            value: formatMoney(cur.expense, currency),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    T(
                      'Income and expenses for ${monthLabel(month, long: true)}',
                      v: TV.caption,
                      color: const Color(0xB3FFFFFF),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        if (isEmpty)
          AppCard(
            child: Column(
              children: [
                const EmptyState(
                  icon: 'sparkles',
                  title: "Let's get started",
                  message: 'Add your first transaction with the + button, or load sample data to explore the app.',
                ),
                AppButton(
                  title: 'Load sample data',
                  icon: 'flask',
                  variant: BtnVariant.secondary,
                  onTap: () => s.replaceData(buildDemoData()),
                ),
              ],
            ),
          ),

        if (hasReminders && perm != NotifPermission.granted && perm != NotifPermission.unsupported)
          AppCard(
            color: c.warningSoft,
            child: Row(
              children: [
                Icon(appIcon('notifications-off'), size: 22, color: c.warning),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const T('Payment reminders are off', v: TV.label),
                      T(
                        perm == NotifPermission.denied
                            ? 'Enable notifications for FinTrack in system settings to get EMI and bill reminders.'
                            : 'Allow notifications to be reminded before EMIs and bills are due.',
                        v: TV.caption,
                        muted: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                AppButton(
                  small: true,
                  expand: false,
                  title: perm == NotifPermission.denied ? 'Settings' : 'Allow',
                  onTap: () async {
                    if (perm == NotifPermission.denied) {
                      await NotificationService.instance.openSettings();
                    } else {
                      final p = await NotificationService.instance.requestPermission();
                      if (mounted) setState(() => perm = p);
                      if (p == NotifPermission.granted && context.mounted) {
                        NotificationService.instance.sync(context.read<AppStore>());
                      }
                    }
                  },
                ),
              ],
            ),
          ),

        // Monthly summary
        FadeIn(
          index: 1,
          child: AppCard(
            onTap: () => nav.insights('budgets'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: T(monthLabel(month, long: true), v: TV.h3, maxLines: 1)),
                    if (prevToDate.expense > 0) ...[
                      const SizedBox(width: 8),
                      Icon(
                        appIcon(change > 0 ? 'trending-up' : 'trending-down'),
                        size: 16,
                        color: change > 0 ? c.expense : c.income,
                      ),
                      const SizedBox(width: 4),
                      Flexible(
                        child: T(
                          '${change.abs().toStringAsFixed(0)}% vs last month',
                          v: TV.caption,
                          maxLines: 1,
                          color: change > 0 ? c.expense : c.income,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _MiniStat(label: 'Spent', value: formatMoney(cur.expense, currency)),
                    _MiniStat(label: 'Saved', value: formatMoney(cur.net > 0 ? cur.net : 0, currency)),
                    _MiniStat(
                      label: 'Savings rate',
                      value: cur.income > 0 ? '${(cur.net / cur.income * 100).round().clamp(0, 100)}%' : '—',
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (budget.monthly > 0) ...[
                  ProgressBar(
                    value: spentPct,
                    color: spentPct > 1 ? c.expense : (spentPct > 0.85 ? c.orange : c.primary),
                  ),
                  const SizedBox(height: 6),
                  T(
                    spentPct > 1
                        ? 'Over budget by ${formatMoney(cur.expense - budget.monthly, currency)}'
                        : '${formatMoney(budget.monthly - cur.expense, currency)} left of ${formatMoney(budget.monthly, currency)} budget',
                    v: TV.caption,
                    muted: true,
                  ),
                ] else
                  T(
                    'Set a monthly budget →',
                    v: TV.caption,
                    color: c.primary,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
              ],
            ),
          ),
        ),

        // Upcoming payments
        FadeIn(
          index: 2,
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: 'Upcoming payments', action: 'See all', onAction: () => nav.payments('calendar')),
                if (upcoming.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  T('${formatMoney(dueTotal, currency)} due in the next 30 days', v: TV.caption, muted: true),
                  const SizedBox(height: 6),
                  for (final o in upcoming.take(5)) PaymentRow(o: o),
                ] else
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: AppButton(
                            small: true,
                            variant: BtnVariant.secondary,
                            icon: 'card-outline',
                            title: 'Add loan',
                            onTap: () => Routes.loanForm(context),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppButton(
                            small: true,
                            variant: BtnVariant.secondary,
                            icon: 'receipt-outline',
                            title: 'Add bill',
                            onTap: () => Routes.billForm(context),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),

        // Quick access
        FadeIn(
          index: 3,
          child: Row(
            children: gap(
              [
                _QuickTile(
                  icon: 'wallet',
                  label: 'Budgets',
                  color: const Color(0xFF6366F1),
                  onTap: () => nav.insights('budgets'),
                ),
                _QuickTile(
                  icon: 'flag',
                  label: 'Goals',
                  color: const Color(0xFF22C55E),
                  onTap: () => nav.insights('goals'),
                ),
                _QuickTile(
                  icon: 'card',
                  label: 'Loans',
                  color: const Color(0xFFEF4444),
                  onTap: () => nav.payments('loans'),
                ),
                _QuickTile(
                  icon: 'receipt',
                  label: 'Bills',
                  color: const Color(0xFFF59E0B),
                  onTap: () => nav.payments('bills'),
                ),
              ],
              10,
              horizontal: true,
            ),
          ),
        ),

        // Weekly chart
        FadeIn(
          index: 4,
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: 'Last 7 days', action: 'Analytics', onAction: () => nav.insights('analytics')),
                const SizedBox(height: 2),
                T('${formatMoney(weekTotal, currency)} spent this week', v: TV.caption, muted: true),
                const SizedBox(height: 12),
                if (weekTotal > 0)
                  BarChart(key: ValueKey(txs.length), data: week, color: c.chartExpense, currency: currency)
                else
                  const EmptyState(
                    icon: 'bar-chart-outline',
                    title: 'No spending this week',
                    message: 'Expenses from the last 7 days will show here.',
                  ),
              ],
            ),
          ),
        ),

        // Recent
        FadeIn(
          index: 5,
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionHeader(title: 'Recent transactions', action: 'See all', onAction: () => nav.go(1)),
                if (txs.isNotEmpty)
                  for (final t in txs.take(5)) TransactionRow(tx: t)
                else
                  const EmptyState(
                    icon: 'receipt-outline',
                    title: 'No transactions yet',
                    message: 'Tap + to add your first income or expense.',
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _bubble(double size, double opacity) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: opacity),
    ),
  );
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.icon, required this.label, required this.value});
  final String icon, label, value;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(appIcon(icon), size: 16, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              T(label, v: TV.caption, color: const Color(0xBFFFFFFF)),
              T(
                value,
                v: TV.label,
                color: Colors.white,
                maxLines: 1,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({required this.label, required this.value});
  final String label, value;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        T(label, v: TV.caption, muted: true),
        const SizedBox(height: 2),
        T(value, v: TV.h3, maxLines: 1),
      ],
    ),
  );
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({required this.icon, required this.label, required this.color, required this.onTap});
  final String icon, label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: ScalePress(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(color: context.colors.card, borderRadius: BorderRadius.circular(AppRadius.lg)),
        child: Column(
          children: [
            IconBadge(icon: icon, color: color, size: 42),
            const SizedBox(height: 8),
            T(
              label,
              v: TV.caption,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    ),
  );
}
