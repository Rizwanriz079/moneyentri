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
