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
import '../widgets/form_scaffold.dart';
import '../widgets/pickers.dart';
import '../widgets/animations.dart';
import '../widgets/ui.dart';

/// Add or edit an income / expense.
class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({super.key, this.id});
  final String? id;

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  Transaction? existing;
  String type = 'expense', amount = '', categoryId = 'food', method = 'upi', note = '';
  String date = todayISO();

  @override
  void initState() {
    super.initState();
    existing = widget.id == null ? null : context.read<AppStore>().transactions.where((t) => t.id == widget.id).firstOrNull;
    final e = existing;
    if (e != null) {
      type = e.type;
      amount = numText(e.amount);
      categoryId = e.categoryId;
      date = e.date;
      method = e.method;
      note = e.note;
    }
  }

  bool get linked => existing?.link != null;

  /// Live budget hint for expenses in the chosen category's month.
  String? _hint(AppStore s, double value) {
    if (type != 'expense' || !(value > 0)) return null;
    final limit = s.budget.categories[categoryId];
    if (limit == null || limit <= 0) return null;
    final monthTx = inMonth(s.transactions, monthKey(date)).where((t) => t.id != widget.id);
    final used = (spendByCategory(monthTx)[categoryId] ?? 0) + value;
    if (used <= limit * 0.85) return null;
    final name = getCategory(categoryId).name;
    final currency = s.settings.currency;
    return used > limit
        ? 'This takes $name over its ${formatMoney(limit, currency)} limit by ${formatMoney(used - limit, currency)}.'
        : '$name will be at ${(used / limit * 100).round()}% of its monthly limit.';
  }

  void _switchType(String t) => setState(() {
    type = t;
    if (!categoriesFor(t).any((c) => c.id == categoryId)) categoryId = categoriesFor(t).first.id;
  });

  bool _saving = false;

  Future<void> _save() async {
    if (_saving) return;
    final value = parseAmount(amount);
    if (!(value > 0)) {
      infoDialog(context, 'Enter an amount', 'The amount must be greater than zero.');
      return;
    }
    final s = context.read<AppStore>();
    _saving = true;
    FocusScope.of(context).unfocus();
    if (existing != null) {
      s.updateTransaction(existing!.id, type: type, amount: value, categoryId: categoryId, date: date, method: method, note: note.trim());
    } else {
      s.addTransaction(type: type, amount: value, categoryId: categoryId, date: date, method: method, note: note.trim());
      final c = context.colors;
      await showSuccessAnimation(
        context,
        title: type == 'income' ? 'Income added' : 'Expense added',
        subtitle: formatSigned(value, s.settings.currency, income: type == 'income'),
        color: type == 'income' ? c.income : c.expense,
      );
    }
    if (mounted) Navigator.pop(context);
  }

  Future<void> _remove() async {
    final ok = await confirmDialog(
      context,
      title: 'Delete transaction?',
      message: linked ? 'This will also mark the linked EMI/bill installment as pending again.' : 'This cannot be undone.',
    );
    if (!ok || !mounted) return;
    context.read<AppStore>().deleteTransaction(existing!.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final s = context.watch<AppStore>();
    final currency = s.settings.currency;
    final hint = _hint(s, parseAmount(amount));
    final accent = type == 'income' ? c.income : c.expense;
    final link = existing?.link;

    return FormScaffold(
      title: existing != null ? 'Edit transaction' : 'Add transaction',
      actions: [
        if (existing != null) AppIconButton(icon: 'trash-outline', color: c.expense, bg: c.expenseSoft, onTap: _remove, tooltip: 'Delete'),
      ],
      footer: AppButton(
        title: existing != null ? 'Save changes' : 'Add $type',
        icon: 'checkmark',
        variant: type == 'income' ? BtnVariant.success : BtnVariant.primary,
        onTap: _save,
      ),
      children: [
        if (link != null)
          AppCard(
            color: c.primarySoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(appIcon('link'), size: 18, color: c.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: T(
                        'Recorded from a ${link.kind == 'loan' ? 'loan EMI' : 'bill'} payment. Amount and category are managed from the '
                        '${link.kind} screen; date, method and note stay in sync.',
                        v: TV.caption,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                AppButton(
                  small: true,
                  expand: false,
                  variant: BtnVariant.ghost,
                  title: 'Open ${link.kind}',
                  icon: 'open-outline',
                  onTap: () => Routes.replaceWithItem(context, link.kind, link.refId),
                ),
              ],
            ),
          ),
        if (!linked)
          Segmented<String>(
            options: const [SegOption('expense', 'Expense'), SegOption('income', 'Income')],
            value: type,
            onChanged: _switchType,
            colorFor: (k) => k == 'income' ? c.income : c.expense,
          ),
        if (!linked)
          Center(
            // Previous design: WalletCoins(amount: …, income: type == 'income', color: accent)
            child: AmountJar(
              amount: parseAmount(amount).isNaN ? 0 : parseAmount(amount),
              color: accent,
              symbol: currencySymbol(currency),
            ),
          ),
        Opacity(
          opacity: linked ? 0.6 : 1,
          child: AmountInput(
            value: amount,
            onChanged: (v) => setState(() => amount = v),
            symbol: currencySymbol(currency),
            color: accent,
            autofocus: existing == null,
            enabled: !linked,
          ),
        ),
        if (hint != null)
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: c.warningSoft, borderRadius: BorderRadius.circular(AppRadius.md)),
            child: Row(
              children: [
                Icon(appIcon('warning'), size: 16, color: c.warning),
                const SizedBox(width: 8),
                Expanded(child: T(hint, v: TV.caption)),
              ],
            ),
          ),
        if (!linked)
          Field(
            label: 'Category',
            child: CategoryGrid(type: type, value: categoryId, onChanged: (id) => setState(() => categoryId = id)),
          ),
        Field(
          label: 'Date',
          child: DateField(value: date, onChanged: (d) => setState(() => date = d)),
        ),
        Field(
          label: 'Payment method',
          child: MethodPicker(value: method, onChanged: (m) => setState(() => method = m)),
        ),
        Field(
          label: 'Description',
          child: AppInput(
            icon: 'create-outline',
            placeholder: 'e.g. Lunch with team',
            value: note,
            onChanged: (v) => note = v,
            onSubmitted: _save,
          ),
        ),
      ],
    );
  }
}
