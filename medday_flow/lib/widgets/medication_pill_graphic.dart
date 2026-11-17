import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Supported physical shapes of medications.
enum MedicationShape {
  capsule,
  round,
  oval,
  oblong,
  liquid,
  drops,
  inhaler,
  injection,
  patch,
  topical;

  String get displayName {
    switch (this) {
      case MedicationShape.capsule:
        return 'Capsule';
      case MedicationShape.round:
        return 'Round Tablet';
      case MedicationShape.oval:
        return 'Oval Tablet';
      case MedicationShape.oblong:
        return 'Caplet';
      case MedicationShape.liquid:
        return 'Liquid Syrup';
      case MedicationShape.drops:
        return 'Dropper Drops';
      case MedicationShape.inhaler:
        return 'Inhaler';
      case MedicationShape.injection:
        return 'Injection / Pen';
      case MedicationShape.patch:
        return 'Skin Patch';
      case MedicationShape.topical:
        return 'Topical Cream';
    }
  }

  static MedicationShape fromString(String? val) {
    if (val == null) return MedicationShape.capsule;
    return MedicationShape.values.firstWhere(
      (e) => e.name.toLowerCase() == val.toLowerCase(),
      orElse: () => MedicationShape.capsule,
    );
  }
}

/// Advanced visual component that renders realistic pharmaceutical pill
/// shapes, colors, specular highlights, and score-lines.
class MedicationPillGraphic extends StatelessWidget {
  final MedicationShape shape;
  final Color primaryColor;
  final Color? secondaryColor;
  final double size;
  final String? fallbackIcon;
  final bool showShadow;

  const MedicationPillGraphic({
    super.key,
    required this.shape,
    required this.primaryColor,
    this.secondaryColor,
    this.size = 44,
    this.fallbackIcon,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _PillPainter(
          shape: shape,
          primaryColor: primaryColor,
          secondaryColor: secondaryColor,
          showShadow: showShadow,
        ),
      ),
    );
  }
}

class _PillPainter extends CustomPainter {
  final MedicationShape shape;
  final Color primaryColor;
  final Color? secondaryColor;
  final bool showShadow;

  _PillPainter({
    required this.shape,
    required this.primaryColor,
    this.secondaryColor,
    required this.showShadow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    final secondColor = secondaryColor ?? primaryColor;

    if (showShadow) {
      final shadowPaint = Paint()
        ..color = primaryColor.withValues(alpha: 0.25)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.12);
      canvas.drawCircle(center.translate(0, h * 0.08), w * 0.38, shadowPaint);
    }

    switch (shape) {
      case MedicationShape.round:
        _drawRoundTablet(canvas, center, w * 0.42);
        break;
      case MedicationShape.capsule:
        _drawCapsule(canvas, center, w * 0.85, h * 0.44, secondColor);
        break;
      case MedicationShape.oval:
        _drawOvalTablet(canvas, center, w * 0.85, h * 0.52);
        break;
      case MedicationShape.oblong:
        _drawOblongCaplet(canvas, center, w * 0.88, h * 0.44);
        break;
      case MedicationShape.liquid:
        _drawLiquidBottle(canvas, center, w, h, secondColor);
        break;
      case MedicationShape.drops:
        _drawDropper(canvas, center, w, h);
        break;
      case MedicationShape.inhaler:
        _drawInhaler(canvas, center, w, h);
        break;
      case MedicationShape.injection:
        _drawSyringe(canvas, center, w, h);
        break;
      case MedicationShape.patch:
        _drawPatch(canvas, center, w * 0.72);
        break;
      case MedicationShape.topical:
        _drawTopicalTube(canvas, center, w, h);
        break;
    }
  }

  void _drawRoundTablet(Canvas canvas, Offset center, double radius) {
    // 3D shaded base
    final gradient = RadialGradient(
      center: const Alignment(-0.35, -0.35),
      radius: 0.9,
      colors: [
        _lighten(primaryColor, 0.35),
        primaryColor,
        _darken(primaryColor, 0.25),
      ],
      stops: const [0.0, 0.65, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, paint);

    // Rim ring
    final rimPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.08;
    canvas.drawCircle(center, radius * 0.92, rimPaint);

    // Center score line
    final scorePaint = Paint()
      ..color = _darken(primaryColor, 0.35).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.09
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center.translate(0, -radius * 0.65),
      center.translate(0, radius * 0.65),
      scorePaint,
    );

    // Specular shine
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.4)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, radius * 0.15);
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-radius * 0.3, -radius * 0.35),
        width: radius * 0.5,
        height: radius * 0.25,
      ),
      shinePaint,
    );
  }

  void _drawCapsule(
    Canvas canvas,
    Offset center,
    double width,
    double height,
    Color secondary,
  ) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 5.5); // Elegant 30° tilt

    final rect = Rect.fromCenter(center: Offset.zero, width: width, height: height);
    final rradius = Radius.circular(height / 2);
    final rrect = RRect.fromRectAndRadius(rect, rradius);

    // Clip to capsule outline
    canvas.save();
    canvas.clipRRect(rrect);

    // Left half (Primary)
    final leftRect = Rect.fromLTRB(rect.left, rect.top, 0, rect.bottom);
    final leftGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _lighten(primaryColor, 0.3),
        primaryColor,
        _darken(primaryColor, 0.25),
      ],
    );
    canvas.drawRect(leftRect, Paint()..shader = leftGradient.createShader(leftRect));

    // Right half (Secondary)
    final rightRect = Rect.fromLTRB(0, rect.top, rect.right, rect.bottom);
    final rightGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _lighten(secondary, 0.3),
        secondary,
        _darken(secondary, 0.25),
      ],
    );
    canvas.drawRect(rightRect, Paint()..shader = rightGradient.createShader(rightRect));

    // Center seam band
    final seamPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..strokeWidth = height * 0.06;
    canvas.drawLine(Offset(0, rect.top), Offset(0, rect.bottom), seamPaint);

    // Gelatin cylindrical top shine
    final shineRect = Rect.fromCenter(
      center: Offset(0, -height * 0.22),
      width: width * 0.72,
      height: height * 0.22,
    );
    final shinePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, height * 0.08);
    canvas.drawRRect(RRect.fromRectAndRadius(shineRect, Radius.circular(height * 0.1)), shinePaint);

    canvas.restore(); // restore clip

    // Border
    final borderPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(rrect, borderPaint);

    canvas.restore(); // restore rotation & translation
  }

  void _drawOvalTablet(Canvas canvas, Offset center, double width, double height) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 6);

    final rect = Rect.fromCenter(center: Offset.zero, width: width, height: height);
    final gradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      radius: 0.85,
      colors: [
        _lighten(primaryColor, 0.35),
        primaryColor,
        _darken(primaryColor, 0.25),
      ],
    );

    canvas.drawOval(rect, Paint()..shader = gradient.createShader(rect));

    // Bevel stroke
    final rimPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = height * 0.08;
    final innerRect = Rect.fromCenter(
      center: Offset.zero,
      width: width * 0.88,
      height: height * 0.85,
    );
    canvas.drawOval(innerRect, rimPaint);

    // Score line
    final scorePaint = Paint()
      ..color = _darken(primaryColor, 0.35).withValues(alpha: 0.5)
      ..strokeWidth = height * 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, -height * 0.4), Offset(0, height * 0.4), scorePaint);

    canvas.restore();
  }

  void _drawOblongCaplet(Canvas canvas, Offset center, double width, double height) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 6);

    final rect = Rect.fromCenter(center: Offset.zero, width: width, height: height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(height * 0.42));

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _lighten(primaryColor, 0.3),
        primaryColor,
        _darken(primaryColor, 0.25),
      ],
    );
    canvas.drawRRect(rrect, Paint()..shader = gradient.createShader(rect));

    // Score line
    final scorePaint = Paint()
      ..color = _darken(primaryColor, 0.35).withValues(alpha: 0.55)
      ..strokeWidth = height * 0.08
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(0, -height * 0.4), Offset(0, height * 0.4), scorePaint);

    // Top highlight
    final shineRect = Rect.fromCenter(
      center: Offset(0, -height * 0.22),
      width: width * 0.75,
      height: height * 0.2,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(shineRect, Radius.circular(height * 0.1)),
      Paint()..color = Colors.white.withValues(alpha: 0.4),
    );

    canvas.restore();
  }

  void _drawLiquidBottle(Canvas canvas, Offset center, double w, double h, Color capColor) {
    final bodyRect = Rect.fromCenter(
      center: center.translate(0, h * 0.08),
      width: w * 0.58,
      height: h * 0.65,
    );
    final bodyRRect = RRect.fromRectAndRadius(bodyRect, Radius.circular(w * 0.12));

    // Liquid fill
    final liquidGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        _lighten(primaryColor, 0.25),
        primaryColor,
        _darken(primaryColor, 0.3),
      ],
    );
    canvas.drawRRect(bodyRRect, Paint()..shader = liquidGradient.createShader(bodyRect));

    // White label on bottle
    final labelRect = Rect.fromCenter(
      center: center.translate(0, h * 0.08),
      width: w * 0.44,
      height: h * 0.3,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(labelRect, Radius.circular(w * 0.04)),
      Paint()..color = Colors.white.withValues(alpha: 0.85),
    );

    // Small cross on label
    final crossPaint = Paint()
      ..color = primaryColor
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center.translate(-w * 0.08, h * 0.08),
      center.translate(w * 0.08, h * 0.08),
      crossPaint,
    );
    canvas.drawLine(
      center.translate(0, h * 0.08 - w * 0.08),
      center.translate(0, h * 0.08 + w * 0.08),
      crossPaint,
    );

    // Cap
    final capRect = Rect.fromCenter(
      center: center.translate(0, -h * 0.32),
      width: w * 0.32,
      height: h * 0.16,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, Radius.circular(w * 0.05)),
      Paint()..color = _darken(capColor, 0.1),
    );
  }

  void _drawDropper(Canvas canvas, Offset center, double w, double h) {
    // Dropper tube
    final tubeRect = Rect.fromCenter(
      center: center.translate(0, -h * 0.05),
      width: w * 0.22,
      height: h * 0.55,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tubeRect, Radius.circular(w * 0.08)),
      Paint()..color = _lighten(primaryColor, 0.15),
    );

    // Rubber bulb
    final bulbRect = Rect.fromCenter(
      center: center.translate(0, -h * 0.35),
      width: w * 0.38,
      height: h * 0.25,
    );
    canvas.drawOval(bulbRect, Paint()..color = _darken(primaryColor, 0.3));

    // Falling droplet
    final dropPath = Path();
    final dropCenter = center.translate(0, h * 0.32);
    final dropRadius = w * 0.12;
    dropPath.moveTo(dropCenter.dx, dropCenter.dy - dropRadius * 1.5);
    dropPath.quadraticBezierTo(
      dropCenter.dx + dropRadius,
      dropCenter.dy,
      dropCenter.dx + dropRadius,
      dropCenter.dy + dropRadius * 0.5,
    );
    dropPath.arcToPoint(
      Offset(dropCenter.dx - dropRadius, dropCenter.dy + dropRadius * 0.5),
      radius: Radius.circular(dropRadius),
      clockwise: true,
    );
    dropPath.quadraticBezierTo(
      dropCenter.dx - dropRadius,
      dropCenter.dy,
      dropCenter.dx,
      dropCenter.dy - dropRadius * 1.5,
    );
    canvas.drawPath(dropPath, Paint()..color = primaryColor);
  }

  void _drawInhaler(Canvas canvas, Offset center, double w, double h) {
    final bodyPath = Path();
    final startX = center.dx - w * 0.15;
    final startY = center.dy - h * 0.38;

    bodyPath.moveTo(startX, startY);
    bodyPath.lineTo(startX + w * 0.3, startY);
    bodyPath.lineTo(startX + w * 0.3, center.dy + h * 0.15);
    bodyPath.lineTo(center.dx + w * 0.35, center.dy + h * 0.15);
    bodyPath.lineTo(center.dx + w * 0.35, center.dy + h * 0.35);
    bodyPath.lineTo(startX, center.dy + h * 0.35);
    bodyPath.close();

    final gradient = LinearGradient(
      colors: [primaryColor, _darken(primaryColor, 0.25)],
    );
    canvas.drawPath(bodyPath, Paint()..shader = gradient.createShader(Rect.fromLTWH(0, 0, w, h)));

    // Canister top
    final canRect = Rect.fromCenter(
      center: Offset(center.dx, startY - h * 0.05),
      width: w * 0.24,
      height: h * 0.15,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(canRect, Radius.circular(w * 0.04)),
      Paint()..color = Colors.grey.shade400,
    );
  }

  void _drawSyringe(Canvas canvas, Offset center, double w, double h) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 4);

    // Barrel
    final barrelRect = Rect.fromCenter(center: Offset.zero, width: w * 0.24, height: h * 0.65);
    canvas.drawRRect(
      RRect.fromRectAndRadius(barrelRect, Radius.circular(w * 0.04)),
      Paint()..color = Colors.grey.shade200,
    );

    // Liquid inside barrel
    final liquidRect = Rect.fromCenter(
      center: Offset(0, h * 0.08),
      width: w * 0.2,
      height: h * 0.4,
    );
    canvas.drawRect(liquidRect, Paint()..color = primaryColor);

    // Needle
    final needlePaint = Paint()
      ..color = Colors.grey.shade600
      ..strokeWidth = w * 0.035;
    canvas.drawLine(Offset(0, -h * 0.32), Offset(0, -h * 0.48), needlePaint);

    // Plunger
    canvas.drawLine(Offset(0, h * 0.32), Offset(0, h * 0.46), needlePaint);
    canvas.drawLine(Offset(-w * 0.12, h * 0.46), Offset(w * 0.12, h * 0.46), needlePaint);

    canvas.restore();
  }

  void _drawPatch(Canvas canvas, Offset center, double side) {
    final patchRect = Rect.fromCenter(center: center, width: side, height: side);
    final rrect = RRect.fromRectAndRadius(patchRect, Radius.circular(side * 0.18));

    // Outer adhesive
    canvas.drawRRect(rrect, Paint()..color = primaryColor.withValues(alpha: 0.35));

    // Inner reservoir
    final innerRect = Rect.fromCenter(center: center, width: side * 0.65, height: side * 0.65);
    canvas.drawRRect(
      RRect.fromRectAndRadius(innerRect, Radius.circular(side * 0.12)),
      Paint()..color = primaryColor,
    );

    // Grid dots on patch
    final dotPaint = Paint()..color = Colors.white.withValues(alpha: 0.6);
    for (int i = -1; i <= 1; i++) {
      for (int j = -1; j <= 1; j++) {
        canvas.drawCircle(center.translate(i * side * 0.18, j * side * 0.18), side * 0.035, dotPaint);
      }
    }
  }

  void _drawTopicalTube(Canvas canvas, Offset center, double w, double h) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-math.pi / 4);

    final tubePath = Path();
    tubePath.moveTo(-w * 0.25, h * 0.3);
    tubePath.lineTo(w * 0.25, h * 0.3);
    tubePath.lineTo(w * 0.15, -h * 0.2);
    tubePath.lineTo(-w * 0.15, -h * 0.2);
    tubePath.close();

    final gradient = LinearGradient(
      colors: [primaryColor, _lighten(primaryColor, 0.25), _darken(primaryColor, 0.2)],
    );
    canvas.drawPath(tubePath, Paint()..shader = gradient.createShader(Rect.fromLTWH(-w / 2, -h / 2, w, h)));

    // Cap
    final capRect = Rect.fromCenter(center: Offset(0, -h * 0.28), width: w * 0.16, height: h * 0.14);
    canvas.drawRRect(
      RRect.fromRectAndRadius(capRect, Radius.circular(w * 0.03)),
      Paint()..color = Colors.grey.shade800,
    );

    canvas.restore();
  }

  Color _lighten(Color color, [double amount = .1]) {
    final hsl = HSLColor.fromColor(color);
    final hslLight = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return hslLight.toColor();
  }

  Color _darken(Color color, [double amount = .1]) {
    final hsl = HSLColor.fromColor(color);
    final hslDark = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return hslDark.toColor();
  }

  @override
  bool shouldRepaint(covariant _PillPainter oldDelegate) {
    return oldDelegate.shape != shape ||
        oldDelegate.primaryColor != primaryColor ||
        oldDelegate.secondaryColor != secondaryColor ||
        oldDelegate.showShadow != showShadow;
  }
}
