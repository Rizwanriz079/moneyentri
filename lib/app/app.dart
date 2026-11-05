import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../core/theme.dart';
import '../data/models.dart';
import '../data/store.dart';
import '../services/notification_service.dart';
import 'nav.dart';
import 'shell.dart';
import 'app_lock_gate.dart';
import 'splash.dart';

class FinTrackApp extends StatefulWidget {
  const FinTrackApp({super.key});

  @override
  State<FinTrackApp> createState() => _FinTrackAppState();
}

class _FinTrackAppState extends State<FinTrackApp> with WidgetsBindingObserver {
  late final AppStore _store = context.read<AppStore>();
  final _notif = NotificationService.instance;
  StreamSubscription<PayTarget>? _tapSub;
  Timer? _syncTimer;

  // Identity of the lists that affect reminders, to skip unrelated changes.
  List<Loan>? _loans;
  List<Bill>? _bills;
  List<Payment>? _payments;
  Settings? _settings;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _store.addListener(_onStoreChanged);
    _onStoreChanged();
    _tapSub = _notif.taps.listen(_openTarget);
    // Cold start from a notification tap.
    _notif.launchTarget().then((t) {
      if (t != null) WidgetsBinding.instance.addPostFrameCallback((_) => _openTarget(t));
    });
  }

  /// Re-sync reminders whenever anything that affects them changes (debounced).
  void _onStoreChanged() {
    final s = _store;
    final changed =
        !identical(_loans, s.loans) ||
        !identical(_bills, s.bills) ||
        !identical(_payments, s.payments) ||
        !identical(_settings, s.settings);
    _loans = s.loans;
    _bills = s.bills;
    _payments = s.payments;
    _settings = s.settings;
    if (!changed) return;
    _syncTimer?.cancel();
    _syncTimer = Timer(const Duration(milliseconds: 400), () => _notif.sync(_store));
  }

  /// Foregrounding rolls the reminder window forward (new month → next EMI);
  /// backgrounding flushes pending writes to storage.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _notif.sync(_store);
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _store.flush();
    }
  }

  /// Tapping a reminder opens the payment sheet for that installment.
  /// It never marks anything as paid by itself.
  void _openTarget(PayTarget t) {
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    Routes.pay(ctx, kind: t.kind, id: t.refId, due: t.dueDate);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _store.removeListener(_onStoreChanged);
    _tapSub?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pref = context.select<AppStore, String>((s) => s.settings.theme);
    final mode = switch (pref) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return MaterialApp(
      title: 'FinTrack',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: buildTheme(AppColors.light),
      darkTheme: buildTheme(AppColors.darkTheme),
      themeMode: mode,
      builder: (context, child) {
        final dark = Theme.of(context).brightness == Brightness.dark;
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark).copyWith(
            statusBarColor: Colors.transparent,
            systemNavigationBarColor: dark ? AppColors.darkTheme.bg : AppColors.light.bg,
          ),
          child: SplashOverlay(child: AppLockGate(child: child!)),
        );
      },
      home: const Shell(),
    );
  }
}
