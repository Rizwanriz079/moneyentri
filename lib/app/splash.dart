import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Animated launch screen shown over the app on start.
///
/// The logo builds itself: the tile pops in, the baseline draws across, the
/// three bars grow one after another, and the dot drops in with a bounce.
/// Then "FinTrack" appears letter by letter with the tagline. The whole
/// thing fades out and removes itself after about 2.5 seconds.
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
  late final AnimationController _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 1900));
  late final AnimationController _exit = AnimationController(vsync: this, duration: const Duration(milliseconds: 380));
  bool _done = false;
  bool _started = false;

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
    await Future<void>.delayed(const Duration(milliseconds: 550));
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

  /// Progress of [_intro] between [start] and [end] (in ms), with a curve.
  double _p(int start, int end, [Curve curve = Curves.easeOutCubic]) {
    final t = ((_intro.value * 1900 - start) / (end - start)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    if (_done) return widget.child;
    final c = context.colors;
    const name = 'FinTrack';
    return Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: Semantics(
            label: 'FinTrack',
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
                        Transform.scale(
                          scale: 1 + exit * 0.15,
                          child: CustomPaint(
                            size: const Size.square(112),
                            painter: _LogoPainter(
                              tile: _p(0, 450, Curves.easeOutBack),
                              base: _p(300, 650),
                              bars: [
                                _p(450, 900, Curves.easeOutBack),
                                _p(580, 1030, Curves.easeOutBack),
                                _p(710, 1160, Curves.easeOutBack),
                              ],
                              dot: _p(950, 1450, Curves.bounceOut),
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
                                    _Letter(name[i], _p(1050 + i * 55, 1400 + i * 55), c.text),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Opacity(
                                opacity: _p(1450, 1850),
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
                            opacity: _p(1500, 1900),
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

/// Draws the FinTrack logo (same geometry as assets/icon/icon.png, on a
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
      canvas.drawRRect(
        RRect.fromLTRBR(261, 770, 261 + (763 - 261) * base, 812, const Radius.circular(21)),
        white,
      );
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
      canvas.drawCircle(Offset(673, 190 - (1 - dot) * 260), 47, white..color = Color.fromRGBO(255, 255, 255, math.min(1, dot * 3)));
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LogoPainter old) =>
      old.tile != tile || old.base != base || old.dot != dot || old.bars.join() != bars.join();
}
