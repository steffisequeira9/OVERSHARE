import 'package:flutter/foundation.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'diagnostic_logger.dart';
import 'models/bounding_box.dart';
import 'models/finding.dart';
import 'models/sensitive_type.dart';

abstract class FaceDetectorService {
  Future<List<Finding>> detectFaces(String imagePath);
  Future<void> dispose();
}

class MlKitFaceDetectorService implements FaceDetectorService {
  FaceDetector? _faceDetector;

  FaceDetector? get _detector {
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.android &&
            defaultTargetPlatform != TargetPlatform.iOS)) {
      return null;
    }
    try {
      return _faceDetector ??= FaceDetector(
        options: FaceDetectorOptions(
          enableContours: false,
          enableLandmarks: false,
          enableClassification: false,
          enableTracking: false,
          minFaceSize: 0.1,
          performanceMode: FaceDetectorMode.fast,
        ),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<Finding>> detectFaces(String imagePath) async {
    final detector = _detector;
    if (detector == null) {
      return [];
    }

    final stopwatch = Stopwatch()..start();
    DiagnosticLogger.logFaceStart();

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final faces = await detector.processImage(inputImage);
      stopwatch.stop();

      DiagnosticLogger.logFaceSuccess(
        faceCount: faces.length,
        durationMs: stopwatch.elapsedMilliseconds,
      );

      return faces.map((face) {
        final box = BoundingBox(
          left: face.boundingBox.left.toDouble(),
          top: face.boundingBox.top.toDouble(),
          width: face.boundingBox.width.toDouble(),
          height: face.boundingBox.height.toDouble(),
        );
        return Finding(
          type: SensitiveType.face,
          matchedText: '[Face detected]',
          boundingBox: box,
          confidence: 0.95,
          source: FindingSource.face,
          status: DetectionStatus.detected,
        );
      }).toList();
    } catch (e, st) {
      stopwatch.stop();
      debugPrint('[OVERSHARE-DIAG] ML Kit Face Detection warning: $e\n$st');
      return [];
    }
  }

  @override
  Future<void> dispose() async {
    await _faceDetector?.close();
    _faceDetector = null;
  }
}

class MockFaceDetectorService implements FaceDetectorService {
  final List<Finding> facesToReturn;

  MockFaceDetectorService({this.facesToReturn = const []});

  @override
  Future<List<Finding>> detectFaces(String imagePath) async {
    return facesToReturn;
  }

  @override
  Future<void> dispose() async {}
}
