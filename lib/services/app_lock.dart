import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

enum UnlockResult {
  success,

  /// The user closed the prompt.
  cancelled,

  /// Too many wrong attempts; Android blocks tries for a while.
  lockedOut,

  /// The phone has no screen lock (PIN, pattern, password) or biometrics set up.
  notSetUp,

  /// Anything else (hardware or system problem).
  error,
}

/// Wraps Android's own fingerprint / face / screen-lock prompt.
///
/// The app never sees or stores fingerprints, face data or the device PIN:
/// Android checks them and only tells the app "yes" or "no".
class AppLockService {
  AppLockService._();
  static final instance = AppLockService._();

  final _auth = LocalAuthentication();

  bool _busy = false;
  DateTime? _endedAt;

  /// True while Android's fingerprint / PIN prompt is on screen.
  bool get busy => _busy;

  /// The system prompt briefly pauses the app on many phones. Pauses during a
  /// prompt, or just after it closes, are not the user leaving the app.
  bool get recentlyPrompted => _busy || (_endedAt != null && DateTime.now().difference(_endedAt!) < const Duration(seconds: 2));

  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// True when the phone has a screen lock or biometrics that can protect the app.
  Future<bool> canLock() async {
    if (!supported) return false;
    try {
      return await _auth.isDeviceSupported();
    } catch (e) {
      debugPrint('App lock check failed: $e');
      return false;
    }
  }

  Future<UnlockResult> authenticate(String reason) async {
    if (!supported) return UnlockResult.notSetUp;
    if (_busy) return UnlockResult.cancelled; // never show two prompts at once
    _busy = true;
    try {
      return await _authenticate(reason);
    } finally {
      _busy = false;
      _endedAt = DateTime.now();
    }
  }

  Future<UnlockResult> _authenticate(String reason) async {
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        // Fingerprint, face OR the phone's PIN / pattern / password.
        biometricOnly: false,
        // Don't re-show the prompt when the app resumes; it would ask twice.
        persistAcrossBackgrounding: false,
      );
      return ok ? UnlockResult.success : UnlockResult.cancelled;
    } on LocalAuthException catch (e) {
      return switch (e.code) {
        LocalAuthExceptionCode.userCanceled ||
        LocalAuthExceptionCode.systemCanceled ||
        LocalAuthExceptionCode.timeout ||
        LocalAuthExceptionCode.authInProgress ||
        LocalAuthExceptionCode.userRequestedFallback => UnlockResult.cancelled,
        LocalAuthExceptionCode.temporaryLockout || LocalAuthExceptionCode.biometricLockout => UnlockResult.lockedOut,
        LocalAuthExceptionCode.noCredentialsSet ||
        LocalAuthExceptionCode.noBiometricsEnrolled ||
        LocalAuthExceptionCode.noBiometricHardware => UnlockResult.notSetUp,
        _ => UnlockResult.error,
      };
    } catch (e) {
      debugPrint('Unlock failed: $e');
      return UnlockResult.error;
    }
  }
}
