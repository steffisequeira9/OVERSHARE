import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_state.dart';
import 'diagnostic_logger.dart';
import 'face_detector_service.dart';
import 'models/finding.dart';
import 'models/ocr_line.dart';
import 'ocr_service.dart';
import 'pattern_detector.dart';

final ocrServiceProvider = Provider<OcrService>((ref) {
  final service = MlKitOcrService();
  ref.onDispose(() => service.dispose());
  return service;
});

final faceDetectorServiceProvider = Provider<FaceDetectorService>((ref) {
  final service = MlKitFaceDetectorService();
  ref.onDispose(() => service.dispose());
  return service;
});

final patternDetectorProvider = Provider<PatternDetector>((ref) {
  return const PatternDetector();
});

final scanFindingsProvider = FutureProvider<List<Finding>>((ref) async {
  final image = ref.watch(selectedImageProvider);
  if (image == null) return [];

  final ocrService = ref.watch(ocrServiceProvider);
  final faceDetector = ref.watch(faceDetectorServiceProvider);
  final detector = ref.watch(patternDetectorProvider);

  final pipelineStopwatch = Stopwatch()..start();

  Uint8List? imageBytes;
  if (kIsWeb) {
    try {
      imageBytes = await image.readAsBytes();
    } catch (e) {
      debugPrint('[OVERSHARE-DIAG] Failed to read image bytes: $e');
    }
  }

  // Run OCR and Face Detection concurrently
  final ocrFuture = ocrService.recognizeText(image.path, imageBytes: imageBytes);
  final faceFuture = faceDetector.detectFaces(image.path);

  final results = await Future.wait([ocrFuture, faceFuture]);
  final lines = results[0] as List<OcrLine>;
  final faces = results[1] as List<Finding>;

  final ocrFindings = detector.detectFindings(lines);
  final allFindings = [...faces, ...ocrFindings];

  pipelineStopwatch.stop();
  DiagnosticLogger.logPipelineComplete(
    totalFindings: allFindings.length,
    durationMs: pipelineStopwatch.elapsedMilliseconds,
  );

  return allFindings;
});
