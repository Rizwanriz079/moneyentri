# Publishing FinTrack on Google Play

The project is set up for release. Before the first upload, you need to do four things yourself: create an upload key, sign the bundle, upload it, and fill in the store forms in Play Console.

## 1. Check the app ID (can never change later)

The app ID is `com.vintaxwebs.fintrack`. It is set in `android/app/build.gradle.kts`, in both `applicationId` and `namespace`.

If you want a different ID, change it **before the first upload**. Also rename the folder `android/app/src/main/kotlin/com/vintaxwebs/fintrack/` and the `package` line in `MainActivity.kt` to match.

## 2. Create your upload key (once)

```bash
keytool -genkey -v -keystore ~/fintrack-upload.jks -keyalg RSA -keysize 2048 \
  -validity 10000 -alias upload
```

Then create `android/key.properties` (this file is git-ignored):

```properties
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=/Users/YOU/fintrack-upload.jks
```

Back up the `.jks` file and both passwords somewhere safe. Play App Signing lets Google reset a lost upload key, but that takes days.

Without `key.properties`, release builds are signed with the debug key. They still run on a phone, but Play Console rejects them.

## 3. Build the bundle

```bash
./tool/build_release.sh
# Output: build/app/outputs/bundle/release/app-release.aab
```

The script runs `flutter build appbundle --release --obfuscate --split-debug-info=release-symbols/<version>`.
`--obfuscate` scrambles class and function names inside the app file, so it is much harder
to reverse-engineer. Your source code is not changed. The `release-symbols/<version>/` folder
is the key to read crash reports from that version (`flutter symbolize`). Keep it, and don't
upload or share it. It is git-ignored.

For each new release, raise the number after `+` in `pubspec.yaml`. For example, `version: 1.0.1+2`. Play requires a higher `versionCode` for every upload.

To test the release build on a phone first:

```bash
flutter build apk --release
flutter install            # with the phone connected and USB debugging on
```

## 4. Play Console setup

1. In [Play Console](https://play.google.com/console), choose **Create app**. Enter the name *FinTrack*, choose *App* and *Free*.
2. Under **Testing → Internal testing**, create a release and upload `app-release.aab`. Accept **Play App Signing** when asked.
3. Complete **App content**. The answers for this app are in the table below.
4. Complete **Main store listing**. The text and graphics are in the `store/` folder.
5. New personal developer accounts must run a **closed test with at least 12 testers for 14 days** before production access is granted.

### App content answers

| Form | Answer |
|---|---|
| Privacy policy | Required. Host `store/privacy-policy.html` (for example on GitHub Pages or your website) and paste the URL. First replace `[your support email]` in it. Also put the URL and your support email in `lib/core/app_info.dart` so they show in Profile → About. |
| Ads | No ads |
| App access | All functionality available without login |
| Content rating | Questionnaire category: *Utility, Productivity, Communication or Other*. Answer *No* to all content questions. |
| Target audience | 18 and over (finance app) |
| Data safety | **No data collected, no data shared.** All data is stored only on the device, with no network calls, no analytics and no accounts. |
| Financial features | Declare *personal finance / budgeting* only. The app does **not** offer loans, payments, banking or crypto services; it only records what the user enters. |
| Government app / news / health | No |

### Permissions the app requests

| Permission | Why |
|---|---|
| `POST_NOTIFICATIONS` | EMI and bill reminders (asked at runtime on Android 13+) |
| `RECEIVE_BOOT_COMPLETED` | Restore scheduled reminders after the phone restarts |
| `VIBRATE` | Reminder notifications |
| `USE_BIOMETRIC` (+ `USE_FINGERPRINT` on Android 8 and below, added by the plugin) | Optional App lock (fingerprint, face or screen lock). Android checks it; the app never receives biometric data |

The app deliberately does **not** use `SCHEDULE_EXACT_ALARM` or `USE_EXACT_ALARM`. Play restricts those to alarm and calendar apps. Reminders use inexact scheduling, so Android may deliver one a few minutes after the chosen time.

## 5. Store listing text

**App name:** FinTrack: Expense & EMI Tracker

**Short description (80 chars max):**
Track expenses, budgets, savings goals, loan EMIs and bills with reminders.

**Full description:**

FinTrack is a simple, private money manager for everyday spending, budgets, savings goals, loans and bills.

• Dashboard: total balance, this month's income and expenses, savings rate, and upcoming payments at a glance
• Add income or expenses in seconds, with category, date, note and payment method (Cash, UPI, Card, Bank)
• History: search and filter by date, category and type; tap to edit, long-press to delete
• Budgets: a monthly budget plus category limits, with progress bars and "near limit" warnings
• Analytics: monthly and weekly reports, 6-month income vs expense chart and a category breakdown
• Savings goals with target dates and how much to save each month
• Loans & EMIs: car, personal, gold, home and education loans, with an EMI calculator, outstanding balance, interest/principal split and full payment history
• Bills: rent, electricity, internet, mobile, insurance and subscriptions, repeating weekly, monthly, quarterly or yearly
• Payment calendar showing every due date
• Reminders 7, 3 and 1 day before and on the due date, showing the amount and date. Pause or change them any time
• Light and dark themes, Indian Rupee (₹) by default, and 8 other currencies

Your data stays on your phone. No account, no ads, no tracking.

**Category:** Finance
**Tags:** expense tracker, budget, EMI, bills

### Graphics (in `store/`)

| Asset | File | Required size |
|---|---|---|
| App icon | `play-icon-512.png` | 512 × 512 PNG |
| Feature graphic | `feature-graphic-1024x500.png` | 1024 × 500 |
| Phone screenshots | `screenshots/phone-*.png` (8 included) | 2–8 images, 9:16 (these are 1082 × 1922) |
