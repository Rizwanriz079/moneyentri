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

  bool pauseDuringPrompt = false;
  bool _busy = false;
  bool _justEnded = false;

  @override
  bool get busy => _busy;

  @override
  bool get recentlyPrompted => _busy || _justEnded;

  @override
  bool get supported => true;

  @override
  Future<bool> canLock() async => true;

  @override
  Future<UnlockResult> authenticate(String reason) async {
    prompts++;
    _busy = true;
    if (pauseDuringPrompt) {
      // Like many phones: the system prompt pauses and resumes the app.
      final b = TestWidgetsFlutterBinding.instance;
      b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      b.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    }
    await Future<void>.value();
    _busy = false;
    _justEnded = true;
    if (pauseDuringPrompt) {
      final b = TestWidgetsFlutterBinding.instance;
      b.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      b.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      b.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }
    return results.isEmpty ? UnlockResult.cancelled : results.removeAt(0);
  }

  void settle() => _justEnded = false;
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

  void leaveAndReturn(WidgetTester tester) {
    final b = tester.binding;
    for (final st in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      b.handleAppLifecycleStateChanged(st);
    }
  }

  testWidgets('locks again every time the user leaves the app and comes back', (tester) async {
    final lock = FakeLock([UnlockResult.success, UnlockResult.success]);
    await pumpGate(tester, lock, enabled: true);
    expect(find.text('SECRET BALANCE'), findsOneWidget);
    lock.settle();

    leaveAndReturn(tester); // even a quick switch
    await tester.pump();
    await tester.pump();
    expect(lock.prompts, 2, reason: 'asks again after returning');
    expect(find.text('SECRET BALANCE'), findsOneWidget, reason: 'unlocked by the second prompt');
  });

  testWidgets('the fingerprint prompt pausing the app does not cause a second prompt', (tester) async {
    final lock = FakeLock([UnlockResult.success, UnlockResult.success])..pauseDuringPrompt = true;
    await pumpGate(tester, lock, enabled: true);
    await tester.pump();
    await tester.pump();
    expect(lock.prompts, 1, reason: 'one fingerprint, not two');
    expect(find.text('SECRET BALANCE'), findsOneWidget);
  });

  testWidgets('turning App lock on in Settings does not lock straight away', (tester) async {
    final lock = FakeLock([UnlockResult.success])..pauseDuringPrompt = true;
    final store = await pumpGate(tester, lock, enabled: false);
    // Profile asks for the fingerprint to confirm (this pauses the app on many phones)...
    await lock.authenticate('Confirm to turn on App lock');
    store.updateSettings((s) => s.copyWith(appLock: true));
    await tester.pump();
    await tester.pump();
    // ...but that must not count as leaving the app.
    expect(lock.prompts, 1);
    expect(find.text('FinTrack is locked'), findsNothing);
  });

  testWidgets('if the phone screen lock was removed, App lock turns itself off', (tester) async {
    final lock = FakeLock([UnlockResult.notSetUp]);
    final store = await pumpGate(tester, lock, enabled: true);
    expect(find.text('SECRET BALANCE'), findsOneWidget);
    expect(store.settings.appLock, isFalse);
  });
}
