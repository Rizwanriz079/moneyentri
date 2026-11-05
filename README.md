# FinTrack (Flutter)

A personal finance app for Android with expenses, budgets, savings goals, loan EMIs and recurring bills, plus local payment reminders. All data stays on the device.

This is the Flutter version of the React Native app in `../fintrack`, with the same features, screens and design.

## Run

```bash
flutter pub get
flutter run                 # Android phone/emulator
flutter run -d chrome       # quick browser preview (no notifications on web)
flutter test                # logic tests
```

On first launch, tap **Load sample data** on Home to explore with about 6 months of data.

Release and Play Store steps are in **[PLAY_STORE.md](PLAY_STORE.md)**.

## Project structure

```
lib/
  main.dart                 Startup: load saved data, init notifications, providers
  app/
    app.dart                MaterialApp, light/dark theme, reminder sync, notification taps
    shell.dart              Bottom tab bar with the centre "+" button
    nav.dart                Routes (typed helpers for every screen) + TabNav state
  core/                     Pure helpers, no Flutter state
    theme.dart              Colour tokens (AppColors), radius/spacing, ThemeData
    icons.dart              Ionicons name → IconData table (keeps icon tree-shaking)
    dates.dart              YYYY-MM-DD helpers, month maths, labels
    format.dart             Money formatting (Indian grouping for ₹), parsing
  data/
    models.dart             Transaction, Budget, Goal, Loan, Bill, Payment, Settings (+ JSON)
    categories.dart         Categories, payment methods, loan and bill types
    store.dart              AppStore (ChangeNotifier): all actions + persistence
  domain/                   Business rules, unit-tested
    schedule.dart           EMI schedule, amortisation, bill recurrence, payment matching
    analytics.dart          Totals, category breakdown, daily/weekly/monthly series
    demo.dart               Sample data
  services/
    notification_service.dart   Reminder planning + idempotent scheduling
  widgets/                  Reusable UI used by every screen
    ui.dart                 T (text), AppCard, AppButton, AppChip, Segmented, AppInput,
                            AmountInput, ProgressBar, Pill, EmptyState, FadeIn, dialogs…
    charts.dart             BarChart, GroupedBarChart, DonutChart, ProgressRing
    rows.dart               TransactionRow, PaymentRow, statusStyle
    pickers.dart            CategoryGrid, MethodPicker, ReminderOffsets, DateField, MonthCalendar
    form_scaffold.dart      Standard form layout with a pinned footer button
  screens/                  One file per screen, built only from the widgets above
```

### How the layers depend on each other

`screens → widgets → (data, domain, core)`. Screens contain only layout and wiring. Calculations live in `domain/`, which has no Flutter imports beyond `foundation`, and state changes go through `AppStore`. Because of this layering:

- **New screens** reuse `AppCard`, `AppButton`, `Segmented`, `FormScaffold`, the charts and the rows, so they automatically match the design and dark mode.
- **Business rules** can be unit-tested without a device (`test/logic_test.dart`).
- **Changing the look** means editing `core/theme.dart`. Every widget reads colours from `context.colors`.

## How payments, expenses and reminders stay in sync

- **Mark as paid** creates one `Payment` and one linked expense `Transaction`. For loans it splits the amount into interest (outstanding × rate ÷ 1200) and principal, and lowers the balance.
- **Mark as pending**, or deleting the linked expense, removes both and restores the balance.
- **Editing a linked expense** can change its date, method and note. The payment record follows.
- Installments are matched to payments **by month** (by exact date for weekly bills), so moving an EMI date doesn't un-pay months that are already paid.

### Reminders (`lib/services/notification_service.dart`)

- Reminders fire at the chosen hour 7, 3 and 1 days before the due date, and on the due date itself. Each loan or bill has its own offset settings.
- Each reminder has a **deterministic key and id** (item, due date, offset, content hash). A sync computes the reminders that should exist, cancels any of ours that shouldn't, and schedules only the missing ones. As a result:
  - there are no duplicates,
  - edits reschedule automatically,
  - paid, paused and deleted items lose their reminders.
- A **rolling window** schedules the next 3 unpaid installments per item, at most 60 in total. It re-syncs on every data change and whenever the app returns to the foreground, so monthly reminders continue until a loan is completed. The plugin restores reminders after a reboot.
- A reminder **never** marks anything as paid. Tapping it opens the Pay screen for that installment.
