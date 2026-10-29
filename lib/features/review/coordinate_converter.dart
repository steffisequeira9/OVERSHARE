import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../scanner/models/bounding_box.dart';

class CoordinateConverter {
  final double imageWidth;
  final double imageHeight;
  final double displayWidth;
  final double displayHeight;

  CoordinateConverter({
    required this.imageWidth,
    required this.imageHeight,
    required this.displayWidth,
    required this.displayHeight,
  });

  /// Scale factor applied by BoxFit.contain
  double get scale {
    if (imageWidth <= 0 || imageHeight <= 0 || displayWidth <= 0 || displayHeight <= 0) {
      return 1.0;
    }
    return math.min(displayWidth / imageWidth, displayHeight / imageHeight);
  }

  /// Rendered image dimensions inside the display container
  double get renderedWidth => imageWidth * scale;
  double get renderedHeight => imageHeight * scale;

  /// Horizontal letterbox offset (pillarbox)
  double get offsetX => (displayWidth - renderedWidth) / 2.0;

  /// Vertical letterbox offset
  double get offsetY => (displayHeight - renderedHeight) / 2.0;

  /// Maps an image-pixel [BoundingBox] to screen/display coordinates
  Rect imageToScreenRect(BoundingBox box) {
    final s = scale;
    return Rect.fromLTWH(
      offsetX + (box.left * s),
      offsetY + (box.top * s),
      box.width * s,
      box.height * s,
    );
  }

  /// Maps screen/display coordinates to image-pixel [BoundingBox]
  BoundingBox screenToImageRect(Rect screenRect) {
    final s = scale;
    if (s <= 0) return const BoundingBox.zero();

    // Clamp coordinates to the actual rendered image rectangle inside the container
    final clampedLeft = screenRect.left.clamp(offsetX, offsetX + renderedWidth);
    final clampedTop = screenRect.top.clamp(offsetY, offsetY + renderedHeight);
    final clampedRight = screenRect.right.clamp(offsetX, offsetX + renderedWidth);
    final clampedBottom = screenRect.bottom.clamp(offsetY, offsetY + renderedHeight);

    final imgLeft = (clampedLeft - offsetX) / s;
    final imgTop = (clampedTop - offsetY) / s;
    final imgWidth = (clampedRight - clampedLeft) / s;
    final imgHeight = (clampedBottom - clampedTop) / s;

    return BoundingBox(
      left: imgLeft.clamp(0.0, imageWidth),
      top: imgTop.clamp(0.0, imageHeight),
      width: imgWidth.clamp(0.0, imageWidth),
      height: imgHeight.clamp(0.0, imageHeight),
    );
  }

  /// Converts a screen touch point (x, y) to image-pixel space
  Offset? screenToImagePoint(Offset screenPoint) {
    if (screenPoint.dx < offsetX ||
        screenPoint.dx > offsetX + renderedWidth ||
        screenPoint.dy < offsetY ||
        screenPoint.dy > offsetY + renderedHeight) {
      return null;
    }

    final s = scale;
    return Offset(
      (screenPoint.dx - offsetX) / s,
      (screenPoint.dy - offsetY) / s,
    );
  }
}
