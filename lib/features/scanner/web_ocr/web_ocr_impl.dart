import 'dart:convert';
import 'dart:js_interop';
import '../models/bounding_box.dart';
import '../models/ocr_line.dart';

@JS('overshareRecognizeText')
external JSPromise<JSString> _overshareRecognizeText(JSString imageSource);

Future<List<OcrLine>> runWebOcrImpl(String imageSource) async {
  try {
    final promise = _overshareRecognizeText(imageSource.toJS);
    final jsString = await promise.toDart;
    final jsonStr = jsString.toDart;
    final List<dynamic> rawLines = jsonDecode(jsonStr) as List<dynamic>;

    final List<OcrLine> lines = [];
    for (final rawLine in rawLines) {
      if (rawLine is! Map<String, dynamic>) continue;
      final text = rawLine['text'] as String? ?? '';
      final bboxMap = rawLine['bbox'] as Map<String, dynamic>? ?? {};
      final x0 = (bboxMap['x0'] as num?)?.toDouble() ?? 0.0;
      final y0 = (bboxMap['y0'] as num?)?.toDouble() ?? 0.0;
      final x1 = (bboxMap['x1'] as num?)?.toDouble() ?? 0.0;
      final y1 = (bboxMap['y1'] as num?)?.toDouble() ?? 0.0;

      final wordsRaw = rawLine['words'] as List<dynamic>? ?? [];
      final List<OcrElement> elements = [];
      for (final rawWord in wordsRaw) {
        if (rawWord is! Map<String, dynamic>) continue;
        final wText = rawWord['text'] as String? ?? '';
        final wBbox = rawWord['bbox'] as Map<String, dynamic>? ?? {};
        final wx0 = (wBbox['x0'] as num?)?.toDouble() ?? 0.0;
        final wy0 = (wBbox['y0'] as num?)?.toDouble() ?? 0.0;
        final wx1 = (wBbox['x1'] as num?)?.toDouble() ?? 0.0;
        final wy1 = (wBbox['y1'] as num?)?.toDouble() ?? 0.0;

        elements.add(
          OcrElement(
            text: wText,
            boundingBox: BoundingBox(
              left: wx0,
              top: wy0,
              width: (wx1 - wx0) > 0 ? (wx1 - wx0) : 0.0,
              height: (wy1 - wy0) > 0 ? (wy1 - wy0) : 0.0,
            ),
          ),
        );
      }

      lines.add(
        OcrLine(
          text: text,
          boundingBox: BoundingBox(
            left: x0,
            top: y0,
            width: (x1 - x0) > 0 ? (x1 - x0) : 0.0,
            height: (y1 - y0) > 0 ? (y1 - y0) : 0.0,
          ),
          elements: elements,
        ),
      );
    }
    return lines;
  } catch (e) {
    throw Exception('Web OCR execution failed: $e');
  }
}
