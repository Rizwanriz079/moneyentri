import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/nav.dart';
import '../core/app_info.dart';
import '../core/format.dart';
import '../core/icons.dart';
import '../core/theme.dart';
import '../data/store.dart';
import '../domain/demo.dart';
import '../services/app_lock.dart';
import '../services/notification_service.dart';
import '../widgets/ui.dart';

/// "9:00 AM", "6:30 PM"
String _timeLabel(int h, int m) => '${h % 12 == 0 ? 12 : h % 12}:${m.toString().padLeft(2, '0')} ${h < 12 ? 'AM' : 'PM'}';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _notif = NotificationService.instance;
  NotifPermission perm = NotifPermission.undetermined;
  int scheduled = 0;
  late String name, email;
  String version = '';

  @override
  void initState() {
    super.initState();
    PackageInfo.fromPlatform().then((i) {
      if (mounted) setState(() => version = 'Version ${i.version} (${i.buildNumber})');
    }).catchError((_) {});
    final s = context.read<AppStore>().settings;
    name = s.name;
    email = s.email;
    _refresh();
  }

  Future<void> _refresh() async {
    final p = await _notif.getPermission();
    if (!mounted) return;
    await _notif.sync(context.read<AppStore>());
    final n = await _notif.scheduledCount();
    if (mounted) {
      setState(() {
        perm = p;
        scheduled = n;
      });
    }
  }

  /// Turning App lock on or off needs the fingerprint / screen lock first.
  Future<void> _setAppLock(bool on) async {
    final lock = AppLockService.instance;
    final store = context.read<AppStore>();
    if (!lock.supported) {
      await infoDialog(context, 'Android app only', 'App lock uses your phone\'s fingerprint, face or screen lock.');
      return;
    }
    if (on && !await lock.canLock()) {
      if (mounted) {
        await infoDialog(
          context,
          'Set up a screen lock first',
          'Add a PIN, pattern, password or fingerprint in your phone\'s Settings → Security, then turn on App lock.',
        );
      }
      return;
    }
    final result = await lock.authenticate(on ? 'Confirm to turn on App lock' : 'Confirm to turn off App lock');
    if (!mounted) return;
    switch (result) {
      case UnlockResult.success:
        store.updateSettings((s) => s.copyWith(appLock: on));
      case UnlockResult.cancelled:
        break;
      case UnlockResult.lockedOut:
        await infoDialog(context, 'Too many attempts', 'Wait a moment, then try again.');
      case UnlockResult.notSetUp:
        await infoDialog(context, 'Set up a screen lock first', 'Add a PIN, pattern, password or fingerprint in your phone\'s Settings.');
      case UnlockResult.error:
        await infoDialog(context, 'Something went wrong', 'Couldn\'t check your fingerprint or screen lock. Try again.');
    }
  }

  /// Clock picker for the time reminders are sent.
  Future<void> _pickReminderTime(int hour, int minute) async {
    final store = context.read<AppStore>();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: hour, minute: minute),
      helpText: 'Send reminders at',
      initialEntryMode: TimePickerEntryMode.dial,
    );
    if (picked == null) return;
    store.updateSettings((s) => s.copyWith(reminderHour: picked.hour, reminderMinute: picked.minute));
    _refresh(); // reschedule reminders at the new time
  }

  Future<void> _open(Uri uri) async {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication).catchError((_) => false);
    if (!ok && mounted) {
      infoDialog(context, 'Couldn\'t open link', uri.toString());
    }
  }

  /// Save the text fields when leaving the screen.
  void _saveProfile() {
    final store = context.read<AppStore>();
    if (store.settings.name != name.trim() || store.settings.email != email.trim()) {
      store.updateSettings((s) => s.copyWith(name: name.trim(), email: email.trim()));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final store = context.watch<AppStore>();
    final settings = store.settings;
    final permLabel = switch (perm) {
      NotifPermission.granted => 'Allowed',
      NotifPermission.denied => 'Blocked in system settings',
      NotifPermission.undetermined => 'Not requested yet',
      NotifPermission.unsupported => 'Android app only',
    };

    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveProfile();
      },
      child: Screen(
        header: const AppHeader(title: 'Profile & settings'),
        children: [
          GradientPanel(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: settings.name.trim().isNotEmpty
                      ? T(settings.name.trim()[0].toUpperCase(), v: TV.h1, color: Colors.white)
                      : Icon(appIcon('person'), size: 28, color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      T(settings.name.isNotEmpty ? settings.name : 'Your name', v: TV.h2, color: Colors.white),
                      T(
                        '${settings.email.isNotEmpty ? settings.email : 'Add your email'} · ${store.transactions.length} transactions',
                        v: TV.caption,
                        color: const Color(0xCCFFFFFF),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: gap([
                const T('Profile', v: TV.h3),
                Field(
                  label: 'Name',
                  child: AppInput(
                    icon: 'person-outline',
                    placeholder: 'Your name',
                    capitalize: TextCapitalization.words,
                    value: name,
                    onChanged: (v) => name = v,
                    onSubmitted: () => store.updateSettings((s) => s.copyWith(name: name.trim())),
                  ),
                ),
                Field(
                  label: 'Email',
                  child: AppInput(
                    icon: 'mail-outline',
                    placeholder: 'you@example.com',
                    keyboard: TextInputType.emailAddress,
                    capitalize: TextCapitalization.none,
                    value: email,
                    onChanged: (v) => email = v,
                    onSubmitted: () => store.updateSettings((s) => s.copyWith(email: email.trim())),
                  ),
                ),
              ], 14),
            ),
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: gap([
                const T('Appearance', v: TV.h3),
                Segmented<String>(
                  options: const [
                    SegOption('system', 'System'),
                    SegOption('light', 'Light'),
                    SegOption('dark', 'Dark'),
                  ],
                  value: settings.theme,
                  onChanged: (t) => store.updateSettings((s) => s.copyWith(theme: t)),
                ),
                Field(
                  label: 'Currency',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final cur in currencies)
                        AppChip(
                          label: cur.symbol.trim() == cur.code ? cur.code : '${cur.symbol.trim()} ${cur.code}',
                          active: settings.currency == cur.code,
                          onTap: () => store.updateSettings((s) => s.copyWith(currency: cur.code)),
                        ),
                    ],
                  ),
                ),
              ], 14),
            ),
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: gap([
                const T('Payment reminders', v: TV.h3),
                ToggleRow(
                  icon: 'notifications-outline',
                  label: 'EMI & bill reminders',
                  hint: 'Permission: $permLabel',
                  value: settings.notificationsEnabled,
                  onChanged: (v) async {
                    store.updateSettings((s) => s.copyWith(notificationsEnabled: v));
                    if (v) {
                      final p = await _notif.requestPermission();
                      if (mounted) setState(() => perm = p);
                    }
                  },
                ),
                if (perm == NotifPermission.denied)
                  AppButton(
                    small: true,
                    variant: BtnVariant.secondary,
                    title: 'Open system settings',
                    icon: 'settings-outline',
                    onTap: _notif.openSettings,
                  ),
                if (perm == NotifPermission.undetermined)
                  AppButton(
                    small: true,
                    title: 'Allow notifications',
                    icon: 'notifications',
                    onTap: () async {
                      final p = await _notif.requestPermission();
                      if (mounted) setState(() => perm = p);
                      _refresh();
                    },
                  ),
                ToggleRow(
                  icon: 'eye-off-outline',
                  label: 'Private reminders',
                  hint: settings.privateReminders
                      ? 'Amounts are hidden in notifications'
                      : 'Notifications show the amount due',
                  value: settings.privateReminders,
                  onChanged: (v) => store.updateSettings((s) => s.copyWith(privateReminders: v)),
                ),
                const HairDivider(),
                NavRow(
                  icon: 'time-outline',
                  title: 'Reminder time',
                  subtitle: '${_timeLabel(settings.reminderHour, settings.reminderMinute)} on each reminder day',
                  onTap: () => _pickReminderTime(settings.reminderHour, settings.reminderMinute),
                ),
                if (perm == NotifPermission.unsupported)
                  const T(
                    'Reminders are delivered by the Android app. They can\'t be sent from the browser preview.',
                    v: TV.caption,
                    muted: true,
                  )
                else
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      T('$scheduled reminder${scheduled == 1 ? '' : 's'} scheduled', v: TV.caption, muted: true),
                      GestureDetector(
                        onTap: _refresh,
                        child: T(
                          'Refresh',
                          v: TV.caption,
                          color: c.primary,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                if (perm == NotifPermission.granted)
                  AppButton(
                    small: true,
                    variant: BtnVariant.ghost,
                    title: 'Send a test notification',
                    icon: 'paper-plane-outline',
                    onTap: _notif.sendTest,
                  ),
              ], 10),
            ),
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: gap([
                const T('Security', v: TV.h3),
                ToggleRow(
                  icon: 'lock-closed-outline',
                  label: 'App lock',
                  hint: AppLockService.instance.supported
                      ? 'Fingerprint, face or screen lock to open the app'
                      : 'Android app only',
                  value: settings.appLock,
                  onChanged: _setAppLock,
                ),
              ], 10),
            ),
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: gap([
                const T('Data', v: TV.h3),
                const T('Everything is stored on this device only.', v: TV.caption, muted: true),
                AppButton(
                  variant: BtnVariant.secondary,
                  title: 'Load sample data',
                  icon: 'flask-outline',
                  onTap: () async {
                    final ok = await confirmDialog(
                      context,
                      title: 'Load sample data?',
                      message: 'This replaces your current transactions, budgets, goals, loans and bills.',
                      confirm: 'Load',
                      destructive: false,
                    );
                    if (ok) store.replaceData(buildDemoData());
                  },
                ),
                AppButton(
                  variant: BtnVariant.danger,
                  title: 'Erase all data',
                  icon: 'trash-outline',
                  onTap: () async {
                    final ok = await confirmDialog(
                      context,
                      title: 'Erase all data?',
                      message:
                          'All transactions, budgets, goals, loans, bills and reminders will be permanently deleted.',
                      confirm: 'Erase',
                    );
                    if (ok) store.resetAllData();
                  },
                ),
              ], 10),
            ),
          ),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const T('About', v: TV.h3),
                const SizedBox(height: 14),
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.asset('assets/icon/icon.png', width: 52, height: 52),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const T('FinTrack', v: TV.h3),
                          T(version.isEmpty ? 'Expense & EMI tracker' : version, v: TV.caption, muted: true),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const T(
                  'Track expenses, budgets, savings goals, loan EMIs and bills, with reminders before every due date. '
                  'No account, no ads, no tracking. Your data stays on this device.',
                  v: TV.caption,
                  muted: true,
                ),
                const SizedBox(height: 6),
                const HairDivider(),
                NavRow(
                  icon: 'shield-checkmark-outline',
                  title: 'Privacy policy',
                  onTap: () => Routes.privacy(context),
                ),
                if (AppInfo.supportEmail.isNotEmpty)
                  NavRow(
                    icon: 'mail-outline',
                    title: 'Contact support',
                    subtitle: AppInfo.supportEmail,
                    external: true,
                    onTap: () => _open(Uri(scheme: 'mailto', path: AppInfo.supportEmail, query: 'subject=FinTrack%20support')),
                  ),
                NavRow(
                  icon: 'star-outline',
                  title: 'Rate on Google Play',
                  external: true,
                  onTap: () => _open(Uri.parse(AppInfo.playStoreUrl)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
