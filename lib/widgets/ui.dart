/// Design-system primitives used by every screen: text, cards, buttons,
/// chips, segmented control, inputs, progress bars and feedback widgets.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/icons.dart';
import '../core/theme.dart';
import 'animations.dart';

void haptic() => HapticFeedback.selectionClick();

// ───────────────────────── Text ─────────────────────────

enum TV { display, h1, h2, h3, body, label, caption }

TextStyle textStyle(TV v) => switch (v) {
  TV.display => const TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.8, height: 1.2),
  TV.h1 => const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, letterSpacing: -0.5, height: 1.25),
  TV.h2 => const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: -0.3, height: 1.3),
  TV.h3 => const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, height: 1.35),
  TV.body => const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, height: 1.35),
  TV.label => const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, height: 1.35),
  TV.caption => const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, height: 1.35),
};

/// Themed text. `muted`/`faint` pick secondary ink; `color` overrides.
class T extends StatelessWidget {
  const T(
    this.text, {
    super.key,
    this.v = TV.body,
    this.color,
    this.muted = false,
    this.faint = false,
    this.style,
    this.maxLines,
    this.align,
  });
  final String text;
  final TV v;
  final Color? color;
  final bool muted, faint;
  final TextStyle? style;
  final int? maxLines;
  final TextAlign? align;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final ink = color ?? (faint ? c.textFaint : (muted ? c.textMuted : c.text));
    return Text(
      text,
      maxLines: maxLines,
      overflow: maxLines != null ? TextOverflow.ellipsis : null,
      textAlign: align,
      style: textStyle(v).copyWith(color: ink).merge(style),
    );
  }
}

// ───────────────────────── Layout ─────────────────────────

/// Bottom padding that leaves room for the floating tab bar.
const tabBarSpace = 110.0;

/// Scrollable screen body with standard padding and spacing between children.
class Screen extends StatelessWidget {
  const Screen({super.key, required this.children, this.tabs = false, this.header});
  final List<Widget> children;
  final bool tabs;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final bottom = tabs ? tabBarSpace : MediaQuery.paddingOf(context).bottom + 24;
    return Scaffold(
      backgroundColor: context.colors.bg,
      // Main tabs never resize for the keyboard (see Shell); pushed screens do.
      resizeToAvoidBottomInset: !tabs,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            ?header,
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.lg, bottom),
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                children: gap(children, Space.lg),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Insert a fixed vertical gap between widgets.
List<Widget> gap(List<Widget> items, double size, {bool horizontal = false}) {
  final out = <Widget>[];
  for (final w in items) {
    if (out.isNotEmpty) out.add(horizontal ? SizedBox(width: size) : SizedBox(height: size));
    out.add(w);
  }
  return out;
}

class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.title, this.subtitle, this.back = true, this.actions = const []});
  final String title;
  final String? subtitle;
  final bool back;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.sm),
      child: Row(
        children: [
          if (back) ...[
            AppIconButton(icon: 'chevron-back', tooltip: 'Back', onTap: () => Navigator.of(context).maybePop()),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                T(title, v: TV.h2, maxLines: 1),
                if (subtitle != null && subtitle!.isNotEmpty) T(subtitle!, v: TV.caption, muted: true, maxLines: 1),
              ],
            ),
          ),
          ...gap(actions, 8, horizontal: true),
        ],
      ),
    );
  }
}

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(Space.lg),
    this.color,
  });
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? c.card,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: c.dark && color == null ? Border.all(color: c.border) : null,
        boxShadow: c.dark
            ? null
            : [BoxShadow(color: c.shadow.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: child,
    );
    return onTap == null ? box : ScalePress(onTap: onTap, child: box);
  }
}

/// Gently scales its child down while pressed.
class ScalePress extends StatefulWidget {
  const ScalePress({super.key, required this.child, this.onTap, this.onLongPress});
  final Widget child;
  final VoidCallback? onTap, onLongPress;

  @override
  State<ScalePress> createState() => _ScalePressState();
}

class _ScalePressState extends State<ScalePress> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;
    final detector = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _set(true) : null,
      onTapUp: enabled ? (_) => _set(false) : null,
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              _set(false);
              HapticFeedback.mediumImpact();
              widget.onLongPress!();
            },
      child: AnimatedScale(
        scale: _down ? 0.97 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
    return enabled ? Semantics(container: true, button: true, child: detector) : detector;
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.action, this.onAction});
  final String title;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Flexible(child: T(title, v: TV.h3)),
      if (action != null)
        GestureDetector(
          onTap: onAction,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: T(action!, v: TV.label, color: context.colors.primary),
          ),
        ),
    ],
  );
}

class HairDivider extends StatelessWidget {
  const HairDivider({super.key});
  @override
  Widget build(BuildContext context) => Container(height: 0.5, color: context.colors.border);
}

/// A label/value line used on detail screens.
class DetailRow extends StatelessWidget {
  const DetailRow(this.label, this.value, {super.key, this.strong = false, this.valueColor});
  final String label, value;
  final bool strong;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        Expanded(child: T(label, v: TV.caption, muted: true)),
        const SizedBox(width: 8),
        T(value, v: strong ? TV.h3 : TV.label, color: valueColor),
      ],
    ),
  );
}

// ───────────────────────── Buttons ─────────────────────────

enum BtnVariant { primary, secondary, danger, ghost, success }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.title,
    required this.onTap,
    this.icon,
    this.variant = BtnVariant.primary,
    this.disabled = false,
    this.small = false,
    this.expand = true,
  });
  final String title;
  final VoidCallback onTap;
  final String? icon;
  final BtnVariant variant;
  final bool disabled, small, expand;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (bg, fg) = switch (variant) {
      BtnVariant.primary => (c.primary, Colors.white),
      BtnVariant.success => (c.income, Colors.white),
      BtnVariant.secondary => (c.primarySoft, c.primary),
      BtnVariant.danger => (c.expenseSoft, c.expense),
      BtnVariant.ghost => (Colors.transparent, c.textMuted),
    };
    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(appIcon(icon!), size: small ? 16 : 18, color: fg), const SizedBox(width: 8)],
        Flexible(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: fg, fontWeight: FontWeight.w700, fontSize: small ? 13 : 15),
          ),
        ),
      ],
    );
    return Opacity(
      opacity: disabled ? 0.5 : 1,
      child: ScalePress(
        onTap: disabled
            ? null
            : () {
                haptic();
                onTap();
              },
        child: Container(
          height: small ? 38 : 52,
          padding: EdgeInsets.symmetric(horizontal: small ? 14 : 20),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(small ? AppRadius.md : AppRadius.lg),
          ),
          child: content,
        ),
      ),
    );
  }
}

class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.color,
    this.bg,
    this.size = 40,
    this.tooltip,
  });
  final String icon;
  final VoidCallback onTap;
  final Color? color, bg;
  final double size;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      label: tooltip ?? icon,
      child: ScalePress(
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg ?? c.card, shape: BoxShape.circle),
          child: Icon(appIcon(icon), size: size * 0.5, color: color ?? c.text),
        ),
      ),
    );
  }
}

/// Rounded square with a tinted background and a coloured icon.
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, required this.color, this.size = 44});
  final String icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(color: tint(color, 0.13), borderRadius: BorderRadius.circular(size * 0.32)),
    child: Icon(appIcon(icon), size: size * 0.48, color: color),
  );
}

// ───────────────────────── Selection ─────────────────────────

class AppChip extends StatelessWidget {
  const AppChip({super.key, required this.label, this.active = false, this.onTap, this.icon, this.color});
  final String label;
  final bool active;
  final VoidCallback? onTap;
  final String? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final accent = color ?? c.primary;
    return GestureDetector(
      onTap: () {
        haptic();
        onTap?.call();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: active ? accent : c.card,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(color: active ? accent : c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(appIcon(icon!), size: 15, color: active ? Colors.white : c.textMuted),
              const SizedBox(width: 6),
            ],
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: active ? Colors.white : c.text, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SegOption<K> {
  const SegOption(this.key, this.label);
  final K key;
  final String label;
}

/// Segmented control with an animated sliding thumb.
class Segmented<K> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged, this.colorFor});
  final List<SegOption<K>> options;
  final K value;
  final ValueChanged<K> onChanged;
  final Color Function(K)? colorFor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final index = options.indexWhere((o) => o.key == value).clamp(0, options.length - 1);
    final n = options.length;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: c.cardAlt, borderRadius: BorderRadius.circular(AppRadius.md)),
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedAlign(
              alignment: Alignment(n == 1 ? 0 : -1 + 2 * index / (n - 1), 0),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: colorFor != null ? colorFor!(value) : c.card,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6, offset: const Offset(0, 2)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (final o in options)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      haptic();
                      onChanged(o.key);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Text(
                        o.label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                          color: o.key == value ? (colorFor != null ? Colors.white : c.text) : c.textMuted,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class ToggleRow extends StatelessWidget {
  const ToggleRow({super.key, required this.label, this.hint, required this.value, required this.onChanged, this.icon});
  final String label;
  final String? hint, icon;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          if (icon != null) ...[IconBadge(icon: icon!, color: c.primary, size: 36), const SizedBox(width: 12)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                T(label),
                if (hint != null) T(hint!, v: TV.caption, muted: true),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) {
              haptic();
              onChanged(v);
            },
            activeTrackColor: c.primary,
            activeThumbColor: Colors.white,
            inactiveTrackColor: c.border,
            inactiveThumbColor: Colors.white,
            trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Inputs ─────────────────────────

class Field extends StatelessWidget {
  const Field({super.key, required this.label, required this.child, this.hint});
  final String label;
  final Widget child;
  final String? hint;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      T(label, v: TV.label, muted: true),
      const SizedBox(height: 6),
      child,
      if (hint != null) ...[const SizedBox(height: 6), T(hint!, v: TV.caption, faint: true)],
    ],
  );
}

/// Bordered text field. Keeps its own controller in sync with [value].
class AppInput extends StatefulWidget {
  const AppInput({
    super.key,
    required this.value,
    required this.onChanged,
    this.icon,
    this.placeholder,
    this.keyboard = TextInputType.text,
    this.enabled = true,
    this.textAlign = TextAlign.start,
    this.onSubmitted,
    this.capitalize = TextCapitalization.sentences,
  });
  final String value;
  final ValueChanged<String> onChanged;
  final String? icon, placeholder;
  final TextInputType keyboard;
  final bool enabled;
  final TextAlign textAlign;
  final VoidCallback? onSubmitted;
  final TextCapitalization capitalize;

  @override
  State<AppInput> createState() => _AppInputState();
}

class _AppInputState extends State<AppInput> {
  late final _ctrl = TextEditingController(text: widget.value);

  @override
  void didUpdateWidget(AppInput old) {
    super.didUpdateWidget(old);
    if (widget.value != _ctrl.text) {
      _ctrl.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final numeric = widget.keyboard.decimal != null || widget.keyboard == TextInputType.number;
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          if (widget.icon != null) ...[
            Icon(appIcon(widget.icon!), size: 18, color: c.textFaint),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: TextField(
              controller: _ctrl,
              enabled: widget.enabled,
              onChanged: widget.onChanged,
              onSubmitted: (_) => widget.onSubmitted?.call(),
              keyboardType: widget.keyboard,
              textAlign: widget.textAlign,
              textCapitalization: numeric ? TextCapitalization.none : widget.capitalize,
              inputFormatters: numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))] : null,
              style: TextStyle(color: widget.enabled ? c.text : c.textMuted, fontSize: 15, fontWeight: FontWeight.w500),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: widget.placeholder,
                hintStyle: TextStyle(color: c.textFaint, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Large centred amount entry used at the top of forms.
class AmountInput extends StatefulWidget {
  const AmountInput({
    super.key,
    required this.value,
    required this.onChanged,
    required this.symbol,
    this.color,
    this.autofocus = false,
    this.enabled = true,
  });
  final String value, symbol;
  final ValueChanged<String> onChanged;
  final Color? color;
  final bool autofocus, enabled;

  @override
  State<AmountInput> createState() => _AmountInputState();
}

class _AmountInputState extends State<AmountInput> with SingleTickerProviderStateMixin {
  late final _ctrl = TextEditingController(text: widget.value);
  // Small "pop" of the number on every keystroke.
  late final _pop = AnimationController(vsync: this, duration: const Duration(milliseconds: 220));
  int _rejects = 0;

  @override
  void didUpdateWidget(AmountInput old) {
    super.didUpdateWidget(old);
    if (widget.value != _ctrl.text) _ctrl.text = widget.value;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _pop.dispose();
    super.dispose();
  }

  /// Rejects a second decimal point or more than 2 decimals, and shakes.
  TextEditingValue _filter(TextEditingValue o, TextEditingValue n) {
    final parts = n.text.split('.');
    final bad = parts.length > 2 || (parts.length == 2 && parts[1].length > 2) || n.text.length > 12;
    if (!bad) return n;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _rejects++);
    });
    haptic();
    return o;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduce = MediaQuery.of(context).disableAnimations;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: Space.md),
      child: Shake(
        trigger: _rejects,
        child: AnimatedBuilder(
          animation: _pop,
          builder: (context, child) => Transform.scale(scale: 1 + 0.07 * math.sin(_pop.value * math.pi), child: child),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                widget.symbol.trim(),
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w700, color: c.textMuted),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: IntrinsicWidth(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minWidth: 44, maxWidth: 280),
                    child: TextField(
                      controller: _ctrl,
                      enabled: widget.enabled,
                      autofocus: widget.autofocus,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                        TextInputFormatter.withFunction(_filter),
                      ],
                      onChanged: (v) {
                        if (!reduce) _pop.forward(from: 0);
                        widget.onChanged(v);
                      },
                      style: TextStyle(
                        fontSize: 44,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        color: widget.color ?? c.text,
                      ),
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: '0',
                        hintStyle: TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: c.textFaint),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── Feedback ─────────────────────────

class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, required this.color, this.height = 8, this.track});
  final double value;
  final Color color;
  final double height;
  final Color? track;

  @override
  Widget build(BuildContext context) {
    final v = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: track ?? context.colors.cardAlt,
        alignment: Alignment.centerLeft,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: v),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOutCubic,
          builder: (_, t, _) => FractionallySizedBox(
            widthFactor: t,
            child: Container(
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(height)),
            ),
          ),
        ),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill({super.key, required this.label, required this.color, this.bg});
  final String label;
  final Color color;
  final Color? bg;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg ?? tint(color, 0.12), borderRadius: BorderRadius.circular(AppRadius.pill)),
    child: Text(
      label,
      style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700),
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action, this.onAction});
  final String icon, title;
  final String? message, action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(color: c.primarySoft, borderRadius: BorderRadius.circular(22)),
            child: Icon(appIcon(icon), size: 30, color: c.primary),
          ),
          const SizedBox(height: 12),
          T(title, v: TV.h3, align: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 8),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 280),
              child: T(message!, v: TV.label, muted: true, align: TextAlign.center),
            ),
          ],
          if (action != null && onAction != null) ...[
            const SizedBox(height: 16),
            AppButton(title: action!, onTap: onAction!, small: true, expand: false),
          ],
        ],
      ),
    );
  }
}

/// Fade + slide in on first build, staggered by [index].
class FadeIn extends StatefulWidget {
  const FadeIn({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  State<FadeIn> createState() => _FadeInState();
}

class _FadeInState extends State<FadeIn> with SingleTickerProviderStateMixin {
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  late final _curve = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.index.clamp(0, 8) * 50), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _curve,
    child: SlideTransition(
      position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(_curve),
      child: widget.child,
    ),
  );
}

/// Indigo→violet gradient panel used for hero cards.
class GradientPanel extends StatelessWidget {
  const GradientPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
    this.radius = AppRadius.xl,
  });
  final Widget child;
  final EdgeInsets padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      width: double.infinity,
      padding: padding,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          colors: [c.primary, c.primaryAlt],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: child,
    );
  }
}

/// Small coloured dot + caption used in chart legends.
class LegendDot extends StatelessWidget {
  const LegendDot({super.key, required this.color, required this.label, this.round = false});
  final Color color;
  final String label;
  final bool round;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: round ? 8 : 10,
        height: round ? 8 : 10,
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(round ? 4 : 3)),
      ),
      const SizedBox(width: 6),
      T(label, v: TV.caption, muted: true),
    ],
  );
}

// ───────────────────────── Dialogs ─────────────────────────

/// Ask the user to confirm. Returns true when they pick [confirm].
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirm = 'Delete',
  bool destructive = true,
  String cancel = 'Cancel',
}) async {
  final c = context.colors;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: T(title, v: TV.h3),
      content: T(message, v: TV.label, muted: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(cancel, style: TextStyle(color: c.textMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(
            confirm,
            style: TextStyle(color: destructive ? c.expense : c.primary, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
  return result ?? false;
}

Future<void> infoDialog(BuildContext context, String title, [String? message]) {
  final c = context.colors;
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: T(title, v: TV.h3),
      content: message == null ? null : T(message, v: TV.label, muted: true),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(
            'OK',
            style: TextStyle(color: c.primary, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

/// One choice in an [showOptionSheet].
class SheetOption<V> {
  const SheetOption(this.value, this.label, {this.icon, this.color});
  final V value;
  final String label;
  final String? icon;
  final Color? color;
}

/// Bottom sheet that shows every option at once as wrapping chips.
/// Returns the picked option, or null if dismissed.
Future<SheetOption<V>?> showOptionSheet<V>(
  BuildContext context, {
  required String title,
  required List<SheetOption<V>> options,
  required V selected,
}) {
  final c = context.colors;
  return showModalBottomSheet<SheetOption<V>>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    backgroundColor: c.card,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg))),
    builder: (ctx) => ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(ctx).height * 0.8),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(Space.lg, 12, Space.lg, Space.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: c.border, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: Space.md),
            T(title, v: TV.h3),
            const SizedBox(height: Space.md),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final o in options)
                  AppChip(
                    label: o.label,
                    icon: o.icon,
                    color: o.color,
                    active: o.value == selected,
                    onTap: () => Navigator.of(ctx).pop(o),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

/// Dropdown-style button that shows the current choice and opens a sheet.
/// [highlighted] marks a non-default choice so active filters stand out.
class SelectButton extends StatelessWidget {
  const SelectButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.iconColor,
    this.highlighted = false,
  });
  final String label;
  final String? icon;
  final Color? iconColor;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = highlighted ? c.primary : c.text;
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: GestureDetector(
        onTap: () {
          haptic();
          onTap();
        },
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: highlighted ? c.primarySoft : c.card,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(color: highlighted ? c.primary : c.border),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(appIcon(icon!), size: 16, color: iconColor ?? (highlighted ? c.primary : c.textMuted)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13),
                ),
              ),
              const SizedBox(width: 4),
              Icon(appIcon('chevron-down'), size: 16, color: c.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tappable settings row: icon, title, optional subtitle and a trailing chevron
/// (or an "open" icon for links that leave the app).
class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.external = false,
  });
  final String icon, title;
  final String? subtitle;
  final VoidCallback onTap;
  final bool external;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: subtitle == null ? title : '$title, $subtitle',
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              IconBadge(icon: icon, color: c.primary, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    T(
                      title,
                      v: TV.body,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    if (subtitle != null) T(subtitle!, v: TV.caption, muted: true),
                  ],
                ),
              ),
              Icon(appIcon(external ? 'open-outline' : 'chevron-forward'), size: 18, color: c.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}
