import '../core/dates.dart';
import '../data/categories.dart';
import '../data/models.dart';

class Totals {
  const Totals(this.income, this.expense);
  final double income, expense;
  double get net => income - expense;
}

Totals totals(Iterable<Transaction> txs) {
  var income = 0.0, expense = 0.0;
  for (final t in txs) {
    if (t.isIncome) {
      income += t.amount;
    } else {
      expense += t.amount;
    }
  }
  return Totals(income, expense);
}

List<Transaction> inMonth(List<Transaction> txs, String key) => txs.where((t) => monthKey(t.date) == key).toList();

List<Transaction> inRange(List<Transaction> txs, String from, String to) =>
    txs.where((t) => t.date.compareTo(from) >= 0 && t.date.compareTo(to) <= 0).toList();

Map<String, double> spendByCategory(Iterable<Transaction> txs) {
  final out = <String, double>{};
  for (final t in txs) {
    if (!t.isIncome) out[t.categoryId] = (out[t.categoryId] ?? 0) + t.amount;
  }
  return out;
}

/// A labelled value for the donut chart.
class Slice {
  const Slice(this.key, this.label, this.value, this.color);
  final String key, label, color;
  final double value;
}

List<Slice> categorySlices(Iterable<Transaction> txs) => spendByCategory(txs).entries.map((e) {
  final c = getCategory(e.key);
  return Slice(e.key, c.name, e.value, c.color);
}).toList();

/// Fold everything beyond the top [n] slices into a single "Other" slice.
List<Slice> topSlices(List<Slice> slices, {int n = 5, String otherColor = '#94A3B8'}) {
  final sorted = slices.where((s) => s.value > 0).toList()..sort((a, b) => b.value.compareTo(a.value));
  if (sorted.length <= n + 1) return sorted;
  final rest = sorted.skip(n).fold(0.0, (s, x) => s + x.value);
  return [...sorted.take(n), Slice('__other', 'Other', rest, otherColor)];
}

/// One bar in a single-series chart.
class BarDatum {
  const BarDatum(this.label, this.value, {this.title});
  final String label;
  final String? title;
  final double value;
}

/// One group in a two-series chart.
class PairDatum {
  const PairDatum(this.label, this.a, this.b, {this.title});
  final String label;
  final String? title;
  final double a, b;
}

/// Expense per day for the [n] days ending [end].
List<BarDatum> dailySpend(List<Transaction> txs, {int n = 7, String? end}) {
  end ??= todayISO();
  final map = <String, double>{};
  for (final t in txs) {
    if (!t.isIncome) map[t.date] = (map[t.date] ?? 0) + t.amount;
  }
  return [
    for (var i = 0; i < n; i++)
      () {
        final d = addDays(end!, i - n + 1);
        return BarDatum(weekdayShort(d).substring(0, 2), map[d] ?? 0, title: fmtShort(d));
      }(),
  ];
}

/// Income vs expense for the [n] months ending at [endKey].
List<PairDatum> monthlySeries(List<Transaction> txs, {int n = 6, String? endKey}) {
  endKey ??= monthKey(todayISO());
  return [
    for (var i = 0; i < n; i++)
      () {
        final key = shiftMonthKey(endKey!, i - n + 1);
        final t = totals(inMonth(txs, key));
        return PairDatum(shortMonth(key), t.income, t.expense, title: monthLabel(key));
      }(),
  ];
}

/// Weekly expense totals for the last [n] weeks (Monday-based).
List<BarDatum> weeklySeries(List<Transaction> txs, {int n = 6}) {
  final thisWeek = startOfWeek(todayISO());
  return [
    for (var i = 0; i < n; i++)
      () {
        final from = addDays(thisWeek, (i - n + 1) * 7);
        final to = addDays(from, 6);
        return BarDatum(fmtShort(from), totals(inRange(txs, from, to)).expense, title: 'Week of ${fmtShort(from)} – ${fmtShort(to)}');
      }(),
  ];
}

double pctChange(double now, double prev) => prev > 0 ? (now - prev) / prev * 100 : (now > 0 ? 100 : 0);
