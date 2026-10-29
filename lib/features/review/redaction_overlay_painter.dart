import 'package:flutter/material.dart';
import '../scanner/models/bounding_box.dart';
import 'coordinate_converter.dart';
import 'models/review_state.dart';

class RedactionOverlayPainter extends CustomPainter {
  final List<FindingReviewItem> findings;
  final List<BoundingBox> manualBoxes;
  final Rect? currentDrawingRect;
  final CoordinateConverter converter;
  final int? selectedIndex;

  const RedactionOverlayPainter({
    required this.findings,
    required this.manualBoxes,
    required this.currentDrawingRect,
    required this.converter,
    this.selectedIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw detected findings
    for (int i = 0; i < findings.length; i++) {
      final item = findings[i];
      final screenRect = converter.imageToScreenRect(item.finding.boundingBox);
      final isSelected = selectedIndex == i;

      final isRedacted = !item.currentAction.isKeep;
      final Color baseColor = item.currentAction.isKeep
          ? const Color(0xFF10B981) // Green for KEEP
          : item.currentAction.isBlurFace
              ? const Color(0xFF8B5CF6) // Purple for BLUR FACE
              : const Color(0xFFEF4444); // Red for HIDE / COVER FACE

      // Semi-transparent fill
      final fillPaint = Paint()
        ..color = baseColor.withValues(alpha: isSelected ? 0.45 : (isRedacted ? 0.35 : 0.15))
        ..style = PaintingStyle.fill;

      // Solid outline
      final borderPaint = Paint()
        ..color = isSelected ? Colors.amberAccent : baseColor
        ..strokeWidth = isSelected ? 3.5 : 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawRect(screenRect, fillPaint);
      canvas.drawRect(screenRect, borderPaint);

      // Label badge
      _drawTag(
        canvas: canvas,
        rect: screenRect,
        text: isSelected ? '★ ${item.currentAction.label}' : item.currentAction.label,
        bgColor: isSelected ? const Color(0xFFD97706) : baseColor,
      );
    }

    // 2. Draw user manual redaction boxes
    for (int i = 0; i < manualBoxes.length; i++) {
      final screenRect = converter.imageToScreenRect(manualBoxes[i]);

      final fillPaint = Paint()
        ..color = const Color(0xFFDC2626).withValues(alpha: 0.45)
        ..style = PaintingStyle.fill;

      final borderPaint = Paint()
        ..color = const Color(0xFF991B1B)
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;

      canvas.drawRect(screenRect, fillPaint);
      canvas.drawRect(screenRect, borderPaint);

      _drawTag(
        canvas: canvas,
        rect: screenRect,
        text: 'MANUAL #${i + 1}',
        bgColor: const Color(0xFF991B1B),
      );
    }

    // 3. Draw active drag box (currently being drawn by user)
    if (currentDrawingRect != null) {
      final activeFill = Paint()
        ..color = const Color(0xFF2563EB).withValues(alpha: 0.25)
        ..style = PaintingStyle.fill;

      final activeBorder = Paint()
        ..color = const Color(0xFF2563EB)
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawRect(currentDrawingRect!, activeFill);
      canvas.drawRect(currentDrawingRect!, activeBorder);
    }
  }

  void _drawTag({
    required Canvas canvas,
    required Rect rect,
    required String text,
    required Color bgColor,
  }) {
    final textSpan = TextSpan(
      text: text,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 9.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final bgRect = Rect.fromLTWH(
      rect.left,
      rect.top - 16 >= 0 ? rect.top - 16 : rect.top,
      textPainter.width + 8,
      14,
    );

    final bgPaint = Paint()..color = bgColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(bgRect, const Radius.circular(3)),
      bgPaint,
    );

    textPainter.paint(
      canvas,
      Offset(bgRect.left + 4, bgRect.top + (14 - textPainter.height) / 2),
    );
  }

  @override
  bool shouldRepaint(covariant RedactionOverlayPainter oldDelegate) {
    return oldDelegate.findings != findings ||
        oldDelegate.manualBoxes != manualBoxes ||
        oldDelegate.currentDrawingRect != currentDrawingRect ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.converter.scale != converter.scale ||
        oldDelegate.converter.offsetX != converter.offsetX ||
        oldDelegate.converter.offsetY != converter.offsetY;
  }
}
