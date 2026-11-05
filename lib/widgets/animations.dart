import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/icons.dart';
import '../core/theme.dart';

bool _reduceMotion(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

// ───────────────────────── Wallet + coins ─────────────────────────

/// Wallet illustration that reacts while an amount is typed.
///
/// Every time [amount] grows, a coin flies: for income it drops into the
/// wallet, for an expense it pops out of it. The wallet squashes on each coin
/// and its ring fills as the amount gets bigger. Bump [amount] on every
/// keystroke; when it shrinks (backspace) the wallet only gives a small nudge.
class WalletCoins extends StatefulWidget {
  const WalletCoins({super.key, required this.amount, required this.income, required this.color});
  final double amount;
  final bool income;
  final Color color;

  @override
  State<WalletCoins> createState() => _WalletCoinsState();
}

class _Coin {
  _Coin(this.born, this.dx, this.spin, this.income);
  final Duration born;
  final double dx, spin;

  /// Direction is fixed when the coin is created, so switching between
  /// Expense and Income mid-flight doesn't reverse coins already in the air.
  final bool income;
}

class _WalletCoinsState extends State<WalletCoins> with TickerProviderStateMixin {
  static const _coinLife = Duration(milliseconds: 650);
  static const _maxCoins = 5;

  /// Stage height: tall enough that coins never leave this widget, so they
  /// can't fly over the Expense/Income switch above it.
  static const _stage = 150.0;
  static const _walletTop = 76.0; // 64 wallet + 2 × 6 margin
  final _coins = <_Coin>[];
  final _rnd = math.Random();
  late final Ticker _ticker = createTicker(_tick);

  /// Time on the ticker's clock. The ticker restarts from zero every time it
  /// starts, so this is reset together with it (see [_addCoin]).
  Duration _now = Duration.zero;
  late final AnimationController _squash = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  @override
  void didUpdateWidget(WalletCoins old) {
    super.didUpdateWidget(old);
    if (widget.amount == old.amount || _reduceMotion(context)) return;
    if (widget.amount > old.amount) {
      _addCoin();
      // Income: the wallet squashes when the coin lands; expense: right away.
      final income = widget.income;
      Future.delayed(income ? const Duration(milliseconds: 380) : Duration.zero, () {
        if (mounted) _squash.forward(from: 0);
      });
    } else {
      _squash.forward(from: 0.5);
    }
  }

  void _addCoin() {
    if (!_ticker.isActive) {
      // A stopped ticker starts counting from zero again; reset our clock with
      // it, otherwise new coins look "not born yet" and freeze in place.
      _coins.clear();
      _now = Duration.zero;
      _ticker.start();
    }
    if (_coins.length >= _maxCoins) _coins.removeAt(0);
    _coins.add(_Coin(_now, (_rnd.nextDouble() - 0.5) * 36, (_rnd.nextDouble() - 0.5) * 2, widget.income));
  }

  void _tick(Duration elapsed) {
    _now = elapsed;
    _coins.removeWhere((c) => elapsed - c.born >= _coinLife);
    if (_coins.isEmpty) _ticker.stop();
    setState(() {});
  }

  @override
  void dispose() {
    _ticker.dispose();
    _squash.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Ring fills on a log scale: ₹10 → small, ₹1,00,000+ → full.
    final fill = widget.amount <= 0 ? 0.0 : (math.log(widget.amount + 1) / math.ln10 / 5).clamp(0.08, 1.0);
    return SizedBox(
      width: 120,
      height: _stage,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        alignment: Alignment.bottomCenter,
        children: [
          Positioned(
            bottom: 0,
            child: TweenAnimationBuilder<double>(
              tween: Tween(end: fill),
              duration: const Duration(milliseconds: 450),
              curve: Curves.easeOutCubic,
              builder: (context, v, child) => CustomPaint(
                painter: _RingPainter(progress: v, color: widget.color, track: c.border),
                child: child,
              ),
              child: AnimatedBuilder(
                animation: _squash,
                builder: (context, child) {
                  // Quick squash-and-stretch: wide & short, then back.
                  final t = _squash.isAnimating ? math.sin(_squash.value * math.pi) : 0.0;
                  return Transform(
                    alignment: Alignment.bottomCenter,
                    transform: Matrix4.diagonal3Values(1 + 0.12 * t, 1 - 0.12 * t, 1),
                    child: child,
                  );
                },
                child: Container(
                  width: 64,
                  height: 64,
                  margin: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: tint(widget.color, 0.14), shape: BoxShape.circle),
                  child: Icon(appIcon('wallet'), size: 30, color: widget.color),
                ),
              ),
            ),
          ),
          for (final coin in _coins) _coinWidget(coin),
        ],
      ),
    );
  }

  Widget _coinWidget(_Coin coin) {
    final t = ((_now - coin.born).inMicroseconds / _coinLife.inMicroseconds).clamp(0.0, 1.0);
    const coinSize = 22.0;
    // Coin travels between the wallet's mouth and the top of the stage.
    const low = _walletTop - coinSize - 6; // just inside the wallet's top edge
    const high = _stage - coinSize - 4; // top of the stage
    final double bottom, opacity, scale;
    if (coin.income) {
      // Falls from the top into the wallet, shrinking as it goes in.
      final e = Curves.easeInQuad.transform(t);
      bottom = high - e * (high - low);
      opacity = t < 0.15 ? t / 0.15 : (t > 0.85 ? (1 - t) / 0.15 : 1);
      scale = 1 - 0.3 * Curves.easeIn.transform(t);
    } else {
      // Pops out of the wallet and rises, fading near the top.
      final e = Curves.easeOutCubic.transform(t);
      bottom = low + e * (high - low);
      opacity = t < 0.12 ? t / 0.12 : 1 - Curves.easeIn.transform((t - 0.12) / 0.88);
      scale = 0.7 + 0.3 * Curves.easeOutBack.transform(math.min(1, t * 3));
    }
    return Positioned(
      bottom: bottom,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(coin.dx * (coin.income ? (1 - t) : t), 0),
          child: Transform(
            alignment: Alignment.center,
            // Shrink/grow plus a spin around the vertical axis so it "flips".
            transform: Matrix4.identity()
              ..scaleByDouble(scale, scale, 1, 1)
              ..rotateY(t * math.pi * 2 * (1 + coin.spin.abs())),
            child: const _CoinFace(),
          ),
        ),
      ),
    );
  }
}

class _CoinFace extends StatelessWidget {
  const _CoinFace();

  @override
  Widget build(BuildContext context) => Container(
    width: 22,
    height: 22,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFFDE68A), Color(0xFFF59E0B)],
      ),
      border: Border.all(color: const Color(0xFFD97706), width: 1.5),
      boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 2))],
    ),
    alignment: Alignment.center,
    child: Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFB45309), width: 1.4),
      ),
    ),
  );
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color, required this.track});
  final double progress;
  final Color color, track;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.width / 2 - 1.5;
    final center = size.center(Offset.zero);
    canvas.drawCircle(
      center,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = track,
    );
    if (progress <= 0) return;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: r),
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.progress != progress || old.color != color || old.track != track;
}

// ───────────────────────── Liquid jar ─────────────────────────

/// Round jar that fills with liquid as an amount is typed.
///
/// The level rises with the amount (log scale: ₹10 is a little, ₹1 lakh is
/// nearly full). Waves move gently all the time; each keystroke makes the
/// liquid slosh and sends a few bubbles up. The currency symbol in the middle
/// turns white where the liquid covers it.
///
/// Time comes from the frame ticker. The ticker only stops for "reduce
/// motion"; if it restarts, its clock is rebased so time never jumps back
/// (the cause of the old frozen-coin bug).
class AmountJar extends StatefulWidget {
  const AmountJar({super.key, required this.amount, required this.color, required this.symbol, this.size = 112});
  final double amount;
  final Color color;
  final String symbol;
  final double size;

  @override
  State<AmountJar> createState() => _AmountJarState();
}

class _Bubble {
  _Bubble(this.bornMs, this.x, this.radius, this.drift);
  final double bornMs, x, radius, drift;
}

class _AmountJarState extends State<AmountJar> with SingleTickerProviderStateMixin {
  static const _bubbleLifeMs = 1100.0;
  static const _levelMs = 650.0;
  final _rnd = math.Random();
  final _bubbles = <_Bubble>[];
  late final Ticker _ticker = createTicker((elapsed) => setState(() => _nowMs = _baseMs + elapsed.inMicroseconds / 1000));
  double _nowMs = 0, _baseMs = 0;
  late double _fromLevel = _levelFor(widget.amount), _toLevel = _fromLevel;
  double _changedMs = -10000;

  static double _levelFor(double amount) =>
      amount <= 0 ? 0.08 : (0.14 + 0.78 * (math.log(amount + 1) / math.ln10 / 5)).clamp(0.14, 0.92);

  double get _ms => _nowMs;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Gentle waves run while the jar is on screen, unless motion is reduced.
    if (_reduceMotion(context)) {
      if (_ticker.isActive) _ticker.stop();
    } else if (!_ticker.isActive) {
      _baseMs = _nowMs; // a restarted ticker counts from zero again
      _ticker.start();
    }
  }

  @override
  void didUpdateWidget(AmountJar old) {
    super.didUpdateWidget(old);
    if (widget.amount == old.amount) return;
    final now = _ms;
    _fromLevel = _currentLevel(now);
    _toLevel = _levelFor(widget.amount);
    _changedMs = now;
    if (widget.amount > old.amount && !_reduceMotion(context)) {
      _bubbles.removeWhere((b) => now - b.bornMs > _bubbleLifeMs);
      for (var i = 0; i < 3 && _bubbles.length < 12; i++) {
        _bubbles.add(
          _Bubble(now + i * 70, 0.25 + _rnd.nextDouble() * 0.5, 2.5 + _rnd.nextDouble() * 3, _rnd.nextDouble() - 0.5),
        );
      }
    }
    if (_reduceMotion(context)) setState(() {});
  }

  double _currentLevel(double now) {
    if (_reduceMotion(context)) return _toLevel;
    final t = ((now - _changedMs) / _levelMs).clamp(0.0, 1.0);
    return _fromLevel + (_toLevel - _fromLevel) * Curves.easeOutBack.transform(t);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final now = _ms;
    final reduce = _reduceMotion(context);
    _bubbles.removeWhere((b) => now - b.bornMs > _bubbleLifeMs);
    // Slosh: the waves get taller right after a keystroke, then calm down.
    final since = now - _changedMs;
    final slosh = reduce ? 0.0 : math.exp(-since / 420) * math.cos(since / 90);
    return Semantics(
      excludeSemantics: true,
      child: SizedBox.square(
        dimension: widget.size,
        child: CustomPaint(
          painter: _JarPainter(
            level: _currentLevel(now).clamp(0.0, 1.0),
            phase: reduce ? 0 : now / 1000 * math.pi * 1.4,
            amp: 3.5 + 7 * slosh.abs(),
            tilt: 0.12 * slosh,
            color: widget.color,
            ring: tint(widget.color, 0.28),
            back: tint(widget.color, 0.08),
            symbol: widget.symbol.trim(),
            bubbles: [
              for (final b in _bubbles)
                if (now >= b.bornMs) (b, ((now - b.bornMs) / _bubbleLifeMs).clamp(0.0, 1.0)),
            ],
          ),
        ),
      ),
    );
  }
}

class _JarPainter extends CustomPainter {
  _JarPainter({
    required this.level,
    required this.phase,
    required this.amp,
    required this.tilt,
    required this.color,
    required this.ring,
    required this.back,
    required this.symbol,
    required this.bubbles,
  });
  final double level, phase, amp, tilt;
  final Color color, ring, back;
  final String symbol;
  final List<(_Bubble, double)> bubbles;

  Path _wave(Rect r, double offset, double speed, double ampScale) {
    final top = r.bottom - level * r.height;
    final path = Path()..moveTo(r.left, r.bottom);
    for (var x = 0.0; x <= r.width; x += 2) {
      final k = x / r.width;
      final y =
          top +
          (k - 0.5) * tilt * r.height +
          amp * ampScale * math.sin(k * math.pi * 2 * 1.15 + phase * speed + offset);
      path.lineTo(r.left + x, y);
    }
    return path
      ..lineTo(r.right, r.bottom)
      ..close();
  }

  void _symbol(Canvas canvas, Rect r, Color c) {
    final tp = TextPainter(
      text: TextSpan(
        text: symbol,
        style: TextStyle(color: c, fontSize: r.width * 0.36, fontWeight: FontWeight.w800, height: 1),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, r.center - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Offset.zero & size;
    final inner = outer.deflate(7);
    canvas.drawCircle(
      outer.center,
      size.width / 2 - 2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = ring,
    );
    canvas.save();
    canvas.clipPath(Path()..addOval(inner));
    canvas.drawRect(inner, Paint()..color = back);
    _symbol(canvas, inner, color);
    canvas.drawPath(_wave(inner, 1.8, 1.25, 0.8), Paint()..color = color.withValues(alpha: 0.35));
    final front = _wave(inner, 0, 1, 1);
    canvas.drawPath(front, Paint()..color = color);
    // Inside the liquid: white symbol and rising bubbles.
    canvas.clipPath(front);
    _symbol(canvas, inner, Colors.white);
    final top = inner.bottom - level * inner.height;
    for (final (b, t) in bubbles) {
      final y = inner.bottom - 4 - (inner.bottom - 4 - top) * Curves.easeOut.transform(t);
      final x = inner.left + inner.width * b.x + b.drift * 10 * math.sin(t * math.pi * 3);
      canvas.drawCircle(
        Offset(x, y),
        b.radius * (0.7 + 0.3 * t),
        Paint()..color = Colors.white.withValues(alpha: 0.55 * (1 - t)),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_JarPainter old) => true;
}

// ───────────────────────── Success ─────────────────────────

/// Full-screen success animation: a circle pops in, a check mark draws itself,
/// coins burst outward, then the title and amount fade in. Closes itself.
Future<void> showSuccessAnimation(
  BuildContext context, {
  required String title,
  String? subtitle,
  required Color color,
}) {
  if (_reduceMotion(context)) return Future.value();
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: Duration.zero,
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (_, _, _) => _SuccessView(title: title, subtitle: subtitle, color: color),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ),
  );
}

class _SuccessView extends StatefulWidget {
  const _SuccessView({required this.title, this.subtitle, required this.color});
  final String title;
  final String? subtitle;
  final Color color;

  @override
  State<_SuccessView> createState() => _SuccessViewState();
}

class _SuccessViewState extends State<_SuccessView> with SingleTickerProviderStateMixin {
  static const _ms = 1300;
  late final AnimationController _a = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: _ms),
  );
  final _angles = List.generate(10, (i) => i * math.pi * 2 / 10 + (i.isEven ? 0.15 : -0.1));

  @override
  void initState() {
    super.initState();
    _a.forward().then((_) {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  double _p(int start, int end, [Curve curve = Curves.easeOutCubic]) =>
      curve.transform(((_a.value * _ms - start) / (end - start)).clamp(0.0, 1.0));

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      label: [widget.title, widget.subtitle].whereType<String>().join(', '),
      child: AnimatedBuilder(
        animation: _a,
        builder: (context, _) {
          final pop = _p(0, 380, Curves.easeOutBack);
          final check = _p(250, 600);
          final burst = _p(300, 900);
          final text = _p(450, 750);
          return ColoredBox(
            color: c.bg.withValues(alpha: 0.98 * _p(0, 200)),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Soft ripple behind the circle.
                        Container(
                          width: 96 + 90 * burst,
                          height: 96 + 90 * burst,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: tint(widget.color, 0.18 * (1 - burst)),
                          ),
                        ),
                        for (final a in _angles)
                          Transform.translate(
                            offset: Offset(math.cos(a), math.sin(a)) * (50 + 56 * burst),
                            child: Opacity(
                              opacity: burst <= 0 ? 0 : (1 - burst).clamp(0.0, 1.0),
                              child: Transform.scale(scale: 0.6 + 0.4 * (1 - burst), child: const _CoinFace()),
                            ),
                          ),
                        Transform.scale(
                          scale: pop,
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: widget.color,
                              boxShadow: [
                                BoxShadow(color: tint(widget.color, 0.35), blurRadius: 24, offset: const Offset(0, 10)),
                              ],
                            ),
                            child: CustomPaint(painter: _CheckPainter(check)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Opacity(
                    opacity: text,
                    child: Transform.translate(
                      offset: Offset(0, 10 * (1 - text)),
                      child: Column(
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: c.text,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              decoration: TextDecoration.none,
                            ),
                          ),
                          if (widget.subtitle != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.subtitle!,
                              style: TextStyle(
                                color: widget.color,
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                decoration: TextDecoration.none,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// White check mark that draws itself as [t] goes 0 → 1.
class _CheckPainter extends CustomPainter {
  _CheckPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0) return;
    final s = size.width;
    final path = Path()
      ..moveTo(s * 0.28, s * 0.52)
      ..lineTo(s * 0.44, s * 0.67)
      ..lineTo(s * 0.73, s * 0.37);
    final metric = path.computeMetrics().first;
    canvas.drawPath(
      metric.extractPath(0, metric.length * t),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.085
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckPainter old) => old.t != t;
}

// ───────────────────────── Shake ─────────────────────────

/// Shakes its child sideways whenever [trigger] changes (e.g. invalid input).
class Shake extends StatefulWidget {
  const Shake({super.key, required this.trigger, required this.child});
  final int trigger;
  final Widget child;

  @override
  State<Shake> createState() => _ShakeState();
}

class _ShakeState extends State<Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));

  @override
  void didUpdateWidget(Shake old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && !_reduceMotion(context)) _a.forward(from: 0);
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _a,
    builder: (context, child) =>
        Transform.translate(offset: Offset(math.sin(_a.value * math.pi * 6) * 10 * (1 - _a.value), 0), child: child),
    child: widget.child,
  );
}
