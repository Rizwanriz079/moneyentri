import 'package:fintrack/app/app_lock_gate.dart';
import 'package:fintrack/app/splash.dart';
import 'package:fintrack/core/theme.dart';
import 'package:fintrack/data/store.dart';
import 'package:fintrack/services/app_lock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Pretend fingerprint checker: returns the queued results in order.
class FakeLock implements AppLockService {
  FakeLock(this.results);
  final List<UnlockResult> results;
  int prompts = 0;

  @override
  bool get supported => true;

  @override
  Future<bool> canLock() async => true;

  @override
  Future<UnlockResult> authenticate(String reason) async {
    prompts++;
    return results.isEmpty ? UnlockResult.cancelled : results.removeAt(0);
  }
}

void main() {
  setUp(() => SplashOverlay.done.value = true);

  Future<AppStore> pumpGate(WidgetTester tester, FakeLock lock, {required bool enabled}) async {
    final store = AppStore()..updateSettings((s) => s.copyWith(appLock: enabled));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: store,
        child: MaterialApp(
          theme: buildTheme(AppColors.light),
          home: AppLockGate(service: lock, child: const Scaffold(body: Text('SECRET BALANCE'))),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    return store;
  }

  testWidgets('app lock off: the app opens with no prompt', (tester) async {
    final lock = FakeLock([]);
    await pumpGate(tester, lock, enabled: false);
    expect(find.text('SECRET BALANCE'), findsOneWidget);
    expect(find.text('FinTrack is locked'), findsNothing);
    expect(lock.prompts, 0);
  });

  testWidgets('app lock on: content is hidden until the fingerprint matches', (tester) async {
    final lock = FakeLock([UnlockResult.cancelled, UnlockResult.success]);
    await pumpGate(tester, lock, enabled: true);
    // First prompt was cancelled: still locked and the data is not on screen.
    expect(lock.prompts, 1);
    expect(find.text('FinTrack is locked'), findsOneWidget);
    expect(find.text('SECRET BALANCE'), findsNothing);
    // Tap Unlock, second prompt succeeds.
    await tester.tap(find.text('Unlock'));
    await tester.pump();
    await tester.pump();
    expect(find.text('FinTrack is locked'), findsNothing);
    expect(find.text('SECRET BALANCE'), findsOneWidget);
  });

  testWidgets('waits for the splash to finish before asking', (tester) async {
    SplashOverlay.done.value = false;
    final lock = FakeLock([UnlockResult.success]);
    await pumpGate(tester, lock, enabled: true);
    expect(lock.prompts, 0);
    SplashOverlay.done.value = true;
    await tester.pump();
    await tester.pump();
    expect(lock.prompts, 1);
    expect(find.text('SECRET BALANCE'), findsOneWidget);
  });

  testWidgets('too many attempts shows a message and stays locked', (tester) async {
    final lock = FakeLock([UnlockResult.lockedOut]);
    await pumpGate(tester, lock, enabled: true);
    expect(find.textContaining('Too many attempts'), findsOneWidget);
    expect(find.text('SECRET BALANCE'), findsNothing);
  });

  testWidgets('relocks after 30+ seconds in the background, not after a quick switch', (tester) async {
    final lock = FakeLock([UnlockResult.success]);
    await pumpGate(tester, lock, enabled: true);
    expect(find.text('SECRET BALANCE'), findsOneWidget);

    // Quick switch (e.g. to the email app): no new prompt.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text('FinTrack is locked'), findsNothing);
    expect(lock.prompts, 1);
  });

  testWidgets('if the phone screen lock was removed, App lock turns itself off', (tester) async {
    final lock = FakeLock([UnlockResult.notSetUp]);
    final store = await pumpGate(tester, lock, enabled: true);
    expect(find.text('SECRET BALANCE'), findsOneWidget);
    expect(store.settings.appLock, isFalse);
  });
}
