import '../theme/app_localizations.dart';
import 'package:flutter/material.dart';

/// Original vector mark: two open pages forming a companion's smile.
class BuddyMark extends StatelessWidget {
  final double size;
  const BuddyMark({super.key, this.size = 64});
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'AksharBuddy, your reading companion',
    image: true,
    child: SizedBox.square(
      dimension: size,
      child: CustomPaint(painter: _BuddyPainter()),
    ),
  );
}

class _BuddyPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 100, size.height / 100);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(0, 0, 100, 100),
        const Radius.circular(28),
      ),
      Paint()..color = const Color(0xFF143D49),
    );
    final left = Path()
      ..moveTo(18, 28)
      ..quadraticBezierTo(34, 24, 47, 37)
      ..lineTo(47, 72)
      ..quadraticBezierTo(32, 62, 18, 65)
      ..close();
    final right = Path()
      ..moveTo(53, 37)
      ..quadraticBezierTo(67, 24, 82, 28)
      ..lineTo(82, 65)
      ..quadraticBezierTo(67, 62, 53, 72)
      ..close();
    canvas.drawPath(left, Paint()..color = const Color(0xFFFFF8EB));
    canvas.drawPath(right, Paint()..color = const Color(0xFF89A886));
    canvas.drawCircle(
      const Offset(33, 44),
      2.5,
      Paint()..color = const Color(0xFF143D49),
    );
    canvas.drawCircle(
      const Offset(67, 44),
      2.5,
      Paint()..color = const Color(0xFF143D49),
    );
    canvas.drawPath(
      Path()
        ..moveTo(39, 78)
        ..quadraticBezierTo(50, 85, 61, 78),
      Paint()
        ..color = const Color(0xFFFFCF83)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.5
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class BuddyCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  const BuddyCard({super.key, required this.child, this.color});
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color ?? Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .10),
      ),
    ),
    child: child,
  );
}

class BuddyHeading extends StatelessWidget {
  final String title, subtitle;
  const BuddyHeading(this.title, this.subtitle, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LText(title, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 8),
        LText(subtitle),
      ],
    ),
  );
}
