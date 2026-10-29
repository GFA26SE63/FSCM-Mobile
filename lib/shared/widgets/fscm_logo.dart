import 'package:flutter/material.dart';

/// 3D isometric box icon matching the SVG in `FSCM_Prototype_Prod_v1.1.html`:
/// `<path d="M3 8l9-5 9 5v8l-9 5-9-5z"/><path d="M3 8l9 5 9-5"/><path d="M12 13v8"/>`
class FscmCubePainter extends CustomPainter {
  const FscmCubePainter({
    this.color = Colors.white,
    this.strokeWidth = 1.8,
  });

  final Color color;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    double sx(double x) => x * size.width / 24.0;
    double sy(double y) => y * size.height / 24.0;

    final outer = Path()
      ..moveTo(sx(3), sy(8))
      ..lineTo(sx(12), sy(3))
      ..lineTo(sx(21), sy(8))
      ..lineTo(sx(21), sy(16))
      ..lineTo(sx(12), sy(21))
      ..lineTo(sx(3), sy(16))
      ..close();

    final innerTop = Path()
      ..moveTo(sx(3), sy(8))
      ..lineTo(sx(12), sy(13))
      ..lineTo(sx(21), sy(8));

    final innerVert = Path()
      ..moveTo(sx(12), sy(13))
      ..lineTo(sx(12), sy(21));

    canvas.drawPath(outer, paint);
    canvas.drawPath(innerTop, paint);
    canvas.drawPath(innerVert, paint);
  }

  @override
  bool shouldRepaint(covariant FscmCubePainter oldDelegate) =>
      color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth;
}

/// Official brand logo icon container of FSCM.
class FscmLogo extends StatelessWidget {
  const FscmLogo({
    super.key,
    this.size = 56,
    this.iconSize = 30,
    this.backgroundColor = const Color(0xFF14655B),
    this.iconColor = Colors.white,
    this.borderRadius = 16,
    this.strokeWidth = 1.8,
  });

  final double size;
  final double iconSize;
  final Color backgroundColor;
  final Color iconColor;
  final double borderRadius;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: CustomPaint(
          size: Size(iconSize, iconSize),
          painter: FscmCubePainter(
            color: iconColor,
            strokeWidth: strokeWidth,
          ),
        ),
      ),
    );
  }
}

