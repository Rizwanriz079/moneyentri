import 'package:flutter/material.dart';

import '../core/theme.dart';
import 'ui.dart';

/// Form layout: header, scrolling fields, and a footer that stays above the keyboard.
class FormScaffold extends StatelessWidget {
  const FormScaffold({super.key, required this.title, this.subtitle, this.actions = const [], required this.children, this.footer});
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            AppHeader(title: title, subtitle: subtitle, actions: actions),
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                behavior: HitTestBehavior.translucent,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, 32),
                  keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                  children: gap(children, Space.lg),
                ),
              ),
            ),
            if (footer != null)
              Container(
                padding: EdgeInsets.fromLTRB(
                  Space.lg,
                  Space.md,
                  Space.lg,
                  MediaQuery.paddingOf(context).bottom.clamp(Space.lg, double.infinity),
                ),
                decoration: BoxDecoration(
                  color: c.bg,
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: footer,
              ),
          ],
        ),
      ),
    );
  }
}
