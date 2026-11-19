import 'package:cupertino_ui/cupertino_ui.dart';

/// A compartment tray and cutlery resting on a folded gingham napkin.
class EmptyMealIllustration extends CustomPainter {
  const EmptyMealIllustration();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 208, size.height / 128);
    final brush = Paint()..isAntiAlias = true;
    void rounded(Rect rect, double radius, Color color) {
      brush
        ..shader = null
        ..color = color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        brush,
      );
    }

    void shaded(Rect rect, double radius, List<Color> colors) {
      brush
        ..color = const Color(0xffffffff)
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ).createShader(rect);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(radius)),
        brush,
      );
      brush.shader = null;
    }

    canvas.drawOval(
      const Rect.fromLTWH(17, 92, 177, 19),
      Paint()
        ..color = const Color(0x293b375e)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );

    canvas.save();
    canvas.translate(116, 71);
    canvas.rotate(.19);
    const cloth = Rect.fromLTWH(-53, -36, 106, 73);
    final hem = RRect.fromRectAndRadius(cloth, const Radius.circular(5));
    canvas.clipRRect(hem);
    canvas.drawColor(const Color(0xffd8ebe9), BlendMode.srcOver);
    for (double x = -49; x < 54; x += 13) {
      canvas.drawRect(
        Rect.fromLTWH(x, -36, 4, 73),
        Paint()..color = const Color(0x447bbeb8),
      );
    }
    for (double y = -32; y < 38; y += 13) {
      canvas.drawRect(
        Rect.fromLTWH(-53, y, 106, 4),
        Paint()..color = const Color(0x447bbeb8),
      );
    }
    canvas.restore();

    canvas.save();
    canvas.translate(87, 61);
    canvas.rotate(-.13);
    canvas.skew(-.14, 0);
    const tray = Rect.fromLTWH(-64, -39, 128, 78);
    rounded(tray.shift(const Offset(0, 5)), 15, const Color(0xff989eb9));
    shaded(tray, 15, const [Color(0xfffcfdff), Color(0xffc8cee3)]);
    void compartment(Rect rect, double radius) {
      rounded(
        rect.shift(const Offset(0, 1.5)),
        radius,
        const Color(0xfff6f8ff),
      );
      shaded(rect, radius, const [
        Color(0xff9ca6c3),
        Color(0xffc9d1e5),
        Color(0xffe0e5ef),
      ]);
    }

    for (var i = 0; i < 3; i++) {
      compartment(Rect.fromLTWH(-56.0 + i * 38, -31, 34, 22), 7);
    }
    compartment(const Rect.fromLTWH(-56, -4, 61, 35), 10);
    compartment(const Rect.fromLTWH(10, -4, 46, 35), 10);
    canvas.restore();

    canvas.save();
    canvas.translate(166, 63);
    canvas.rotate(.22);
    shaded(const Rect.fromLTWH(-2, -12, 4.5, 44), 2, const [
      Color(0xfff9faff),
      Color(0xff8692ac),
    ]);
    const bowl = Rect.fromLTWH(-7, -29, 15, 21);
    brush.shader = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xff8b98b2), Color(0xfff0f3fb), Color(0xffa7b1c6)],
    ).createShader(bowl);
    canvas.drawOval(bowl, brush);
    for (final x in [12.0, 18.0]) {
      shaded(Rect.fromLTWH(x, -29, 3, 61), 1.5, const [
        Color(0xffeec78c),
        Color(0xffbc8857),
      ]);
    }
    canvas.restore();
    canvas.restore();
  }

  @override
  bool shouldRepaint(EmptyMealIllustration oldDelegate) => false;
}
