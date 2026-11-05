import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app/nav.dart';
import '../core/dates.dart';
import '../core/format.dart';
import '../core/theme.dart';
import '../data/categories.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../widgets/rows.dart';
import '../widgets/ui.dart';

const _ranges = [('month', 'This month'), ('week', 'This week'), ('lastMonth', 'Last month'), ('90', 'Last 90 days'), ('all', 'All time')];

(String, String) _bounds(String r) {
  final t = todayISO();
  switch (r) {
    case 'week':
      return (startOfWeek(t), t);
    case 'month':
      return ('${monthKey(t)}-01', '${monthKey(t)}-31');
    case 'lastMonth':
      final k = shiftMonthKey(monthKey(t), -1);
      return ('$k-01', '$k-31');
    case '90':
      return (addDays(t, -89), t);
    default:
      return ('0000-01-01', '9999-12-31');
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String type = 'all';
  String range = 'month';
  String? cat;
  String q = '';

  Future<void> _confirmDelete(Transaction t) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete transaction?',
      message: t.link != null
          ? 'This expense was recorded from a ${t.link!.kind == 'loan' ? 'loan EMI' : 'bill'} payment. Deleting it will mark that installment as pending again.'
          : 'This cannot be undone.',
    );
    if (ok && mounted) context.read<AppStore>().deleteTransaction(t.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.watch<AppStore>();
    final currency = s.settings.currency;
    final (from, to) = _bounds(range);
    final needle = q.trim().toLowerCase();

    final filtered =
        s.transactions
            .where(
              (t) =>
                  (type == 'all' || t.type == type) &&
                  t.date.compareTo(from) >= 0 &&
                  t.date.compareTo(to) <= 0 &&
                  (cat == null || t.categoryId == cat) &&
                  (needle.isEmpty ||
                      t.note.toLowerCase().contains(needle) ||
                      getCategory(t.categoryId).name.toLowerCase().contains(needle) ||
                      numText(t.amount).contains(needle)),
            )
            .toList()
          ..sort((a, b) {
            final d = b.date.compareTo(a.date);
            return d != 0 ? d : b.createdAt.compareTo(a.createdAt);
          });

    final groups = <String, List<Transaction>>{};
    for (final t in filtered) {
      (groups[t.date] ??= []).add(t);
    }
    var inc = 0.0, exp = 0.0;
    for (final t in filtered) {
      t.isIncome ? inc += t.amount : exp += t.amount;
    }

    final cats = type == 'all'
        ? [...expenseCategories, ...incomeCategories.where((x) => x.id != 'gift_in' && x.id != 'other_in')]
        : categoriesFor(type);

    final items = <Widget>[
      const T('Transactions', v: TV.h1),
      const SizedBox(height: Space.md),
      AppInput(icon: 'search', placeholder: 'Search notes, categories or amounts', value: q, onChanged: (v) => setState(() => q = v)),
      const SizedBox(height: Space.md),
      Segmented<String>(
        options: const [SegOption('all', 'All'), SegOption('income', 'Income'), SegOption('expense', 'Expense')],
        value: type,
        onChanged: (k) => setState(() {
          type = k;
          cat = null;
        }),
      ),
      const SizedBox(height: Space.md),
      Row(
        children: [
          Expanded(
            child: SelectButton(
              icon: 'calendar-outline',
              label: _ranges.firstWhere((r) => r.$1 == range).$2,
              highlighted: range != 'month',
              onTap: () async {
                final o = await showOptionSheet<String>(
                  context,
                  title: 'Date range',
                  selected: range,
                  options: [for (final (k, label) in _ranges) SheetOption(k, label)],
                );
                if (o != null && mounted) setState(() => range = o.value);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SelectButton(
              icon: cat == null ? 'grid-outline' : getCategory(cat!).icon,
              iconColor: cat == null ? null : hex(getCategory(cat!).color),
              label: cat == null ? 'All categories' : getCategory(cat!).name,
              highlighted: cat != null,
              onTap: () async {
                final o = await showOptionSheet<String?>(
                  context,
                  title: 'Category',
                  selected: cat,
                  options: [
                    const SheetOption(null, 'All categories'),
                    for (final x in cats) SheetOption(x.id, x.name, icon: x.icon, color: hex(x.color)),
                  ],
                );
                if (o != null && mounted) setState(() => cat = o.value);
              },
            ),
          ),
        ],
      ),
      const SizedBox(height: Space.md),
      Row(
        children: [
          Expanded(
            child: _SumTile(label: 'Income', value: inc > 0 ? formatSigned(inc, currency, income: true) : formatMoney(0, currency), color: c.income, bg: c.incomeSoft),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SumTile(label: 'Expenses', value: exp > 0 ? formatSigned(exp, currency, income: false) : formatMoney(0, currency), color: c.expense, bg: c.expenseSoft),
          ),
        ],
      ),
      const SizedBox(height: Space.sm),
    ];

    for (final e in groups.entries) {
      final net = e.value.fold(0.0, (a, t) => a + (t.isIncome ? t.amount : -t.amount));
      items.add(
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(child: T('${fmtRelative(e.key)} · ${weekdayShort(e.key)}', v: TV.label, muted: true, maxLines: 1)),
              const SizedBox(width: 8),
              Flexible(
                child: T(
                  net == 0 ? formatMoney(0, currency) : formatMoney(net, currency, sign: true),
                  v: TV.caption,
                  faint: true,
                  maxLines: 1,
                  align: TextAlign.end,
                ),
              ),
            ],
          ),
        ),
      );
      for (final t in e.value) {
        items.add(TransactionRow(tx: t, showDate: false, onLongPress: () => _confirmDelete(t)));
      }
    }

    if (filtered.isEmpty) {
      items.add(
        EmptyState(
          icon: 'search',
          title: 'No transactions found',
          message: s.transactions.isNotEmpty ? 'Try a different filter or date range.' : 'Tap + to record your first transaction.',
          action: s.transactions.isNotEmpty ? null : 'Add transaction',
          onAction: () => Routes.transactionForm(context),
        ),
      );
    } else {
      items.add(
        const Padding(
          padding: EdgeInsets.only(top: 16),
          child: T('Tap to edit · long-press to delete', v: TV.caption, faint: true, align: TextAlign.center),
        ),
      );
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, tabBarSpace),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: items,
        ),
      ),
    );
  }
}

class _SumTile extends StatelessWidget {
  const _SumTile({required this.label, required this.value, required this.color, required this.bg});
  final String label, value;
  final Color color, bg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(AppRadius.md)),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        T(label, v: TV.caption, muted: true),
        T(value, v: TV.h3, color: color, maxLines: 1),
      ],
    ),
  );
}
