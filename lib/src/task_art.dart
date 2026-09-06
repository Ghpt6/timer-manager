import 'package:flutter/material.dart';

import 'timer_models.dart';

Color taskTint(TaskIcon kind) => switch (kind) {
  TaskIcon.kettle => const Color(0xFFFAEBDD),
  TaskIcon.egg => const Color(0xFFF8F0D6),
  TaskIcon.noodles => const Color(0xFFF2E5DC),
  TaskIcon.tea => const Color(0xFFE8EEDC),
  TaskIcon.rice => const Color(0xFFE6EDE9),
  TaskIcon.soup => const Color(0xFFF3E2D9),
  TaskIcon.timer => const Color(0xFFFAEBDD),
  TaskIcon.fitness => const Color(0xFFE6EDE9),
  TaskIcon.running => const Color(0xFFE8EEDC),
  TaskIcon.work => const Color(0xFFE3EAF4),
  TaskIcon.study => const Color(0xFFF8F0D6),
  TaskIcon.meditation => const Color(0xFFEEE5F2),
};

IconData? _symbolFor(TaskIcon kind) => switch (kind) {
  TaskIcon.timer => Icons.timer_outlined,
  TaskIcon.fitness => Icons.fitness_center_rounded,
  TaskIcon.running => Icons.directions_run_rounded,
  TaskIcon.work => Icons.work_outline_rounded,
  TaskIcon.study => Icons.menu_book_rounded,
  TaskIcon.meditation => Icons.self_improvement_rounded,
  _ => null,
};

/// Small vector illustrations stay crisp without network or asset downloads.
class TaskArt extends StatelessWidget {
  const TaskArt({super.key, required this.kind, this.size = 70});
  final TaskIcon kind;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: switch (_symbolFor(kind)) {
      final symbol? => Icon(
        symbol,
        size: size * .62,
        color: const Color(0xFF596858),
      ),
      null => CustomPaint(painter: _FoodPainter(kind)),
    },
  );
}

class _FoodPainter extends CustomPainter {
  _FoodPainter(this.kind);
  final TaskIcon kind;
  static const ink = Color(0xFF596858);
  static const orange = Color(0xFFE99A60);
  static const ivory = Color(0xFFFFFCF0);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    final outline = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    void shape(Path path, Color color) {
      canvas.drawPath(path, Paint()..color = color);
      canvas.drawPath(path, outline);
    }

    void line(double x1, double y1, double x2, double y2) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), outline);
    void oval(Rect rect, Color color) {
      canvas.drawOval(rect, Paint()..color = color);
      canvas.drawOval(rect, outline);
    }

    void steam(double x, double y) {
      canvas.drawPath(
        Path()
          ..moveTo(x, y)
          ..cubicTo(x - 7, y - 6, x + 7, y - 10, x, y - 17),
        Paint()
          ..color = ink.withValues(alpha: .45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round,
      );
    }

    canvas.drawOval(
      const Rect.fromLTWH(19, 81, 65, 7),
      Paint()..color = ink.withValues(alpha: .08),
    );
    switch (kind) {
      case TaskIcon.timer:
      case TaskIcon.fitness:
      case TaskIcon.running:
      case TaskIcon.work:
      case TaskIcon.study:
      case TaskIcon.meditation:
        return;
      case TaskIcon.kettle:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            const Rect.fromLTWH(62, 31, 25, 36),
            const Radius.circular(12),
          ),
          outline..strokeWidth = 6,
        );
        outline.strokeWidth = 2.6;
        shape(
          Path()
            ..moveTo(31, 45)
            ..lineTo(12, 34)
            ..lineTo(19, 60)
            ..lineTo(33, 66)
            ..close(),
          orange,
        );
        shape(
          Path()
            ..moveTo(37, 31)
            ..lineTo(62, 31)
            ..quadraticBezierTo(77, 51, 77, 72)
            ..quadraticBezierTo(76, 81, 66, 81)
            ..lineTo(32, 81)
            ..quadraticBezierTo(23, 80, 25, 69)
            ..quadraticBezierTo(27, 46, 37, 31)
            ..close(),
          ivory,
        );
        shape(
          Path()
            ..moveTo(34, 38)
            ..lineTo(68, 38)
            ..lineTo(64, 29)
            ..lineTo(39, 29)
            ..close(),
          orange,
        );
        line(47, 24, 55, 24);
        line(51, 24, 51, 28);
        line(57, 49, 61, 63);
        steam(26, 28);
      case TaskIcon.egg:
        canvas.save();
        canvas.translate(47, 51);
        canvas.rotate(-.3);
        shape(
          Path()
            ..moveTo(0, -32)
            ..cubicTo(22, -31, 31, 11, 20, 25)
            ..cubicTo(9, 40, -19, 34, -22, 18)
            ..cubicTo(-27, -1, -17, -30, 0, -32)
            ..close(),
          ivory,
        );
        canvas.restore();
        oval(const Rect.fromLTWH(45, 47, 36, 37), ivory);
        canvas.drawOval(
          const Rect.fromLTWH(53, 55, 20, 21),
          Paint()..color = const Color(0xFFF2B849),
        );
        line(24, 28, 27, 24);
      case TaskIcon.noodles:
        line(54, 34, 86, 15);
        line(58, 40, 91, 23);
        for (var i = 0; i < 4; i++) {
          canvas.drawPath(
            Path()
              ..moveTo(32 + i * 8, 49)
              ..cubicTo(25 + i * 8, 34, 43 + i * 8, 32, 38 + i * 8, 46),
            outline
              ..color = orange
              ..strokeWidth = 3,
          );
        }
        outline
          ..color = ink
          ..strokeWidth = 2.6;
        shape(
          Path()
            ..moveTo(16, 47)
            ..lineTo(84, 47)
            ..quadraticBezierTo(80, 78, 50, 80)
            ..quadraticBezierTo(22, 79, 16, 47)
            ..close(),
          ivory,
        );
        line(39, 83, 62, 83);
        canvas.drawPath(
          Path()
            ..moveTo(27, 58)
            ..quadraticBezierTo(49, 71, 73, 58),
          outline..color = orange,
        );
        steam(27, 31);
      case TaskIcon.tea:
        oval(const Rect.fromLTWH(19, 76, 64, 9), const Color(0xFFD4DFBD));
        oval(const Rect.fromLTWH(64, 40, 22, 24), ivory);
        shape(
          Path()
            ..moveTo(23, 38)
            ..lineTo(71, 38)
            ..lineTo(68, 67)
            ..quadraticBezierTo(46, 88, 26, 67)
            ..close(),
          ivory,
        );
        oval(const Rect.fromLTWH(23, 32, 48, 13), const Color(0xFFAABB84));
        line(56, 43, 58, 60);
        shape(
          Path()
            ..moveTo(54, 58)
            ..lineTo(63, 58)
            ..lineTo(66, 71)
            ..lineTo(54, 72)
            ..close(),
          const Color(0xFFD4DFBD),
        );
        steam(37, 24);
        steam(54, 25);
      case TaskIcon.rice:
        shape(
          Path()
            ..moveTo(21, 49)
            ..quadraticBezierTo(16, 35, 29, 32)
            ..quadraticBezierTo(31, 18, 44, 25)
            ..quadraticBezierTo(54, 16, 63, 28)
            ..quadraticBezierTo(78, 24, 79, 47)
            ..close(),
          ivory,
        );
        shape(
          Path()
            ..moveTo(16, 47)
            ..lineTo(85, 47)
            ..quadraticBezierTo(76, 77, 51, 80)
            ..quadraticBezierTo(25, 76, 16, 47)
            ..close(),
          const Color(0xFFAFC4B5),
        );
        line(40, 83, 61, 83);
        line(36, 34, 39, 37);
        line(53, 31, 56, 34);
        line(62, 38, 65, 41);
        line(44, 42, 48, 41);
      case TaskIcon.soup:
        shape(
          Path()
            ..moveTo(13, 46)
            ..lineTo(25, 46)
            ..lineTo(25, 57)
            ..lineTo(14, 54)
            ..close(),
          ink,
        );
        shape(
          Path()
            ..moveTo(75, 46)
            ..lineTo(88, 46)
            ..lineTo(87, 54)
            ..lineTo(75, 57)
            ..close(),
          ink,
        );
        shape(
          Path()
            ..moveTo(23, 42)
            ..lineTo(78, 42)
            ..lineTo(76, 70)
            ..quadraticBezierTo(76, 81, 65, 81)
            ..lineTo(35, 81)
            ..quadraticBezierTo(24, 80, 24, 69)
            ..close(),
          orange,
        );
        shape(
          Path()
            ..moveTo(19, 42)
            ..quadraticBezierTo(50, 16, 82, 42)
            ..close(),
          ivory,
        );
        line(45, 25, 55, 25);
        line(50, 25, 50, 30);
        canvas.drawPath(
          Path()
            ..moveTo(34, 52)
            ..lineTo(35, 67),
          outline
            ..color = ivory
            ..strokeWidth = 3,
        );
        steam(35, 22);
        steam(64, 23);
    }
  }

  @override
  bool shouldRepaint(_FoodPainter oldDelegate) => oldDelegate.kind != kind;
}
