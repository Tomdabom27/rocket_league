import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'car_link.dart';
import 'settings.dart';
import 'settings_page.dart';
import 'ui_kit.dart';

const _boostDrainSeconds = 3.0;
const _boostFillSeconds = 10.0;

const _redScore = 0;
const _blueScore = 0;

class PlayPage extends StatefulWidget {
  const PlayPage({super.key, required this.skipped});

  final bool skipped;

  @override
  State<PlayPage> createState() => _PlayPageState();
}

class _PlayPageState extends State<PlayPage>
    with SingleTickerProviderStateMixin {
  final link = CarLink.instance;
  final _boost = ValueNotifier<double>(1);

  /// True only while boost is actually running (drives the button animation).
  final _boostActive = ValueNotifier<bool>(false);

  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  bool _held = false;
  bool _boosting = false;
  bool _lockedOut = false;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
    if (!widget.skipped) link.addListener(_onLinkChanged);
  }

  @override
  void dispose() {
    link.removeListener(_onLinkChanged);
    _ticker.dispose();
    _boost.dispose();
    _boostActive.dispose();
    super.dispose();
  }

  void _setBoosting(bool on) {
    _boosting = on;
    _boostActive.value = on;
    link.setBoosting(on);
  }

  void _onTick(Duration elapsed) {
    final dt = (elapsed - _lastTick).inMicroseconds / 1e6;
    _lastTick = elapsed;

    var level = _boost.value;
    var boostingNow = _boosting;

    if (_boosting) {
      level -= dt / _boostDrainSeconds;
      if (level <= 0) {
        level = 0;
        boostingNow = false;
        _lockedOut = true;
      }
    } else if (level < 1) {
      level = math.min(1.0, level + dt / _boostFillSeconds);
    }

    if (level != _boost.value) _boost.value = level;
    if (boostingNow != _boosting) _setBoosting(boostingNow);
  }

  void _press() {
    _held = true;
    if (_lockedOut || _boost.value <= 0) return;
    _setBoosting(true);
  }

  void _release() {
    _held = false;
    _lockedOut = false;
    if (_boosting) _setBoosting(false);
  }

  void _onLinkChanged() {
    if (_leaving || link.isConnected) return;
    _leaving = true;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          backgroundColor: AppColors.navy,
          behavior: SnackBarBehavior.floating,
          content: Text(
            'CONNECTION LOST',
            style: GoogleFonts.fredoka(
              fontSize: 16,
              letterSpacing: 1.6,
              color: Colors.white,
            ),
          ),
        ),
      );
    // popUntil (not pop) so this still works if the settings page is open
    // on top of the play page when the connection drops.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _goBack() async {
    if (_leaving) return;
    _leaving = true;
    if (!widget.skipped) {
      link.sendDrive(0, 0);
      link.setBoosting(false);
      await link.disconnect();
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _goBack();
      },
      child: ScreenFrame(
        title: 'PLAY',
        pill: TopPill(
          label: 'BACK',
          icon: LucideShape.chevronLeft,
          iconSize: 38,
          iconLeft: 4,
          textLeft: 53,
          onTap: _goBack,
        ),
        trailing: const SettingsPill(),
        child: LayoutBuilder(
          builder: (context, c) {
            final s = DesignScale.of(context);
            final w = c.maxWidth;
            final h = c.maxHeight;
            return Stack(
              children: [
                ListenableBuilder(
                  listenable: AppSettings.instance,
                  builder: (context, _) {
                    // Never let the joystick grow taller than the play area.
                    final size = math.min(
                      210 * s * AppSettings.instance.joystickScale,
                      h - 8 * s,
                    );
                    return Positioned(
                      left: w * 0.198 - size / 2,
                      top: (h - size) / 2,
                      child: _Joystick(size: size, onChanged: link.sendDrive),
                    );
                  },
                ),
                Center(child: _Score(s: s)),
                Positioned(
                  left: w * 0.81 - 58.5 * s,
                  top: (h - 117 * s) / 2,
                  child: _BoostButton(
                    s: s,
                    level: _boost,
                    active: _boostActive,
                    onPress: _press,
                    onRelease: _release,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Score extends StatelessWidget {
  const _Score({required this.s});

  final double s;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$_redScore', style: AppText.score(s, AppColors.red)),
        SizedBox(width: 30 * s),
        Text('-', style: AppText.score(s, AppColors.light)),
        SizedBox(width: 30 * s),
        Text('$_blueScore', style: AppText.score(s, AppColors.blue)),
      ],
    );
  }
}

class _Joystick extends StatefulWidget {
  const _Joystick({required this.size, required this.onChanged});

  /// Diameter of the joystick base in logical pixels. The knob and the touch
  /// area scale with it.
  final double size;

  final void Function(double x, double y) onChanged;

  @override
  State<_Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<_Joystick> {
  Offset _knob = Offset.zero;
  int? _pointer;

  double get _base => widget.size;
  double get _knobSize => widget.size * 129 / 210;
  double get _maxTravel => (_base - _knobSize) / 2;

  void _update(Offset local) {
    var v = local - Offset(_base / 2, _base / 2);
    if (v.distance > _maxTravel) v = v / v.distance * _maxTravel;
    setState(() => _knob = v);
    widget.onChanged(v.dx / _maxTravel, -v.dy / _maxTravel);
  }

  void _release(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    setState(() => _knob = Offset.zero);
    widget.onChanged(0, 0);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (e) {
        if (_pointer != null) return;
        _pointer = e.pointer;
        _update(e.localPosition);
      },
      onPointerMove: (e) {
        if (e.pointer == _pointer) _update(e.localPosition);
      },
      onPointerUp: _release,
      onPointerCancel: _release,
      child: SizedBox(
        width: _base,
        height: _base,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.overlayOuter,
              ),
            ),
            Transform.translate(
              offset: _knob,
              child: Container(
                width: _knobSize,
                height: _knobSize,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.overlayInner,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BoostButton extends StatefulWidget {
  const _BoostButton({
    required this.s,
    required this.level,
    required this.active,
    required this.onPress,
    required this.onRelease,
  });

  final double s;
  final ValueListenable<double> level;

  /// True while the boost is really running.
  final ValueListenable<bool> active;

  final VoidCallback onPress;
  final VoidCallback onRelease;

  @override
  State<_BoostButton> createState() => _BoostButtonState();
}

class _BoostButtonState extends State<_BoostButton>
    with TickerProviderStateMixin {
  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 500,
    damping: 14,
  );

  int? _pointer;

  late final AnimationController _squish = AnimationController.unbounded(
    vsync: this,
  );

  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
  );

  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 550),
  );

  @override
  void initState() {
    super.initState();
    widget.active.addListener(_onActive);
  }

  @override
  void dispose() {
    widget.active.removeListener(_onActive);
    _squish.dispose();
    _glow.dispose();
    _pulse.dispose();
    _burst.dispose();
    super.dispose();
  }

  void _onActive() {
    if (widget.active.value) {
      HapticFeedback.lightImpact();
      _glow.forward();
      _burst.forward(from: 0);
      _pulse.repeat(reverse: true);
    } else {
      _glow.reverse().whenComplete(() {
        if (mounted && !widget.active.value) _pulse.stop();
      });
    }
  }

  void _down(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    _squish.animateTo(
      1,
      duration: const Duration(milliseconds: 90),
      curve: Curves.easeOut,
    );
    widget.onPress();
  }

  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    _squish.animateWith(
      SpringSimulation(_spring, _squish.value, 0, _squish.velocity),
    );
    widget.onRelease();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.s;
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: AnimatedBuilder(
        animation: _squish,
        builder: (context, child) =>
            Transform.scale(scale: 1 - 0.10 * _squish.value, child: child),
        child: CustomPaint(
          painter: _BoostRingPainter(
            level: widget.level,
            glow: _glow,
            pulse: _pulse,
            burst: _burst,
            s: s,
          ),
          child: SizedBox(
            width: 117 * s,
            height: 117 * s,
            child: Center(
              child: AnimatedBuilder(
                animation: Listenable.merge([_glow, _pulse]),
                builder: (context, _) {
                  final g = _glow.value;
                  final p = _pulse.value;
                  return Transform.scale(
                    scale: 1 + g * (0.10 + 0.08 * p),
                    child: LucideIcon(
                      LucideShape.zap,
                      size: 52 * s,
                      color: Color.lerp(AppColors.blue, Colors.white, g)!,
                      strokeWidth: 1.5 + 0.7 * g,
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BoostRingPainter extends CustomPainter {
  _BoostRingPainter({
    required this.level,
    required this.glow,
    required this.pulse,
    required this.burst,
    required this.s,
  }) : super(repaint: Listenable.merge([level, glow, pulse, burst]));

  final ValueListenable<double> level;
  final Animation<double> glow;
  final Animation<double> pulse;
  final Animation<double> burst;
  final double s;

  static Color _blue(double opacity) =>
      Color.fromRGBO(56, 182, 255, opacity.clamp(0.0, 1.0).toDouble());

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = 55 * s;
    final g = glow.value.clamp(0.0, 1.0).toDouble();
    final p = pulse.value;
    final b = burst.value;

    if (g > 0) {
      final glowRadius = radius * (1.45 + 0.12 * p);
      canvas.drawCircle(
        center,
        glowRadius,
        Paint()
          ..shader = RadialGradient(
            colors: [_blue(0.55 * g * (0.75 + 0.25 * p)), _blue(0)],
            stops: const [0.55, 1.0],
          ).createShader(Rect.fromCircle(center: center, radius: glowRadius)),
      );
    }

    final face = Color.lerp(
      AppColors.overlayOuter,
      const Color(0x6638B6FF),
      g,
    )!;
    canvas.drawCircle(center, radius, Paint()..color = face);

    if (b > 0 && b < 1) {
      final t = Curves.easeOut.transform(b);
      canvas.drawCircle(
        center,
        radius * (1.0 + 0.9 * t),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = (1 + 5 * (1 - t)) * s
          ..color = _blue(0.7 * (1 - t)),
      );
    }

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7 * s
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, ring..color = AppColors.blueTrack);

    final v = level.value.clamp(0.0, 1.0).toDouble();
    if (v > 0) {
      final arcRect = Rect.fromCircle(center: center, radius: radius);
      final sweep = 2 * math.pi * v;

      if (g > 0) {
        canvas.drawArc(
          arcRect,
          -math.pi / 2,
          sweep,
          false,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 11 * s
            ..strokeCap = StrokeCap.round
            ..color = _blue(0.8 * g)
            ..maskFilter = MaskFilter.blur(BlurStyle.normal, 7 * s),
        );
      }

      canvas.drawArc(
        arcRect,
        -math.pi / 2,
        sweep,
        false,
        ring..color = Color.lerp(AppColors.blue, Colors.white, 0.35 * g)!,
      );
    }
  }

  @override
  bool shouldRepaint(_BoostRingPainter old) =>
      old.s != s ||
      old.level != level ||
      old.glow != glow ||
      old.pulse != pulse ||
      old.burst != burst;
}
