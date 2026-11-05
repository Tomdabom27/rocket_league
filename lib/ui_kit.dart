import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const navy = Color(0xFF13182C);
  static const light = Color(0xFFEFEDF8);
  static const mint = Color(0xFFA3E4D7);
  static const red = Color(0xFFFF5757);
  static const blue = Color(0xFF38B6FF);

  static const overlayOuter = Color(0x40FFFFFF);
  static const overlayInner = Color(0x21FFFFFF);
  static const blueTrack = Color(0x4038B6FF);
}

class DesignScale extends InheritedWidget {
  const DesignScale({super.key, required this.s, required super.child});

  final double s;

  static double of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DesignScale>()!.s;

  @override
  bool updateShouldNotify(DesignScale oldWidget) => oldWidget.s != s;
}

class AppText {
  static TextStyle title(double s, {Color color = AppColors.navy}) =>
      GoogleFonts.fredoka(
        fontSize: 24 * s,
        fontWeight: FontWeight.w500,
        letterSpacing: 2.4 * s,
        color: color,
      );

  static TextStyle body(double s, {Color color = Colors.black}) =>
      GoogleFonts.fredoka(
        fontSize: 20 * s,
        fontWeight: FontWeight.w400,
        letterSpacing: 2 * s,
        color: color,
      );

  static TextStyle score(double s, Color color) => GoogleFonts.fredoka(
    fontSize: 96 * s,
    fontWeight: FontWeight.w500,
    color: color,
  );
}

class ScreenFrame extends StatelessWidget {
  const ScreenFrame({
    super.key,
    required this.title,
    required this.pill,
    this.trailing,
    required this.child,
  });

  final String title;

  final Widget pill;

  final Widget? trailing;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, c) {
            final s = math.min(c.maxWidth / 917, c.maxHeight / 451);
            return DesignScale(
              s: s,
              child: Padding(
                padding: EdgeInsets.fromLTRB(24 * s, 29 * s, 24 * s, 24 * s),
                child: Column(
                  children: [
                    SizedBox(
                      height: 43 * s,
                      child: Stack(
                        children: [
                          Align(alignment: Alignment.centerLeft, child: pill),
                          Center(child: Text(title, style: AppText.title(s))),
                          if (trailing != null)
                            Align(
                              alignment: Alignment.centerRight,
                              child: trailing,
                            ),
                        ],
                      ),
                    ),
                    SizedBox(height: 30 * s),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(36 * s),
                        child: ColoredBox(
                          color: AppColors.navy,
                          child: SizedBox.expand(child: child),
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
    );
  }
}

class TopPill extends StatelessWidget {
  const TopPill({
    super.key,
    required this.label,
    required this.icon,
    required this.iconSize,
    required this.iconLeft,
    required this.textLeft,
    required this.onTap,
    this.width = 174,
  });

  final String label;
  final LucideShape icon;
  final double iconSize;
  final double iconLeft;
  final double textLeft;
  final VoidCallback onTap;

  final double width;

  @override
  Widget build(BuildContext context) {
    final s = DesignScale.of(context);
    return Material(
      color: AppColors.light,
      borderRadius: BorderRadius.circular(13 * s),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: width * s,
          height: 43 * s,
          child: Stack(
            children: [
              Positioned(
                left: iconLeft * s,
                top: (43 - iconSize) / 2 * s,
                child: LucideIcon(
                  icon,
                  size: iconSize * s,
                  color: AppColors.navy,
                ),
              ),
              Positioned(
                left: textLeft * s,
                top: 0,
                bottom: 0,
                child: Center(child: Text(label, style: AppText.title(s))),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum LucideShape { skipForward, chevronLeft, zap, settings }

class LucideIcon extends StatelessWidget {
  const LucideIcon(
    this.shape, {
    super.key,
    required this.size,
    required this.color,
    this.strokeWidth = 2,
  });

  final LucideShape shape;
  final double size;
  final Color color;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) => CustomPaint(
    size: Size.square(size),
    painter: _LucidePainter(shape, color, strokeWidth),
  );
}

Path _gearPath() {
  const teeth = 8;
  const outer = 10.0;
  const inner = 7.6;
  const step = 2 * math.pi / teeth;

  final path = Path();
  var first = true;

  void point(double angle, double radius) {
    final o = Offset(
      12 + radius * math.cos(angle),
      12 + radius * math.sin(angle),
    );
    if (first) {
      path.moveTo(o.dx, o.dy);
      first = false;
    } else {
      path.lineTo(o.dx, o.dy);
    }
  }

  for (var i = 0; i < teeth; i++) {
    final c = i * step - math.pi / 2;
    point(c - step * 0.30, inner);
    point(c - step * 0.17, outer);
    point(c + step * 0.17, outer);
    point(c + step * 0.30, inner);
  }
  path.close();
  return path;
}

class _LucidePainter extends CustomPainter {
  _LucidePainter(this.shape, this.color, this.strokeWidth);

  final LucideShape shape;
  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 24);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    switch (shape) {
      case LucideShape.skipForward:
        canvas.drawPath(
          Path()
            ..moveTo(5, 4)
            ..lineTo(15, 12)
            ..lineTo(5, 20)
            ..close(),
          paint,
        );
        canvas.drawLine(const Offset(19, 5), const Offset(19, 19), paint);
      case LucideShape.chevronLeft:
        canvas.drawPath(
          Path()
            ..moveTo(15, 18)
            ..lineTo(9, 12)
            ..lineTo(15, 6),
          paint,
        );
      case LucideShape.zap:
        canvas.drawPath(
          Path()
            ..moveTo(13, 2)
            ..lineTo(3, 14)
            ..lineTo(12, 14)
            ..lineTo(11, 22)
            ..lineTo(21, 10)
            ..lineTo(12, 10)
            ..close(),
          paint,
        );
      case LucideShape.settings:
        canvas.drawPath(_gearPath(), paint);
        canvas.drawCircle(const Offset(12, 12), 3, paint);
    }
  }

  @override
  bool shouldRepaint(_LucidePainter old) =>
      old.shape != shape ||
      old.color != color ||
      old.strokeWidth != strokeWidth;
}
