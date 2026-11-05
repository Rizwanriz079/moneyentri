import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/categories.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../widgets/form_scaffold.dart';
import '../widgets/ui.dart';

/// Monthly budget plus optional per-category limits.
class BudgetFormScreen extends StatefulWidget {
  const BudgetFormScreen({super.key});

  @override
  State<BudgetFormScreen> createState() => _BudgetFormScreenState();
}

class _BudgetFormScreenState extends State<BudgetFormScreen> {
  late String monthly;
  late Map<String, String> limits;

  @override
  void initState() {
    super.initState();
    final b = context.read<AppStore>().budget;
    monthly = b.monthly > 0 ? numText(b.monthly) : '';
    limits = b.categories.map((k, v) => MapEntry(k, numText(v)));
  }

  Map<String, double> get _parsed => {
    for (final e in limits.entries)
      if (parseAmount(e.value) > 0) e.key: parseAmount(e.value),
  };

  Future<void> _save() async {
    final currency = context.read<AppStore>().settings.currency;
    final parsed = _parsed;
    final allocated = parsed.values.fold(0.0, (a, v) => a + v);
    final m = parseAmount(monthly).isNaN ? 0.0 : parseAmount(monthly);
    if (m > 0 && allocated > m) {
      final ok = await confirmDialog(
        context,
        title: 'Limits exceed the monthly budget',
        message:
            'Category limits add up to ${formatMoney(allocated, currency)}, which is more than your ${formatMoney(m, currency)} budget. Save anyway?',
        confirm: 'Save',
        cancel: 'Edit',
        destructive: false,
      );
      if (!ok) return;
    }
    if (!mounted) return;
    context.read<AppStore>().setBudget(Budget(monthly: m, categories: parsed));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final currency = context.select<AppStore, String>((s) => s.settings.currency);
    final allocated = _parsed.values.fold(0.0, (a, v) => a + v);
    final m = parseAmount(monthly).isNaN ? 0.0 : parseAmount(monthly);

    return FormScaffold(
      title: 'Budgets',
      subtitle: 'Monthly budget and category limits',
      footer: AppButton(title: 'Save budget', icon: 'checkmark', onTap: _save),
      children: [
        Field(
          label: 'Monthly budget',
          child: AmountInput(value: monthly, onChanged: (v) => setState(() => monthly = v), symbol: currencySymbol(currency)),
        ),
        if (m > 0)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Flexible(child: T('Allocated to categories', v: TV.caption, muted: true)),
              const SizedBox(width: 8),
              Flexible(
                child: T(
                  '${formatMoney(allocated, currency)} / ${formatMoney(m, currency)}',
                  v: TV.caption,
                  align: TextAlign.end,
                  color: allocated > m ? c.expense : c.textMuted,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const T('Category limits', v: TV.h3),
              const SizedBox(height: 4),
              const T('Leave empty for no limit.', v: TV.caption, muted: true),
              const SizedBox(height: 8),
              for (var i = 0; i < expenseCategories.length; i++) ...[
                if (i > 0) const HairDivider(),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      IconBadge(icon: expenseCategories[i].icon, color: hex(expenseCategories[i].color), size: 34),
                      const SizedBox(width: 12),
                      Expanded(child: T(expenseCategories[i].name, v: TV.label)),
                      SizedBox(
                        width: 120,
                        child: AppInput(
                          keyboard: const TextInputType.numberWithOptions(decimal: true),
                          placeholder: 'No limit',
                          textAlign: TextAlign.right,
                          value: limits[expenseCategories[i].id] ?? '',
                          onChanged: (v) => setState(() => limits[expenseCategories[i].id] = v),
                        ),
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
