import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/format.dart';
import '../core/theme.dart';
import '../data/store.dart';

/// Animated launch screen shown over the app on start.
///
/// First a short "money tracking" scene: a balance line draws itself while
/// the balance counts up and income (green) and expense (red) entries slide
/// in. Everything then pulls into the centre, where the logo builds itself: the tile pops in, the baseline draws across, the
/// three bars grow one after another, and the dot drops in with a bounce.
/// Then "MoneyEntri" appears letter by letter with the tagline. The whole
/// thing fades out and removes itself after about 4 seconds.
///
/// Android's native launch screen (flutter_native_splash) is a plain
/// background in the same colour, so the hand-off is seamless.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({super.key, required this.child});
  final Widget child;

  /// Becomes true when the splash has finished (App lock waits for this).
  static final done = ValueNotifier<bool>(false);

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay> with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _total),
  );
  late final AnimationController _exit = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  bool _done = false;
  bool _started = false;

  /// The logo starts once the tracking scene has pulled into the centre.
  static const _logo = 1450;
  static const _total = _logo + 1900;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Respect the system "remove animations" setting.
    if (MediaQuery.of(context).disableAnimations) _intro.value = 1;
    _run();
  }

  Future<void> _run() async {
    await _intro.forward();
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    await _exit.forward();
    if (mounted) setState(() => _done = true);
    SplashOverlay.done.value = true;
  }

  @override
  void dispose() {
    _intro.dispose();
    _exit.dispose();
    super.dispose();
  }

  /// Like [_p], but in the logo's own time (0 = when the logo starts).
  double _l(int start, int end, [Curve curve = Curves.easeOutCubic]) => _p(_logo + start, _logo + end, curve);

  /// Progress of [_intro] between [start] and [end] (in ms), with a curve.
  double _p(int start, int end, [Curve curve = Curves.easeOutCubic]) {
    final t = ((_intro.value * _total - start) / (end - start)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  /// Sample entries for the tracking scene: (label, amount, income?, x, y).
  static const _entries = [
    ('Salary', 25000, true, -40.0, -178.0),
    ('Food', 450, false, 60.0, -124.0),
    ('Car EMI', 1200, false, -55.0, 112.0),
    ('Refund', 800, true, 50.0, 166.0),
  ];

  /// Balance line + counter + income/expense entries, before the logo.
  Widget _trackingScene(AppColors c, String currency) {
    // Everything pulls into the centre just before the logo appears.
    final gather = _p(1150, 1550, Curves.easeInCubic);
    final keep = 1 - gather;
    Widget place(Offset at, Widget child) => Transform.translate(
      offset: at * keep,
      child: Transform.scale(
        scale: 1 - 0.7 * gather,
        child: Opacity(opacity: keep, child: child),
      ),
    );
    final line = _p(0, 1100, Curves.easeInOutCubic);
    return Stack(
      alignment: Alignment.center,
      children: [
        place(const Offset(0, 8), CustomPaint(size: const Size(240, 96), painter: _TrackPainter(line, c.income))),
        place(
          const Offset(0, -64),
          Opacity(
            opacity: _p(100, 400),
            child: Text(
              formatMoney((24150 * line).round(), currency),
              style: TextStyle(
                color: c.text,
                fontSize: 22,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
        for (var i = 0; i < _entries.length; i++)
          () {
            final (label, amount, income, x, y) = _entries[i];
            final t = _p(150 + i * 200, 550 + i * 200, Curves.easeOutBack);
            // Income slides in from the left, expenses from the right.
            return place(
              Offset(x + (income ? -60 : 60) * (1 - t), y),
              Opacity(
                opacity: t.clamp(0.0, 1.0),
                child: _EntryPill(
                  label: label,
                  amount: formatSigned(amount, currency, income: income),
                  income: income,
                  colors: c,
                ),
              ),
            );
          }(),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    const name = 'MoneyEntri';
    final currency = context.read<AppStore>().settings.currency;
    // Keep the same tree shape before and after the splash. Returning the
    // child on its own once done would rebuild everything below it from
    // scratch, including App lock, which then asked for the fingerprint again.
    return Stack(
      children: [
        widget.child,
        if (!_done)
          Positioned.fill(
            child: Semantics(
              label: 'MoneyEntri',
              container: true,
              excludeSemantics: true,
              child: AnimatedBuilder(
                animation: Listenable.merge([_intro, _exit]),
                builder: (context, _) {
                  final exit = Curves.easeIn.transform(_exit.value);
                  return Opacity(
                    opacity: 1 - exit,
                    child: ColoredBox(
                      color: c.bg,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          if (_intro.value * _total < _logo + 200) _trackingScene(c, currency),
                          Transform.scale(
                            scale: 1 + exit * 0.15,
                            child: CustomPaint(
                              size: const Size.square(112),
                              painter: _LogoPainter(
                                tile: _l(0, 450, Curves.easeOutBack),
                                base: _l(300, 650),
                                bars: [
                                  _l(450, 900, Curves.easeOutBack),
                                  _l(580, 1030, Curves.easeOutBack),
                                  _l(710, 1160, Curves.easeOutBack),
                                ],
                                dot: _l(950, 1450, Curves.bounceOut),
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(0, 112),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    for (var i = 0; i < name.length; i++)
                                      _Letter(name[i], _l(1050 + i * 55, 1400 + i * 55), c.text),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Opacity(
                                  opacity: _l(1450, 1850),
                                  child: Text(
                                    'Expenses · EMIs · Bills',
                                    style: TextStyle(
                                      color: c.textMuted,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      letterSpacing: 0.4,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            bottom: 40 + MediaQuery.paddingOf(context).bottom,
                            child: Opacity(
                              opacity: _l(1500, 1900),
                              child: Text(
                                'Your money, on your phone only',
                                style: TextStyle(
                                  color: c.textFaint,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  decoration: TextDecoration.none,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
      ],
    );
  }
}

/// One letter of the name: fades in while rising into place.
class _Letter extends StatelessWidget {
  const _Letter(this.char, this.t, this.color);
  final String char;
  final double t;
  final Color color;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: t,
    child: Transform.translate(
      offset: Offset(0, (1 - t) * 14),
      child: Text(
        char,
        style: TextStyle(
          color: color,
          fontSize: 32,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.5,
          decoration: TextDecoration.none,
        ),
      ),
    ),
  );
}

/// Draws the MoneyEntri logo (same geometry as assets/icon/icon.png, on a
/// 1024 grid) with each part driven by its own progress value.
class _LogoPainter extends CustomPainter {
  _LogoPainter({required this.tile, required this.base, required this.bars, required this.dot});
  final double tile, base, dot;
  final List<double> bars;

  static const _barX = [296.0, 457.0, 618.0];
  static const _barTop = [535.0, 420.0, 294.0];
  static const _barW = 111.0, _barBottom = 731.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (tile <= 0) return;
    final k = size.width / 1024;
    canvas.save();
    canvas.scale(k);
    // Tile: pops in from the centre.
    canvas.translate(512, 512);
    canvas.scale(math.max(0, tile));
    canvas.translate(-512, -512);
    final rect = const Rect.fromLTWH(0, 0, 1024, 1024);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(220)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4F46E5), Color(0xFF7C3AED)],
        ).createShader(rect),
    );
    final white = Paint()..color = const Color(0xFFFFFFFF);
    // Baseline: draws left to right.
    if (base > 0) {
      canvas.drawRRect(RRect.fromLTRBR(261, 770, 261 + (763 - 261) * base, 812, const Radius.circular(21)), white);
    }
    // Bars: grow up from the baseline, one after another.
    for (var i = 0; i < 3; i++) {
      final t = math.max(0.0, bars[i]);
      if (t <= 0) continue;
      final h = (_barBottom - _barTop[i]) * t;
      canvas.drawRRect(
        RRect.fromLTRBR(_barX[i], _barBottom - h, _barX[i] + _barW, _barBottom, Radius.circular(math.min(40, h / 2))),
        white,
      );
    }
    // Dot: drops in from above and bounces into place.
    if (dot > 0) {
      canvas.drawCircle(
        Offset(673, 190 - (1 - dot) * 260),
        47,
        white..color = Color.fromRGBO(255, 255, 255, math.min(1, dot * 3)),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.tile != tile || old.base != base || old.dot != dot || old.bars.join() != bars.join();
}

/// A small income/expense entry card used in the tracking scene.
class _EntryPill extends StatelessWidget {
  const _EntryPill({required this.label, required this.amount, required this.income, required this.colors});
  final String label, amount;
  final bool income;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final c = colors;
    final tone = income ? c.income : c.expense;
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: c.border),
        boxShadow: [BoxShadow(color: c.shadow.withValues(alpha: 0.08), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: income ? c.incomeSoft : c.expenseSoft, shape: BoxShape.circle),
            child: Icon(income ? Icons.south_west_rounded : Icons.north_east_rounded, size: 16, color: tone),
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: TextStyle(
              color: c.textMuted,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.none,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            amount,
            style: TextStyle(color: tone, fontSize: 14, fontWeight: FontWeight.w800, decoration: TextDecoration.none),
          ),
        ],
      ),
    );
  }
}

/// A rising balance line that draws itself, with a dot tracking its tip.
class _TrackPainter extends CustomPainter {
  _TrackPainter(this.t, this.color);
  final double t;
  final Color color;

  static const _points = [
    Offset(0, .62),
    Offset(.14, .5),
    Offset(.27, .64),
    Offset(.41, .38),
    Offset(.55, .5),
    Offset(.7, .26),
    Offset(.84, .34),
    Offset(1, .08),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final pts = [for (final p in _points) Offset(p.dx * size.width, p.dy * size.height)];
    // Smooth curve through the points.
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final a = pts[i - 1], b = pts[i];
      final mx = (a.dx + b.dx) / 2;
      path.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }
    final metric = path.computeMetrics().first;
    final drawn = metric.extractPath(0, metric.length * t);
    final tip = metric.getTangentForOffset(metric.length * t)!.position;

    // Soft fill under the drawn part.
    final fill = Path.from(drawn)
      ..lineTo(tip.dx, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.22), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      drawn,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // Tracking dot with a white ring.
    canvas.drawCircle(tip, 7, Paint()..color = const Color(0xFFFFFFFF));
    canvas.drawCircle(tip, 5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_TrackPainter old) => old.t != t || old.color != color;
}
