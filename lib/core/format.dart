import 'dart:math';

class Currency {
  const Currency(this.code, this.symbol, this.name);
  final String code, symbol, name;
}

const currencies = [
  Currency('INR', '₹', 'Indian Rupee'),
  Currency('USD', r'$', 'US Dollar'),
  Currency('EUR', '€', 'Euro'),
  Currency('GBP', '£', 'British Pound'),
  Currency('AED', 'AED ', 'UAE Dirham'),
  Currency('SGD', r'S$', 'Singapore Dollar'),
  Currency('AUD', r'A$', 'Australian Dollar'),
  Currency('CAD', r'C$', 'Canadian Dollar'),
  Currency('JPY', '¥', 'Japanese Yen'),
];

String currencySymbol(String code) => currencies.firstWhere((c) => c.code == code, orElse: () => currencies.first).symbol;

/// Group digits: Indian style (12,34,567) for INR, western (1,234,567) otherwise.
String _group(String intPart, bool indian) {
  if (!indian) {
    return intPart.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  }
  if (intPart.length <= 3) return intPart;
  final last3 = intPart.substring(intPart.length - 3);
  final rest = intPart.substring(0, intPart.length - 3).replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (_) => ',');
  return '$rest,$last3';
}

double round2(num n) => (n * 100).roundToDouble() / 100;

String formatMoney(num value, String currency, {bool sign = false}) {
  final neg = value < 0;
  final abs = value.abs();
  final whole = round2(abs) == round2(abs).truncateToDouble();
  final noDecimals = currency == 'JPY' || whole;
  final fixed = abs.toStringAsFixed(noDecimals ? 0 : 2);
  final parts = fixed.split('.');
  final body = '${currencySymbol(currency)}${_group(parts[0], currency == 'INR')}${parts.length > 1 ? '.${parts[1]}' : ''}';
  if (neg) return '- $body';
  return sign ? '+ $body' : body;
}

/// Amount with an explicit sign and a space after it: "+ ₹5,000" for
/// income, "- ₹554" for an expense.
String formatSigned(num amount, String currency, {required bool income}) =>
    '${income ? '+' : '-'} ${formatMoney(amount.abs(), currency)}';

/// Compact labels for charts: ₹1.2K, ₹3.4L, ₹1.1Cr / $1.2K, $3.4M
String formatCompact(num value, String currency) {
  final s = currencySymbol(currency);
  final abs = value.abs();
  final sign = value < 0 ? '- ' : '';
  String trim(num n) => n >= 100 ? n.toStringAsFixed(0) : n.toStringAsFixed(1).replaceAll(RegExp(r'\.0$'), '');
  if (currency == 'INR') {
    if (abs >= 1e7) return '$sign$s${trim(abs / 1e7)}Cr';
    if (abs >= 1e5) return '$sign$s${trim(abs / 1e5)}L';
  } else {
    if (abs >= 1e9) return '$sign$s${trim(abs / 1e9)}B';
    if (abs >= 1e6) return '$sign$s${trim(abs / 1e6)}M';
  }
  if (abs >= 1e3) return '$sign$s${trim(abs / 1e3)}K';
  return '$sign$s${abs.round()}';
}

/// Parse a user-typed amount ("12,500.50"). Returns NaN when empty/invalid.
double parseAmount(String text) {
  final cleaned = text.replaceAll(RegExp(r'[^0-9.]'), '');
  if (cleaned.isEmpty) return double.nan;
  final v = double.tryParse(cleaned);
  return v == null ? double.nan : round2(v);
}

/// Display a number for an editable text field without a trailing ".0".
String numText(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

final _rand = Random();
String uid() => '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}${_rand.nextInt(1 << 30).toRadixString(36)}';
