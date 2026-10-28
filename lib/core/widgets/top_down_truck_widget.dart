import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

class TopDownTruckWidget extends StatelessWidget {
  final double headingDegrees;
  final bool isSelected;
  final bool isLiveTracking;
  final Color cabinColor;
  final Color cargoColor;
  final double width;
  final double height;
  final String? label;

  const TopDownTruckWidget({
    super.key,
    required this.headingDegrees,
    this.isSelected = false,
    this.isLiveTracking = false,
    this.cabinColor = AppColors.primary,
    this.cargoColor = const Color(0xFFF1F5F9),
    this.width = 28.0,
    this.height = 52.0,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
        if (label != null && label!.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.accent : const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(6),
              boxShadow: const [
                BoxShadow(color: Colors.black38, blurRadius: 4, offset: Offset(0, 2)),
              ],
            ),
            child: Text(
              label!,
              maxLines: 1,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ),
          const SizedBox(height: 3),
        ],
        AnimatedRotation(
          turns: headingDegrees / 360.0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
          child: SizedBox(
            width: width + 16, // room for mirrors and headlight beam
            height: height + (isLiveTracking ? 18 : 6),
            child: CustomPaint(
              painter: _TopDownTruckPainter(
                cabinColor: isSelected ? AppColors.accent : cabinColor,
                cargoColor: cargoColor,
                isSelected: isSelected,
                isLiveTracking: isLiveTracking,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
}

class _TopDownTruckPainter extends CustomPainter {
  final Color cabinColor;
  final Color cargoColor;
  final bool isSelected;
  final bool isLiveTracking;

  _TopDownTruckPainter({
    required this.cabinColor,
    required this.cargoColor,
    required this.isSelected,
    required this.isLiveTracking,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double truckW = size.width - 16;
    final double truckH = isLiveTracking ? size.height - 18 : size.height - 6;
    final double startX = (size.width - truckW) / 2;
    final double startY = isLiveTracking ? 18.0 : 4.0;

    // 1. Headlight glow beams projecting forward if live tracking
    if (isLiveTracking) {
      final Paint beamPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.yellowAccent.withValues(alpha: 0.5),
            Colors.yellowAccent.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(0, 0, size.width, startY + 4));

      // Left beam
      final Path leftBeam = Path()
        ..moveTo(startX + 3, startY + 2)
        ..lineTo(startX - 6, 0)
        ..lineTo(startX + 9, 0)
        ..close();
      canvas.drawPath(leftBeam, beamPaint);

      // Right beam
      final Path rightBeam = Path()
        ..moveTo(startX + truckW - 3, startY + 2)
        ..lineTo(startX + truckW - 9, 0)
        ..lineTo(startX + truckW + 6, 0)
        ..close();
      canvas.drawPath(rightBeam, beamPaint);
    }

    // 2. Realistic Drop Shadow
    final Paint shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    final RRect shadowRRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(startX + 1, startY + 2, truckW, truckH),
      const Radius.circular(5),
    );
    canvas.drawRRect(shadowRRect, shadowPaint);

    // 3. Black Rubber Wheels (4 tires)
    final Paint wheelPaint = Paint()..color = const Color(0xFF1E293B);
    const double wheelW = 3.5;
    const double wheelH = 8.5;

    // Front-left
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(startX - wheelW + 1, startY + 7, wheelW, wheelH),
        const Radius.circular(1.5),
      ),
      wheelPaint,
    );
    // Front-right
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(startX + truckW - 1, startY + 7, wheelW, wheelH),
        const Radius.circular(1.5),
      ),
      wheelPaint,
    );
    // Rear-left
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(startX - wheelW + 1, startY + truckH - 14, wheelW, wheelH),
        const Radius.circular(1.5),
      ),
      wheelPaint,
    );
    // Rear-right
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(startX + truckW - 1, startY + truckH - 14, wheelW, wheelH),
        const Radius.circular(1.5),
      ),
      wheelPaint,
    );

    // 4. Rear Cargo Bed / Thùng xe tải (from 35% height to bottom)
    final double cabinH = truckH * 0.36;
    final double cargoH = truckH - cabinH;

    final Paint cargoPaint = Paint()..color = cargoColor;
    final Rect cargoRect = Rect.fromLTWH(startX, startY + cabinH, truckW, cargoH);
    canvas.drawRRect(
      RRect.fromRectAndRadius(cargoRect, const Radius.circular(3.5)),
      cargoPaint,
    );

    // Cargo bed outline & ribs (gân thùng xe tải)
    final Paint cargoBorderPaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(cargoRect, const Radius.circular(3.5)),
      cargoBorderPaint,
    );

    final Paint ribPaint = Paint()
      ..color = const Color(0xFFCBD5E1)
      ..strokeWidth = 1.0;
    final double ribStep = cargoH / 4.0;
    for (int i = 1; i < 4; i++) {
      final y = startY + cabinH + i * ribStep;
      canvas.drawLine(Offset(startX + 2, y), Offset(startX + truckW - 2, y), ribPaint);
    }

    // Rear Tail Lights (Đèn hậu đỏ)
    final Paint tailLightPaint = Paint()..color = const Color(0xFFEF4444);
    canvas.drawRect(Rect.fromLTWH(startX + 2, startY + truckH - 2, 4, 2), tailLightPaint);
    canvas.drawRect(Rect.fromLTWH(startX + truckW - 6, startY + truckH - 2, 4, 2), tailLightPaint);

    // 5. Front Cabin (Đầu xe)
    final Paint cabinPaint = Paint()..color = cabinColor;
    final RRect cabinRRect = RRect.fromRectAndCorners(
      Rect.fromLTWH(startX + 0.5, startY, truckW - 1, cabinH + 2),
      topLeft: const Radius.circular(6.0),
      topRight: const Radius.circular(6.0),
      bottomLeft: const Radius.circular(2.0),
      bottomRight: const Radius.circular(2.0),
    );
    canvas.drawRRect(cabinRRect, cabinPaint);

    // Side mirrors (Gương chiếu hậu 2 bên)
    final Paint mirrorPaint = Paint()..color = cabinColor;
    // Left mirror
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(startX - 2.5, startY + 7, 3, 4.5),
        const Radius.circular(1),
      ),
      mirrorPaint,
    );
    // Right mirror
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(startX + truckW - 0.5, startY + 7, 3, 4.5),
        const Radius.circular(1),
      ),
      mirrorPaint,
    );

    // Curved Front Windshield (Kính chắn gió trước màu kính râm)
    final Paint windshieldPaint = Paint()..color = const Color(0xFF1E293B);
    final Path windshieldPath = Path()
      ..moveTo(startX + 4, startY + 8)
      ..quadraticBezierTo(startX + truckW / 2, startY + 6, startX + truckW - 4, startY + 8)
      ..lineTo(startX + truckW - 3, startY + 14)
      ..quadraticBezierTo(startX + truckW / 2, startY + 12.5, startX + 3, startY + 14)
      ..close();
    canvas.drawPath(windshieldPath, windshieldPaint);

    // Front Headlights (Đèn pha trước)
    final Paint headLightPaint = Paint()..color = const Color(0xFFFEF08A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(startX + 2.5, startY + 0.5, 3.5, 2), const Radius.circular(1)),
      headLightPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(startX + truckW - 6, startY + 0.5, 3.5, 2), const Radius.circular(1)),
      headLightPaint,
    );

    // 6. If selected: Draw glowing active border and green checkmark dot
    if (isSelected) {
      final Paint selectedBorder = Paint()
        ..color = AppColors.accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(startX - 1, startY - 1, truckW + 2, truckH + 2),
          const Radius.circular(6),
        ),
        selectedBorder,
      );

      // Checkmark indicator circle on the cargo roof
      final Paint dotBg = Paint()..color = AppColors.success;
      canvas.drawCircle(Offset(startX + truckW / 2, startY + cabinH + cargoH / 2), 4.5, dotBg);
      final Paint dotWhite = Paint()..color = Colors.white;
      canvas.drawCircle(Offset(startX + truckW / 2, startY + cabinH + cargoH / 2), 2.0, dotWhite);
    }
  }

  @override
  bool shouldRepaint(covariant _TopDownTruckPainter oldDelegate) {
    return oldDelegate.cabinColor != cabinColor ||
        oldDelegate.cargoColor != cargoColor ||
        oldDelegate.isSelected != isSelected ||
        oldDelegate.isLiveTracking != isLiveTracking;
  }
}
