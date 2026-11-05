/// Dates are stored as local calendar strings: YYYY-MM-DD. String comparison
/// therefore matches chronological order.
library;

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _monthsLong = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

String _pad(int n) => n < 10 ? '0$n' : '$n';

String toISO(DateTime d) => '${d.year}-${_pad(d.month)}-${_pad(d.day)}';

/// Parse YYYY-MM-DD as a local date (midnight).
DateTime parseISO(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[0]), p.length > 1 ? int.parse(p[1]) : 1, p.length > 2 ? int.parse(p[2]) : 1);
}

String todayISO() => toISO(DateTime.now());

String addDays(String s, int n) {
  final d = parseISO(s);
  return toISO(DateTime(d.year, d.month, d.day + n));
}

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

/// Add months, keeping the preferred day and clamping it to the month length
/// (e.g. the 31st becomes the 30th in November).
String addMonthsClamped(String s, int n, [int? preferredDay]) {
  final d = parseISO(s);
  final day = preferredDay ?? d.day;
  final total = d.month - 1 + n;
  final y = d.year + (total / 12).floor();
  final m = total % 12 + 1;
  final dim = daysInMonth(y, m);
  return toISO(DateTime(y, m, day < dim ? day : dim));
}

/// Whole calendar days from a to b (b - a).
int diffDays(String a, String b) {
  final da = parseISO(a), db = parseISO(b);
  return DateTime.utc(db.year, db.month, db.day).difference(DateTime.utc(da.year, da.month, da.day)).inDays;
}

String monthKey(String s) => s.substring(0, 7);

String monthLabel(String key, {bool long = false}) {
  final p = key.split('-');
  final m = int.parse(p[1]);
  return '${(long ? _monthsLong : _months)[m - 1]} ${p[0]}';
}

String shortMonth(String key) => _months[int.parse(key.split('-')[1]) - 1];

String shiftMonthKey(String key, int n) => monthKey(addMonthsClamped('$key-01', n));

/// "5 Nov"
String fmtShort(String s) {
  final d = parseISO(s);
  return '${d.day} ${_months[d.month - 1]}';
}

/// "5 Nov 2026"
String fmtDate(String s) {
  final d = parseISO(s);
  return '${d.day} ${_months[d.month - 1]} ${d.year}';
}

/// "Thu, 5 Nov 2026"
String fmtLong(String s) => '${weekdayShort(s)}, ${fmtDate(s)}';

/// "4th November", with the year added when it isn't [currentYear]: "4th January 2027".
String fmtDayMonth(String s, {int? currentYear}) {
  final d = parseISO(s);
  final n = d.day;
  final suffix = (n % 100 >= 11 && n % 100 <= 13) ? 'th' : const {1: 'st', 2: 'nd', 3: 'rd'}[n % 10] ?? 'th';
  final year = d.year == (currentYear ?? DateTime.now().year) ? '' : ' ${d.year}';
  return '$n$suffix ${_monthsLong[d.month - 1]}$year';
}

String weekdayShort(String s) => _days[parseISO(s).weekday - 1];

/// "Today", "Yesterday", "Tomorrow" or "5 Nov 2026"
String fmtRelative(String s) {
  final t = todayISO();
  if (s == t) return 'Today';
  if (s == addDays(t, -1)) return 'Yesterday';
  if (s == addDays(t, 1)) return 'Tomorrow';
  return fmtDate(s);
}

/// Monday-based start of the week containing the date.
String startOfWeek(String s) => addDays(s, -(parseISO(s).weekday - 1));

String dueLabel(int days) {
  if (days == 0) return 'Due today';
  if (days == 1) return 'Due tomorrow';
  if (days > 1) return '$days days left';
  if (days == -1) return '1 day overdue';
  return '${-days} days overdue';
}

String greeting() {
  final h = DateTime.now().hour;
  if (h < 12) return 'Good morning';
  if (h < 17) return 'Good afternoon';
  return 'Good evening';
}
