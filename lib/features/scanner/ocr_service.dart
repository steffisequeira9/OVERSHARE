import 'dart:convert' show base64Encode;
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'diagnostic_logger.dart';
import 'models/bounding_box.dart';
import 'models/ocr_line.dart';
import 'web_ocr/web_ocr.dart';

/// Exception thrown when OCR fails, times out, or runs on an unsupported platform.
class OcrException implements Exception {
  final String message;
  final Object? cause;

  const OcrException(this.message, [this.cause]);

  @override
  String toString() => 'OcrException: $message';
}

abstract class OcrService {
  Future<List<OcrLine>> recognizeText(String imagePath, {Uint8List? imageBytes});
  Future<void> dispose();
}

class MlKitOcrService implements OcrService {
  TextRecognizer? _textRecognizer;

  TextRecognizer get _recognizer =>
      _textRecognizer ??= TextRecognizer(script: TextRecognitionScript.latin);

  @override
  Future<List<OcrLine>> recognizeText(String imagePath, {Uint8List? imageBytes}) async {
    final stopwatch = Stopwatch()..start();

    DiagnosticLogger.logOcrStart(
      pathLength: imagePath.length,
      isWeb: kIsWeb,
      platformName: defaultTargetPlatform.name,
    );

    // On Web, run client-side in-browser Tesseract.js (Web Worker / WASM)
    if (kIsWeb) {
      try {
        final String imageSource;
        if (imageBytes != null && imageBytes.isNotEmpty) {
          imageSource = 'data:image/png;base64,${base64Encode(imageBytes)}';
        } else {
          imageSource = imagePath;
        }

        final lines = await runWebOcr(imageSource);
        stopwatch.stop();
        DiagnosticLogger.logOcrSuccess(
          blockCount: 1,
          lineCount: lines.length,
          durationMs: stopwatch.elapsedMilliseconds,
        );
        return lines;
      } catch (e, st) {
        stopwatch.stop();
        DiagnosticLogger.logOcrError(
          errorType: 'WebOcrFailure',
          safeMessage: 'Tesseract Web OCR processing failed',
        );
        debugPrint('[OVERSHARE-DIAG] Web OCR error: $e\n$st');
        throw OcrException('In-browser OCR processing failed: $e', e);
      }
    }

    // Verify file accessibility on native targets
    try {
      final file = File(imagePath);
      if (!file.existsSync()) {
        DiagnosticLogger.logOcrError(
          errorType: 'FileNotFound',
          safeMessage: 'Image file does not exist at provided path',
        );
        throw OcrException('Selected image file does not exist or is inaccessible: path length ${imagePath.length}');
      }
    } catch (e) {
      if (e is OcrException) rethrow;
      DiagnosticLogger.logOcrError(
        errorType: 'FileAccessError',
        safeMessage: 'Failed to access image file on filesystem',
      );
      throw OcrException('Cannot access image file: ${e.runtimeType}', e);
    }

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _recognizer.processImage(inputImage);

      final List<OcrLine> resultLines = [];

      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          final lineBox = BoundingBox(
            left: line.boundingBox.left.toDouble(),
            top: line.boundingBox.top.toDouble(),
            width: line.boundingBox.width.toDouble(),
            height: line.boundingBox.height.toDouble(),
          );

          final elements = line.elements.map((el) {
            return OcrElement(
              text: el.text,
              boundingBox: BoundingBox(
                left: el.boundingBox.left.toDouble(),
                top: el.boundingBox.top.toDouble(),
                width: el.boundingBox.width.toDouble(),
                height: el.boundingBox.height.toDouble(),
              ),
            );
          }).toList();

          resultLines.add(
            OcrLine(
              text: line.text,
              boundingBox: lineBox,
              elements: elements,
            ),
          );
        }
      }

      stopwatch.stop();
      DiagnosticLogger.logOcrSuccess(
        blockCount: recognizedText.blocks.length,
        lineCount: resultLines.length,
        durationMs: stopwatch.elapsedMilliseconds,
      );

      return resultLines;
    } catch (e, st) {
      stopwatch.stop();
      DiagnosticLogger.logOcrError(
        errorType: e.runtimeType.toString(),
        safeMessage: 'OCR processImage execution failed',
      );
      debugPrint('[OVERSHARE-DIAG] ML Kit OCR error details: $e\n$st');
      throw OcrException('OCR processing failed on-device (${e.runtimeType}).', e);
    }
  }

  @override
  Future<void> dispose() async {
    await _textRecognizer?.close();
    _textRecognizer = null;
  }
}

class MockOcrService implements OcrService {
  final List<OcrLine> linesToReturn;
  final bool shouldThrow;
  final String? errorMessage;

  MockOcrService({
    this.linesToReturn = const [],
    this.shouldThrow = false,
    this.errorMessage,
  });

  @override
  Future<List<OcrLine>> recognizeText(String imagePath, {Uint8List? imageBytes}) async {
    if (shouldThrow) {
      throw OcrException(errorMessage ?? 'Mock OCR simulated failure');
    }
    return linesToReturn;
  }

  @override
  Future<void> dispose() async {}
}
