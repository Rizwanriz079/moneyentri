import 'package:flutter/material.dart';

/// Design tokens shared by every screen. Read them with `context.colors`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.dark,
    required this.primary,
    required this.primaryAlt,
    required this.income,
    required this.expense,
    required this.warning,
    required this.orange,
    required this.bg,
    required this.card,
    required this.cardAlt,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.textFaint,
    required this.primarySoft,
    required this.incomeSoft,
    required this.expenseSoft,
    required this.warningSoft,
    required this.tabBar,
    required this.chartIncome,
    required this.chartExpense,
    required this.grid,
    required this.shadow,
  });

  final bool dark;
  final Color primary, primaryAlt, income, expense, warning, orange;
  final Color bg, card, cardAlt, border, text, textMuted, textFaint;
  final Color primarySoft, incomeSoft, expenseSoft, warningSoft, tabBar;

  /// Chart marks: validated for colour-vision deficiency on each surface.
  final Color chartIncome, chartExpense, grid, shadow;

  static const light = AppColors(
    dark: false,
    primary: Color(0xFF4F46E5),
    primaryAlt: Color(0xFF7C3AED),
    income: Color(0xFF16A34A),
    expense: Color(0xFFEF4444),
    warning: Color(0xFFF59E0B),
    orange: Color(0xFFF97316),
    bg: Color(0xFFF4F5FA),
    card: Color(0xFFFFFFFF),
    cardAlt: Color(0xFFF1F2F8),
    border: Color(0xFFE6E8F0),
    text: Color(0xFF0F172A),
    textMuted: Color(0xFF64748B),
    textFaint: Color(0xFF94A3B8),
    primarySoft: Color(0xFFEEF0FF),
    incomeSoft: Color(0xFFE8F7EE),
    expenseSoft: Color(0xFFFDECEC),
    warningSoft: Color(0xFFFEF5E6),
    tabBar: Color(0xFFFFFFFF),
    chartIncome: Color(0xFF166534),
    chartExpense: Color(0xFFF97316),
    grid: Color(0xFFEEF0F5),
    shadow: Color(0xFF1E1B4B),
  );

  static const darkTheme = AppColors(
    dark: true,
    primary: Color(0xFF6366F1),
    primaryAlt: Color(0xFF7C3AED),
    income: Color(0xFF22C55E),
    expense: Color(0xFFF87171),
    warning: Color(0xFFF59E0B),
    orange: Color(0xFFF97316),
    bg: Color(0xFF0A0B10),
    card: Color(0xFF14161F),
    cardAlt: Color(0xFF1B1E2A),
    border: Color(0xFF252938),
    text: Color(0xFFF1F5F9),
    textMuted: Color(0xFF94A3B8),
    textFaint: Color(0xFF64748B),
    primarySoft: Color(0xFF1E1F3B),
    incomeSoft: Color(0xFF0F2A1B),
    expenseSoft: Color(0xFF2F1518),
    warningSoft: Color(0xFF2D2310),
    tabBar: Color(0xFF14161F),
    chartIncome: Color(0xFF16A34A),
    chartExpense: Color(0xFFEA580C),
    grid: Color(0xFF1F2330),
    shadow: Color(0xFF000000),
  );

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) => other is AppColors && t >= 0.5 ? other : this;
}

class AppRadius {
  static const sm = 10.0, md = 14.0, lg = 20.0, xl = 28.0, pill = 999.0;
}

class Space {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0, xl = 20.0, xxl = 28.0;
}

ThemeData buildTheme(AppColors c) {
  final base = c.dark ? ThemeData.dark(useMaterial3: true) : ThemeData.light(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: c.bg,
    colorScheme: base.colorScheme.copyWith(
      primary: c.primary,
      secondary: c.primaryAlt,
      surface: c.card,
      error: c.expense,
      onPrimary: Colors.white,
      onSurface: c.text,
    ),
    textSelectionTheme: TextSelectionThemeData(cursorColor: c.primary, selectionHandleColor: c.primary),
    dialogTheme: DialogThemeData(
      backgroundColor: c.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
    ),
    datePickerTheme: DatePickerThemeData(backgroundColor: c.card, headerBackgroundColor: c.primary, headerForegroundColor: Colors.white),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    extensions: [c],
  );
}

extension ThemeX on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>() ?? AppColors.light;
}

/// `#RRGGBB` → Color, used for category / goal colours stored as strings.
Color hex(String s) => Color(int.parse('FF${s.replaceFirst('#', '')}', radix: 16));

/// Colour with alpha, equivalent to the `${color}22` suffix trick.
Color tint(Color c, double opacity) => c.withValues(alpha: opacity);
