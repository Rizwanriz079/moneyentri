import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/icons.dart';
import '../core/theme.dart';
import '../data/store.dart';
import '../services/app_lock.dart';
import '../widgets/ui.dart';
import 'splash.dart';

/// Covers the app with a lock screen when App lock is on.
///
/// Locks when the app starts and every time it comes back from the
/// background. Pauses caused by the fingerprint prompt itself are ignored, so
/// the user is asked once, not twice. While locked, the app below is kept
/// alive but not shown, not tappable and hidden from screen readers.
class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child, this.service});
  final Widget child;

  /// For tests; defaults to [AppLockService.instance].
  final AppLockService? service;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  late final AppLockService _lock = widget.service ?? AppLockService.instance;
  late bool _locked = _enabled;
  bool _busy = false;
  String? _message;
  bool _leftApp = false;

  bool get _enabled => _lock.supported && context.read<AppStore>().settings.appLock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SplashOverlay.done.addListener(_maybePrompt);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SplashOverlay.done.removeListener(_maybePrompt);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused || state == AppLifecycleState.hidden) {
      // The fingerprint prompt itself can pause the app; that isn't leaving.
      if (!_busy && !_lock.recentlyPrompted) _leftApp = true;
    } else if (state == AppLifecycleState.resumed) {
      final left = _leftApp;
      _leftApp = false;
      if (left && _enabled && !_locked) {
        setState(() {
          _locked = true;
          _message = null;
        });
        // Ask once the app is fully back on screen.
        WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
      }
    }
  }

  /// Show the system prompt once the splash animation has finished.
  void _maybePrompt() {
    if (!mounted || !_locked || _busy || !SplashOverlay.done.value) return;
    _unlock();
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() => _busy = true);
    final result = await _lock.authenticate('Unlock FinTrack');
    if (!mounted) return;
    setState(() {
      _busy = false;
      switch (result) {
        case UnlockResult.success:
          _locked = false;
          _message = null;
        case UnlockResult.cancelled:
          _message = null;
        case UnlockResult.lockedOut:
          _message = 'Too many attempts. Wait a moment, then try again.';
        case UnlockResult.notSetUp:
          // The phone's screen lock was removed, so the app can't be protected
          // any more. Anyone holding this unlocked phone can already open it.
          _locked = false;
          _message = null;
          context.read<AppStore>().updateSettings((s) => s.copyWith(appLock: false));
        case UnlockResult.error:
          _message = 'Couldn\'t check your fingerprint or screen lock. Try again.';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Turning App lock off elsewhere removes the lock screen straight away.
    final enabled = context.select<AppStore, bool>((s) => s.settings.appLock);
    final showLock = _locked && enabled && _lock.supported;
    return Stack(
      children: [
        // Keep the app's state, but don't paint it or let it be touched/read.
        Visibility(visible: !showLock, maintainState: true, child: widget.child),
        if (showLock) Positioned.fill(child: _LockScreen(busy: _busy, message: _message, onUnlock: _unlock)),
      ],
    );
  }
}

class _LockScreen extends StatelessWidget {
  const _LockScreen({required this.busy, required this.message, required this.onUnlock});
  final bool busy;
  final String? message;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.bg,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Space.lg),
          child: Column(
            children: [
              const Spacer(flex: 3),
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/icon/icon.png', width: 76, height: 76),
              ),
              const SizedBox(height: 20),
              const T('FinTrack is locked', v: TV.h2, align: TextAlign.center),
              const SizedBox(height: 8),
              const T(
                'Use your fingerprint, face or screen lock to open the app.',
                v: TV.body,
                muted: true,
                align: TextAlign.center,
              ),
              if (message != null) ...[
                const SizedBox(height: 16),
                T(message!, v: TV.caption, color: c.expense, align: TextAlign.center),
              ],
              const Spacer(flex: 4),
              AppButton(title: busy ? 'Waiting…' : 'Unlock', icon: 'finger-print', disabled: busy, onTap: onUnlock),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(appIcon('shield-checkmark-outline'), size: 14, color: c.textFaint),
                  const SizedBox(width: 6),
                  const Flexible(child: T('Your data stays on this phone', v: TV.caption, faint: true)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
