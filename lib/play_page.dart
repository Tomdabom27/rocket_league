import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:google_fonts/google_fonts.dart';

import 'car_link.dart';
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
    super.dispose();
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
    if (boostingNow != _boosting) {
      _boosting = boostingNow;
      link.setBoosting(_boosting);
    }
  }

  void _press() {
    _held = true;
    if (_lockedOut || _boost.value <= 0) return;
    _boosting = true;
    link.setBoosting(true);
  }

  void _release() {
    _held = false;
    _lockedOut = false;
    if (_boosting) {
      _boosting = false;
      link.setBoosting(false);
    }
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
    Navigator.of(context).pop();
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
        child: LayoutBuilder(
          builder: (context, c) {
            final s = DesignScale.of(context);
            final w = c.maxWidth;
            final h = c.maxHeight;
            return Stack(
              children: [
                Positioned(
                  left: w * 0.198 - 105 * s,
                  top: (h - 210 * s) / 2,
                  child: _Joystick(s: s, onChanged: link.sendDrive),
                ),
                Center(child: _Score(s: s)),
                Positioned(
                  left: w * 0.81 - 58.5 * s,
                  top: (h - 117 * s) / 2,
                  child: _BoostButton(
                    s: s,
                    level: _boost,
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
  const _Joystick({required this.s, required this.onChanged});

  final double s;

  final void Function(double x, double y) onChanged;

  @override
  State<_Joystick> createState() => _JoystickState();
}

class _JoystickState extends State<_Joystick> {
  Offset _knob = Offset.zero;
  int? _pointer;

  double get _base => 210 * widget.s;
  double get _knobSize => 129 * widget.s;
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
    required this.onPress,
    required this.onRelease,
  });

  final double s;
  final ValueListenable<double> level;
  final VoidCallback onPress;
  final VoidCallback onRelease;

  @override
  State<_BoostButton> createState() => _BoostButtonState();
}

class _BoostButtonState extends State<_BoostButton> {
  int? _pointer;

  void _down(PointerDownEvent e) {
    if (_pointer != null) return;
    _pointer = e.pointer;
    widget.onPress();
  }

  void _up(PointerEvent e) {
    if (e.pointer != _pointer) return;
    _pointer = null;
    widget.onRelease();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: _down,
      onPointerUp: _up,
      onPointerCancel: _up,
      child: CustomPaint(
        painter: _BoostRingPainter(widget.level, widget.s),
        child: SizedBox(
          width: 117 * widget.s,
          height: 117 * widget.s,
          child: Center(
            child: LucideIcon(
              LucideShape.zap,
              size: 52 * widget.s,
              color: AppColors.blue,
              strokeWidth: 1.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _BoostRingPainter extends CustomPainter {
  _BoostRingPainter(this.level, this.s) : super(repaint: level);

  final ValueListenable<double> level;
  final double s;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = 55 * s;

    canvas.drawCircle(center, radius, Paint()..color = AppColors.overlayOuter);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7 * s
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, ring..color = AppColors.blueTrack);

    final v = level.value.clamp(0.0, 1.0);
    if (v > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        2 * math.pi * v,
        false,
        ring..color = AppColors.blue,
      );
    }
  }

  @override
  bool shouldRepaint(_BoostRingPainter old) => old.s != s || old.level != level;
}
