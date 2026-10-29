import 'package:flutter/foundation.dart';

@immutable
class BoundingBox {
  final double left;
  final double top;
  final double width;
  final double height;

  const BoundingBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  const BoundingBox.zero()
      : left = 0,
        top = 0,
        width = 0,
        height = 0;

  double get right => left + width;
  double get bottom => top + height;

  bool get isEmpty => width <= 0 || height <= 0;

  BoundingBox copyWith({
    double? left,
    double? top,
    double? width,
    double? height,
  }) {
    return BoundingBox(
      left: left ?? this.left,
      top: top ?? this.top,
      width: width ?? this.width,
      height: height ?? this.height,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoundingBox &&
          runtimeType == other.runtimeType &&
          left == other.left &&
          top == other.top &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(left, top, width, height);

  @override
  String toString() =>
      'BoundingBox(x: ${left.toStringAsFixed(1)}, y: ${top.toStringAsFixed(1)}, w: ${width.toStringAsFixed(1)}, h: ${height.toStringAsFixed(1)})';
}
