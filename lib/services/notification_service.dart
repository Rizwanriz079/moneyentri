import 'dart:async';
import 'dart:convert';

import 'dart:ui' show Color;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/dates.dart';
import '../core/format.dart';
import '../data/store.dart';
import '../domain/schedule.dart';

/// Reminder strategy
/// ─────────────────
/// Every reminder gets a deterministic key built from
/// (kind, item id, due date, offset, content hash), and a numeric id derived
/// from that key. On each sync we compute the full set of reminders that
/// *should* exist, cancel any of ours that shouldn't, and schedule only the
/// missing ones. This makes sync idempotent: no duplicates, edits
/// (amount/date/name) reschedule automatically, paid installments drop out,
/// and paused/deleted items are cleaned up.
///
/// Recurrence is handled as a rolling window: the next few unpaid
/// installments of every active loan/bill are scheduled, and the window is
/// re-synced whenever data changes or the app returns to the foreground, so
/// monthly reminders continue until a loan is completed. A reminder never
/// marks anything as paid.

enum NotifPermission { granted, denied, undetermined, unsupported }

/// Which installment a tapped notification refers to.
class PayTarget {
  const PayTarget(this.kind, this.refId, this.dueDate);
  final String kind, refId, dueDate;
}

class PlannedReminder {
  const PlannedReminder(this.key, this.fireAt, this.title, this.body, this.target);
  final String key;
  final DateTime fireAt;
  final String title, body;
  final PayTarget target;

  int get id => notificationId(key);

  String get payload => jsonEncode({'key': key, 'kind': target.kind, 'refId': target.refId, 'due': target.dueDate});
}

const _prefix = 'ft|';
const channelId = 'payment-reminders';
const _askedKey = 'fintrack:notif-asked';

/// Stay well below platform limits on pending alarms.
const maxScheduled = 60;
const occurrencesPerItem = 3;

/// Stable 31-bit FNV-1a hash used as the notification id for a reminder key.
int notificationId(String key) {
  var h = 0x811c9dc5;
  for (final c in utf8.encode(key)) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h & 0x7FFFFFFF;
}

String _hash(String s) {
  var h = 5381;
  for (final c in s.codeUnits) {
    h = ((h << 5) + h + c) & 0xFFFFFFFF;
  }
  return h.toRadixString(36);
}

/// Compute every reminder that should currently be scheduled.
List<PlannedReminder> planReminders(AppStore s, {DateTime? now}) {
  if (!s.settings.notificationsEnabled) return [];
  now ??= DateTime.now();
  final today = toISO(now);
  final planned = <PlannedReminder>[];

  List<PlannedReminder> remindersFor(Occurrence occ, List<int> offsets, String extra) {
    final money = formatMoney(occ.amount, s.settings.currency);
    final label = occ.kind == 'loan' ? '${occ.name} EMI' : occ.name;
    final out = <PlannedReminder>[];
    for (final offset in offsets.toSet()) {
      final day = parseISO(addDays(occ.dueDate, -offset));
      final fire = DateTime(day.year, day.month, day.day, s.settings.reminderHour);
      if (!fire.isAfter(now!.add(const Duration(seconds: 10)))) continue;
      final when = offset == 0 ? 'is due today' : (offset == 1 ? 'is due tomorrow' : 'is due in $offset days');
      final title = offset == 0 ? '⏰ $label due today' : '$label due in $offset day${offset > 1 ? 's' : ''}';
      // Private mode leaves the amount out: notifications can be read on the lock screen.
      final body = s.settings.privateReminders
          ? 'Payment $when (${fmtLong(occ.dueDate)}). Open FinTrack to see the amount and record it.'
          : '$money $when (${fmtLong(occ.dueDate)})$extra. Tap to record the payment.';
      final key = ['ft', occ.kind, occ.refId, occ.dueDate, offset, _hash('$title|$body|${fire.millisecondsSinceEpoch}')].join('|');
      out.add(PlannedReminder(key, fire, title, body, PayTarget(occ.kind, occ.refId, occ.dueDate)));
    }
    return out;
  }

  for (final loan in s.loans) {
    if (!loan.reminders.enabled || loan.reminders.paused) continue;
    final sum = loanSummary(loan, s.payments, today);
    if (sum.completed) continue;
    final extra = loan.bank.isNotEmpty ? ' · ${loan.bank}' : '';
    for (final o in sum.installments.where((o) => o.status == OccStatus.pending).take(occurrencesPerItem)) {
      planned.addAll(remindersFor(o, loan.reminders.offsets, extra));
    }
  }

  for (final bill in s.bills) {
    if (!bill.reminders.enabled || bill.reminders.paused) continue;
    final upcoming = billOccurrences(
      bill,
      s.payments,
      today,
      addDays(today, 400),
      today,
    ).where((o) => o.status == OccStatus.pending).take(occurrencesPerItem);
    for (final o in upcoming) {
      planned.addAll(remindersFor(o, bill.reminders.offsets, ''));
    }
  }

  planned.sort((a, b) => a.fireAt.compareTo(b.fireAt));
  // Two keys hashing to one id is astronomically unlikely; keep the first if it happens.
  final seen = <int>{};
  return planned.where((p) => seen.add(p.id)).take(maxScheduled).toList();
}

class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _taps = StreamController<PayTarget>.broadcast();

  /// Notifications the user tapped while the app was running.
  Stream<PayTarget> get taps => _taps.stream;

  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  bool _ready = false;

  Future<void> init() async {
    if (!supported || _ready) return;
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      // Unknown zone name: fall back to UTC offsets computed from DateTime.
    }
    await _plugin.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('ic_notification')),
      onDidReceiveNotificationResponse: (r) {
        final t = _parse(r.payload);
        if (t != null) _taps.add(t);
      },
    );
    await _ensureChannel();
    _ready = true;
  }

  /// The notification that cold-started the app, if any.
  Future<PayTarget?> launchTarget() async {
    if (!supported) return null;
    try {
      final details = await _plugin.getNotificationAppLaunchDetails();
      if (details?.didNotificationLaunchApp != true) return null;
      return _parse(details!.notificationResponse?.payload);
    } catch (e) {
      debugPrint('Launch details unavailable: $e');
      return null;
    }
  }

  PayTarget? _parse(String? payload) {
    if (payload == null) return null;
    try {
      final j = jsonDecode(payload) as Map<String, dynamic>;
      return PayTarget(j['kind'], j['refId'], j['due']);
    } catch (_) {
      return null;
    }
  }

  Future<void> _ensureChannel() async {
    await _android?.createNotificationChannel(
      const AndroidNotificationChannel(
        channelId,
        'Payment reminders',
        description: 'EMI and bill due-date reminders',
        importance: Importance.high,
      ),
    );
  }

  NotificationDetails get _details => const NotificationDetails(
    android: AndroidNotificationDetails(
      channelId,
      'Payment reminders',
      channelDescription: 'EMI and bill due-date reminders',
      importance: Importance.high,
      priority: Priority.high,
      // Android hides the text on a secure lock screen when the user has
      // chosen to hide sensitive notification content.
      visibility: NotificationVisibility.private,
      color: Color(0xFF4F46E5),
      styleInformation: BigTextStyleInformation(''),
    ),
  );

  /// Never throws: if the plugin isn't available, reports "unsupported" so
  /// screens show a message instead of failing.
  Future<NotifPermission> getPermission() async {
    if (!supported) return NotifPermission.unsupported;
    try {
      final enabled = await _android?.areNotificationsEnabled() ?? false;
      if (enabled) return NotifPermission.granted;
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool(_askedKey) == true ? NotifPermission.denied : NotifPermission.undetermined;
    } catch (e) {
      debugPrint('Notification permission check failed: $e');
      return NotifPermission.unsupported;
    }
  }

  /// Ask for permission (Android 13+). The channel already exists from init().
  Future<NotifPermission> requestPermission() async {
    if (!supported) return NotifPermission.unsupported;
    await init();
    if (await getPermission() == NotifPermission.granted) return NotifPermission.granted;
    final granted = await _android?.requestNotificationsPermission() ?? false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_askedKey, true);
    return granted ? NotifPermission.granted : NotifPermission.denied;
  }

  Future<void> openSettings() async {
    if (!supported) return;
    try {
      await _plugin.openAppNotificationSettings();
    } catch (e) {
      debugPrint('Could not open notification settings: $e');
    }
  }

  Future<List<PendingNotificationRequest>> _ours() async {
    final all = await _plugin.pendingNotificationRequests();
    return all.where((n) => (n.payload ?? '').contains('"key":"$_prefix')).toList();
  }

  Future<void> _reconcile(AppStore s) async {
    await init();
    final perm = await getPermission();
    final scheduled = await _ours();
    // Without permission, leave nothing of ours queued.
    final planned = perm == NotifPermission.granted ? planReminders(s) : <PlannedReminder>[];
    final wanted = {for (final p in planned) p.id: p};
    final existing = <int>{};

    for (final n in scheduled) {
      final want = wanted[n.id];
      if (want == null || want.payload != n.payload) {
        await _plugin.cancel(id: n.id);
      } else {
        existing.add(n.id);
      }
    }
    if (perm != NotifPermission.granted) return;
    for (final p in planned) {
      if (existing.contains(p.id)) continue;
      await _plugin.zonedSchedule(
        id: p.id,
        title: p.title,
        body: p.body,
        payload: p.payload,
        scheduledDate: tz.TZDateTime.from(p.fireAt, tz.local),
        notificationDetails: _details,
        // Inexact alarms avoid the restricted exact-alarm permission on Play;
        // Android may deliver a reminder a few minutes after the chosen hour.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  // Syncs are serialized and coalesced so concurrent triggers can't double-schedule.
  Future<void>? _running;
  AppStore? _queued;

  Future<void> sync(AppStore s) {
    if (!supported || !s.hydrated) return Future.value();
    _queued = s;
    return _running ??= () async {
      while (_queued != null) {
        final next = _queued!;
        _queued = null;
        try {
          await _reconcile(next);
        } catch (e) {
          debugPrint('Reminder sync failed: $e');
        }
      }
      _running = null;
    }();
  }

  Future<int> scheduledCount() async {
    if (!supported) return 0;
    try {
      return (await _ours()).length;
    } catch (e) {
      debugPrint('Could not count reminders: $e');
      return 0;
    }
  }

  Future<void> sendTest() async {
    if (!supported) return;
    await init();
    await _plugin.show(
      id: 1,
      title: 'FinTrack reminders are on ✅',
      body: 'You will be notified before EMIs and bills are due.',
      notificationDetails: _details,
    );
  }
}
