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
    try {
      final ok = await _auth.authenticate(
        localizedReason: reason,
        // Fingerprint, face OR the phone's PIN / pattern / password.
        biometricOnly: false,
        // Keep the prompt if the app is briefly backgrounded.
        persistAcrossBackgrounding: true,
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
