import 'dart:math';

import 'package:flutter/material.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../domain/analytics.dart';
import 'ui.dart';

/// Index of the most recent non-zero value (falls back to the last index).
int lastNonZero(List<double> values) {
  for (var i = values.length - 1; i >= 0; i--) {
    if (values[i] > 0) return i;
  }
  return max(0, values.length - 1);
}

/// Bar that grows from the baseline when it appears or its value changes.
class _GrowBar extends StatelessWidget {
  const _GrowBar({required this.ratio, required this.color, required this.width, required this.height, this.dim = false});
  final double ratio, width, height;
  final Color color;
  final bool dim;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: ratio),
    duration: const Duration(milliseconds: 650),
    curve: Curves.easeOutCubic,
    builder: (_, t, _) => AnimatedOpacity(
      opacity: dim ? 0.35 : 1,
      duration: const Duration(milliseconds: 200),
      child: Container(
        width: width,
        height: ratio > 0 ? max(3, t * height) : 0,
        decoration: BoxDecoration(
          color: color,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
        ),
      ),
    ),
  );
}

class _ReadoutItem {
  const _ReadoutItem(this.label, this.value, this.color);
  final String label, value;
  final Color color;
}

/// Value line shown above a chart for the tapped/selected bar.
class _Readout extends StatelessWidget {
  const _Readout({required this.title, required this.items});
  final String title;
  final List<_ReadoutItem> items;

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 22),
    child: Wrap(
      spacing: 14,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        T(title, v: TV.label, muted: true),
        for (final i in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: i.color, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 6),
              Flexible(child: T('${i.label} ${i.value}', v: TV.label)),
            ],
          ),
      ],
    ),
  );
}

/// Shared plot frame: max label, gridlines and baseline.
class _Plot extends StatelessWidget {
  const _Plot({required this.height, required this.maxLabel, required this.children, this.midLine = false});
  final double height;
  final String maxLabel;
  final List<Widget> children;
  final bool midLine;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: height,
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.grid)),
      ),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            left: 0,
            child: T(maxLabel, v: TV.caption, faint: true, style: const TextStyle(fontSize: 10)),
          ),
          Positioned(top: 14, left: 0, right: 0, child: Container(height: 1, color: c.grid)),
          if (midLine)
            Positioned(
              top: 14 + (height - 14) / 2,
              left: 0,
              right: 0,
              child: Container(height: 1, color: c.grid),
            ),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: children),
        ],
      ),
    );
  }
}

class _AxisLabels extends StatelessWidget {
  const _AxisLabels({required this.labels, required this.selected});
  final List<String> labels;
  final int selected;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: T(
              labels[i],
              v: TV.caption,
              color: i == selected ? c.text : c.textFaint,
              align: TextAlign.center,
              maxLines: 1,
              style: const TextStyle(fontSize: 11),
            ),
          ),
      ],
    );
  }
}

/// Single-series bar chart. Tap a bar to read its exact value.
class BarChart extends StatefulWidget {
  const BarChart({
    super.key,
    required this.data,
    required this.color,
    required this.currency,
    this.height = 140,
    this.seriesLabel = 'Spent',
  });
  final List<BarDatum> data;
  final Color color;
  final String currency, seriesLabel;
  final double height;

  @override
  State<BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<BarChart> {
  late int sel = lastNonZero(widget.data.map((d) => d.value).toList());

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final maxV = max(1.0, data.map((d) => d.value).fold(0.0, max));
    final i = min(sel, data.length - 1);
    final cur = data.isEmpty ? null : data[i];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cur != null)
          _Readout(
            title: cur.title ?? cur.label,
            items: [_ReadoutItem(widget.seriesLabel, formatMoney(cur.value, widget.currency), widget.color)],
          ),
        const SizedBox(height: 10),
        _Plot(
          height: widget.height,
          maxLabel: formatCompact(maxV, widget.currency),
          children: [
            for (var k = 0; k < data.length; k++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => sel = k),
                  child: Align(
                    alignment: Alignment.bottomCenter,
                    child: _GrowBar(
                      ratio: data[k].value / maxV,
                      color: widget.color,
                      width: min(22, 220 / data.length),
                      height: widget.height - 18,
                      dim: k != i,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _AxisLabels(labels: [for (final d in data) d.label], selected: i),
      ],
    );
  }
}

/// Two-series grouped bars (e.g. income vs expense) with legend and tap readout.
class GroupedBarChart extends StatefulWidget {
  const GroupedBarChart({
    super.key,
    required this.data,
    required this.currency,
    required this.labels,
    required this.colors,
    this.height = 170,
  });
  final List<PairDatum> data;
  final String currency;
  final (String, String) labels;
  final (Color, Color) colors;
  final double height;

  @override
  State<GroupedBarChart> createState() => _GroupedBarChartState();
}

class _GroupedBarChartState extends State<GroupedBarChart> {
  late int sel = lastNonZero(widget.data.map((d) => d.a + d.b).toList());

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    final maxV = max(1.0, data.expand((d) => [d.a, d.b]).fold(0.0, max));
    final i = min(sel, data.length - 1);
    final cur = data.isEmpty ? null : data[i];
    final barW = min(14.0, 120 / max(1, data.length));
    final (la, lb) = widget.labels;
    final (ca, cb) = widget.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cur != null)
          _Readout(
            title: cur.title ?? cur.label,
            items: [_ReadoutItem(la, formatMoney(cur.a, widget.currency), ca), _ReadoutItem(lb, formatMoney(cur.b, widget.currency), cb)],
          ),
        const SizedBox(height: 10),
        _Plot(
          height: widget.height,
          maxLabel: formatCompact(maxV, widget.currency),
          midLine: true,
          children: [
            for (var k = 0; k < data.length; k++)
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => sel = k),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _GrowBar(ratio: data[k].a / maxV, color: ca, width: barW, height: widget.height - 18, dim: k != i),
                      const SizedBox(width: 2),
                      _GrowBar(ratio: data[k].b / maxV, color: cb, width: barW, height: widget.height - 18, dim: k != i),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _AxisLabels(labels: [for (final d in data) d.label], selected: i),
        const SizedBox(height: 10),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 6,
          children: [
            LegendDot(color: ca, label: la),
            LegendDot(color: cb, label: lb),
          ],
        ),
      ],
    );
  }
}

/// Donut with 2px surface gaps between segments; legend rows double as the table view.
class DonutChart extends StatefulWidget {
  const DonutChart({
    super.key,
    required this.slices,
    required this.currency,
    this.size = 170,
    this.stroke = 22,
    this.centerLabel = 'Total',
  });
  final List<Slice> slices;
  final String currency, centerLabel;
  final double size, stroke;

  @override
  State<DonutChart> createState() => _DonutChartState();
}

class _DonutChartState extends State<DonutChart> with SingleTickerProviderStateMixin {
  String? active;
  late final _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..forward();
  late final _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic);

  double get _total => widget.slices.fold(0.0, (s, x) => s + x.value);

  @override
  void didUpdateWidget(DonutChart old) {
    super.didUpdateWidget(old);
    if (old.slices.fold(0.0, (s, x) => s + x.value) != _total) _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggle(String key) => setState(() => active = active == key ? null : key);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = _total;
    final activeSlice = widget.slices.where((s) => s.key == active).firstOrNull;
    return Column(
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedBuilder(
                animation: _anim,
                builder: (_, _) => Opacity(
                  opacity: _anim.value,
                  child: Transform.rotate(
                    angle: (_anim.value - 1) * pi / 2,
                    child: Transform.scale(
                      scale: 0.85 + 0.15 * _anim.value,
                      child: GestureDetector(
                        onTapUp: (d) {
                          final key = _hitTest(d.localPosition, total);
                          if (key != null) _toggle(key);
                        },
                        child: CustomPaint(
                          size: Size.square(widget.size),
                          painter: _DonutPainter(widget.slices, total, widget.stroke, c.cardAlt, active),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    T(activeSlice?.label ?? widget.centerLabel, v: TV.caption, muted: true),
                    T(formatCompact(activeSlice?.value ?? total, widget.currency), v: TV.h2),
                    if (activeSlice != null && total > 0) T('${(activeSlice.value / total * 100).round()}%', v: TV.caption, muted: true),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final s in widget.slices)
          GestureDetector(
            onTap: () => _toggle(s.key),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
              decoration: BoxDecoration(color: active == s.key ? c.cardAlt : Colors.transparent, borderRadius: BorderRadius.circular(10)),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: hex(s.color), borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: T(s.label, v: TV.label, maxLines: 1)),
                  T('${total > 0 ? (s.value / total * 100).round() : 0}%', v: TV.label, muted: true),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 90,
                    child: T(formatMoney(s.value, widget.currency), v: TV.label, align: TextAlign.right),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  /// Which slice (if any) lies under a tap on the ring.
  String? _hitTest(Offset p, double total) {
    if (total <= 0) return null;
    final center = Offset(widget.size / 2, widget.size / 2);
    final d = (p - center).distance;
    final r = (widget.size - widget.stroke) / 2;
    if ((d - r).abs() > widget.stroke / 2 + 6) return null;
    var angle = atan2(p.dy - center.dy, p.dx - center.dx) + pi / 2;
    if (angle < 0) angle += 2 * pi;
    var acc = 0.0;
    for (final s in widget.slices) {
      acc += s.value / total * 2 * pi;
      if (angle <= acc) return s.key;
    }
    return null;
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.slices, this.total, this.stroke, this.track, this.active);
  final List<Slice> slices;
  final double total, stroke;
  final Color track;
  final String? active;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (size.width - stroke) / 2;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: r);
    canvas.drawCircle(
      size.center(Offset.zero),
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (total <= 0) return;
    final gapAngle = slices.length > 1 ? 2 / r : 0.0; // 2px surface gap between segments
    var start = -pi / 2;
    for (final s in slices) {
      final sweep = s.value / total * 2 * pi;
      final isActive = s.key == active;
      canvas.drawArc(
        rect,
        start,
        max(0.005, sweep - gapAngle),
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = isActive ? stroke + 6 : stroke
          ..color = hex(s.color).withValues(alpha: active != null && !isActive ? 0.3 : 1),
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter o) => o.slices != slices || o.total != total || o.active != active || o.track != track;
}

/// Circular progress ring (savings goals) that animates to [progress].
class ProgressRing extends StatelessWidget {
  const ProgressRing({super.key, required this.progress, required this.color, this.size = 180, this.stroke = 16, required this.child});
  final double progress, size, stroke;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final track = context.colors.cardAlt;
    return SizedBox(
      width: size,
      height: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: progress.clamp(0, 1).toDouble()),
        duration: const Duration(milliseconds: 900),
        curve: Curves.easeOutCubic,
        builder: (_, t, child) => CustomPaint(painter: _RingPainter(t, color, track, stroke), child: child),
        child: Center(child: child),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.t, this.color, this.track, this.stroke);
  final double t, stroke;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final r = (size.width - stroke) / 2;
    final center = size.center(Offset.zero);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );
    if (t <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -pi / 2,
      2 * pi * t,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter o) => o.t != t || o.color != color || o.track != track;
}
