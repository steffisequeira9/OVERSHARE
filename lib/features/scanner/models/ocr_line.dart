import 'package:flutter/foundation.dart';
import 'bounding_box.dart';

@immutable
class OcrElement {
  final String text;
  final BoundingBox boundingBox;

  const OcrElement({
    required this.text,
    required this.boundingBox,
  });
}

@immutable
class OcrLine {
  final String text;
  final BoundingBox boundingBox;
  final List<OcrElement> elements;

  const OcrLine({
    required this.text,
    required this.boundingBox,
    this.elements = const [],
  });
}
