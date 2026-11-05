/// Public links shown in Profile → About. Fill these in before publishing.
/// Rows whose value is empty are hidden, so nothing broken ships.
class AppInfo {
  /// Where `store/privacy-policy.html` is hosted (also pasted into Play Console).
  static const privacyPolicyUrl = 'https://rizwanriz079.github.io/moneyentri-privacy/';

  /// Support address shown to users and in the Play Store listing.
  static const supportEmail = 'abb422112@gmail.com';

  /// Must match `applicationId` in android/app/build.gradle.kts.
  static const packageId = 'com.vintaxwebs.moneyentri';

  static const playStoreUrl = 'https://play.google.com/store/apps/details?id=$packageId';
}
