import 'package:flutter/foundation.dart';

/// Privacy-safe diagnostic logger for scanning, OCR, and detection pipelines.
///
/// STRICT PRIVACY RULES:
/// - NEVER logs raw OCR text, recognized lines, or candidate strings.
/// - NEVER logs phone numbers, UPI IDs, bank accounts, emails, or names.
/// - NEVER logs image bytes, base64 data, or API keys.
/// - ONLY logs anonymous aggregate counts, bounding box counts, durations,
///   platform indicators, and finding category distributions.
class DiagnosticLogger {
  const DiagnosticLogger();

  static void logOcrStart({
    required int pathLength,
    required bool isWeb,
    required String platformName,
  }) {
    debugPrint(
      '[OVERSHARE-DIAG][OCR] Started text recognition: '
      'platform=$platformName, isWeb=$isWeb, pathLen=$pathLength',
    );
  }

  static void logOcrSuccess({
    required int blockCount,
    required int lineCount,
    required int durationMs,
  }) {
    debugPrint(
      '[OVERSHARE-DIAG][OCR] Text recognition complete: '
      'blocks=$blockCount, lines=$lineCount, duration=${durationMs}ms',
    );
  }

  static void logOcrError({
    required String errorType,
    required String safeMessage,
  }) {
    debugPrint(
      '[OVERSHARE-DIAG][OCR] Text recognition failed: '
      'errorType=$errorType, message=$safeMessage',
    );
  }

  static void logFaceStart() {
    debugPrint('[OVERSHARE-DIAG][FACE] Started face detection');
  }

  static void logFaceSuccess({
    required int faceCount,
    required int durationMs,
  }) {
    debugPrint(
      '[OVERSHARE-DIAG][FACE] Face detection complete: '
      'faces=$faceCount, duration=${durationMs}ms',
    );
  }

  static void logPatternScan({
    required int linesScanned,
    required int candidateCount,
    required int finalFindingCount,
    required Map<String, int> typeCounts,
    required int durationMs,
  }) {
    final typeSummary = typeCounts.entries
        .map((e) => '${e.key}:${e.value}')
        .join(', ');
    debugPrint(
      '[OVERSHARE-DIAG][DETECTOR] Pattern scan complete: '
      'lines=$linesScanned, candidates=$candidateCount, '
      'findings=$finalFindingCount [$typeSummary], duration=${durationMs}ms',
    );
  }

  static void logPipelineComplete({
    required int totalFindings,
    required int durationMs,
  }) {
    debugPrint(
      '[OVERSHARE-DIAG][PIPELINE] Scan pipeline finished: '
      'totalFindings=$totalFindings, duration=${durationMs}ms',
    );
  }
}
