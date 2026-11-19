import 'dart:math' as math;

import 'package:cupertino_ui/cupertino_ui.dart';

/// A miniature weekly planner, drawn locally so the welcome screen opens offline.
class PlannerIllustration extends CustomPainter {
  const PlannerIllustration();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 180, size.height / 100);
    final brush = Paint()..isAntiAlias = true;
    void tile(Rect rect, double radius, int color) {
      brush.color = Color(color);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        brush,
      );
    }

    canvas.save();
    canvas.translate(88, 50);
    canvas.rotate(-math.pi / 19);
    tile(const Rect.fromLTWH(-53, -33, 106, 73), 10, 0xffc7c5f2);
    tile(const Rect.fromLTWH(-54, -39, 108, 73), 10, 0xfffdfcff);
    tile(const Rect.fromLTWH(-54, -39, 108, 17), 8, 0xff776fd6);
    for (var i = 0; i < 3; i++) {
      tile(Rect.fromLTWH(-33 + i * 32, -44, 5, 13), 2.5, 0xff494574);
    }
    const inks = [0xffdddafa, 0xffbde4df, 0xffffdfa2, 0xffe9e9f4];
    for (var y = 0; y < 3; y++) {
      for (var x = 0; x < 5; x++) {
        tile(
          Rect.fromLTWH(-44 + x * 18, -15 + y * 14, 15, 10),
          3,
          inks[(x + y * 2) % 4],
        );
      }
    }
    canvas.restore();
    canvas.save();
    canvas.translate(140, 68);
    canvas.rotate(.53);
    tile(const Rect.fromLTWH(-4, -29, 8, 47), 3, 0xffedac54);
    tile(const Rect.fromLTWH(-4, -29, 8, 7), 3, 0xffee937f);
    brush.color = const Color(0xff775a4a);
    canvas.drawPath(
      Path()
        ..moveTo(-4, 17)
        ..lineTo(4, 17)
        ..lineTo(0, 26)
        ..close(),
      brush,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(PlannerIllustration oldDelegate) => false;
}
