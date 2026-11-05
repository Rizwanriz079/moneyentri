import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/icons.dart';
import '../core/theme.dart';
import '../screens/history_screen.dart';
import '../screens/home_screen.dart';
import '../screens/insights_screen.dart';
import '../screens/payments_screen.dart';
import '../widgets/ui.dart';
import 'nav.dart';

const _tabs = [
  ('Home', 'home-outline', 'home'),
  ('History', 'receipt-outline', 'receipt'),
  ('Insights', 'pie-chart-outline', 'pie-chart'),
  ('Payments', 'calendar-outline', 'calendar'),
];

/// Bottom-tab container with a floating bar and a centre "+" button.
class Shell extends StatelessWidget {
  const Shell({super.key});

  @override
  Widget build(BuildContext context) {
    final nav = context.watch<TabNav>();
    return PopScope(
      // Back from another tab returns to Home before leaving the app.
      canPop: nav.tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) nav.go(0);
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: nav.tab,
          children: const [HomeScreen(), HistoryScreen(), InsightsScreen(), PaymentsScreen()],
        ),
        bottomNavigationBar: const _TabBar(),
      ),
    );
  }
}

class _TabBar extends StatelessWidget {
  const _TabBar();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final nav = context.watch<TabNav>();
    final bottom = MediaQuery.paddingOf(context).bottom;

    Widget tab(int i) {
      final (label, icon, activeIcon) = _tabs[i];
      final focused = nav.tab == i;
      return Expanded(
        child: Semantics(
          container: true,
          excludeSemantics: true,
          onTap: () => nav.go(i),
          selected: focused,
          button: true,
          label: label,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              haptic();
              nav.go(i);
            },
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(appIcon(focused ? activeIcon : icon), size: 22, color: focused ? c.primary : c.textFaint),
                const SizedBox(height: 3),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: focused ? c.primary : c.textFaint,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // The bar has a fixed height, so cap large system text sizes inside it.
    return MediaQuery.withClampedTextScaling(
      maxScaleFactor: 1.15,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 0, 16, bottom > 12 ? bottom : 12),
        child: Container(
          height: 68,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: c.tabBar,
            borderRadius: BorderRadius.circular(26),
            border: c.dark ? Border.all(color: c.border) : null,
            boxShadow: [BoxShadow(color: c.shadow.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 8))],
          ),
          child: Row(
            children: [
              tab(0),
              tab(1),
              Expanded(
                child: OverflowBox(
                  maxHeight: 120,
                  child: Transform.translate(
                    offset: const Offset(0, -15),
                    child: Semantics(
                      button: true,
                      container: true,
                      excludeSemantics: true,
                      onTap: () => Routes.transactionForm(context),
                      label: 'Add transaction',
                      child: ScalePress(
                        onTap: () {
                          haptic();
                          Routes.transactionForm(context);
                        },
                        child: Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            gradient: LinearGradient(
                              colors: [c.primary, c.primaryAlt],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF4F46E5).withValues(alpha: 0.45),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(appIcon('add'), size: 30, color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              tab(2),
              tab(3),
            ],
          ),
        ),
      ),
    );
  }
}
