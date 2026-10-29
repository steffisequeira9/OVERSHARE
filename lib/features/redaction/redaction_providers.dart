import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import '../../core/app_state.dart';
import '../decision/decision_providers.dart';
import '../decision/purpose.dart';
import '../decision/risk_scorer.dart';
import '../scanner/models/finding.dart';
import '../scanner/scanner_providers.dart';
import 'export_service.dart';
import 'metadata_service.dart';
import 'redaction_service.dart';

final redactionServiceProvider = Provider<RedactionService>((ref) {
  return const RedactionService();
});

final metadataServiceProvider = Provider<MetadataService>((ref) {
  return const MetadataService();
});

final exportServiceProvider = Provider<ExportService>((ref) {
  return const ExportService();
});

class RedactionStyleNotifier extends Notifier<RedactionStyle> {
  @override
  RedactionStyle build() => RedactionStyle.solidFill;

  void setStyle(RedactionStyle style) => state = style;
}

final selectedRedactionStyleProvider =
    NotifierProvider<RedactionStyleNotifier, RedactionStyle>(
  RedactionStyleNotifier.new,
);

final originalMetadataProvider = FutureProvider<List<MetadataItem>>((ref) async {
  final imageFile = ref.watch(selectedImageProvider);
  if (imageFile == null) return [];

  final bytes = await imageFile.readAsBytes();
  final service = ref.watch(metadataServiceProvider);
  return service.extractMetadata(bytes);
});

@immutable
class SanitizedExportState {
  final bool isProcessing;
  final ExportResult? exportResult;
  final Uint8List? sanitizedBytes;
  final List<Finding> residualFindings;
  final RiskScoreResult? residualScoreResult;
  final bool isSavedToGallery;
  final bool isMetadataStrippedVerified;
  final String? error;

  const SanitizedExportState({
    this.isProcessing = false,
    this.exportResult,
    this.sanitizedBytes,
    this.residualFindings = const [],
    this.residualScoreResult,
    this.isSavedToGallery = false,
    this.isMetadataStrippedVerified = false,
    this.error,
  });

  SanitizedExportState copyWith({
    bool? isProcessing,
    ExportResult? exportResult,
    Uint8List? sanitizedBytes,
    List<Finding>? residualFindings,
    RiskScoreResult? residualScoreResult,
    bool? isSavedToGallery,
    bool? isMetadataStrippedVerified,
    String? error,
  }) {
    return SanitizedExportState(
      isProcessing: isProcessing ?? this.isProcessing,
      exportResult: exportResult ?? this.exportResult,
      sanitizedBytes: sanitizedBytes ?? this.sanitizedBytes,
      residualFindings: residualFindings ?? this.residualFindings,
      residualScoreResult: residualScoreResult ?? this.residualScoreResult,
      isSavedToGallery: isSavedToGallery ?? this.isSavedToGallery,
      isMetadataStrippedVerified:
          isMetadataStrippedVerified ?? this.isMetadataStrippedVerified,
      error: error,
    );
  }
}

class SanitizedExportNotifier extends Notifier<SanitizedExportState> {
  @override
  SanitizedExportState build() => const SanitizedExportState();

  Future<void> exportImage({
    required Uint8List originalBytes,
    required List<dynamic> regions,
    required RedactionStyle style,
  }) async {
    state = state.copyWith(isProcessing: true, error: null);

    try {
      final redactionService = ref.read(redactionServiceProvider);
      final exportService = ref.read(exportServiceProvider);
      final metadataService = ref.read(metadataServiceProvider);
      final ocrService = ref.read(ocrServiceProvider);
      final faceDetector = ref.read(faceDetectorServiceProvider);
      final patternDetector = ref.read(patternDetectorProvider);
      final scorer = ref.read(riskScorerProvider);
      final purpose = ref.read(selectedPurposeProvider) ?? Purpose.paymentProof;
      final audience = ref.read(selectedAudienceProvider);

      // Extract BoundingBox from regions
      final boxes = regions.map((r) => r.rect).toList();

      final sanitizedBytes = redactionService.redactImageBytes(
        imageBytes: originalBytes,
        regions: List.from(boxes),
        style: style,
      );

      // Verify that pixel modification actually occurred on the decoded image
      final verifiedModification = redactionService.verifyRedactionApplied(
        originalBytes: originalBytes,
        redactedBytes: sanitizedBytes,
        regions: List.from(boxes),
        style: style,
      );
      if (!verifiedModification) {
        throw StateError(
          'Export verification failed: Redacted image pixels were not permanently modified.',
        );
      }

      // Verify EXIF metadata was genuinely removed
      final isExifStripped = metadataService.verifyExifStripped(sanitizedBytes);

      // Save using platform-compatible saver
      final exportResult = await exportService.saveSanitizedImage(sanitizedBytes);

      // Residual verification: re-scan exported bytes for remaining sensitive tokens
      List<Finding> residualFindings = [];
      RiskScoreResult residualScore = const RiskScoreResult.zero();

      try {
        final rescanLines = await ocrService.recognizeText(
          exportResult.filePath,
          imageBytes: sanitizedBytes,
        );
        final rescanOcr = patternDetector.detectFindings(rescanLines);
        final rescanFaces = await faceDetector.detectFaces(exportResult.filePath);
        residualFindings = [...rescanFaces, ...rescanOcr];
        residualScore = scorer.calculateScore(residualFindings, purpose, audience);
      } catch (scanErr) {
        debugPrint('Residual scan check warning: $scanErr');
      }

      state = SanitizedExportState(
        isProcessing: false,
        sanitizedBytes: sanitizedBytes,
        exportResult: exportResult,
        residualFindings: residualFindings,
        residualScoreResult: residualScore,
        isMetadataStrippedVerified: isExifStripped,
      );
    } catch (e) {
      state = SanitizedExportState(
        isProcessing: false,
        error: e.toString(),
      );
    }
  }

  Future<bool> saveToDeviceGallery() async {
    final result = state.exportResult;
    if (result == null) return false;

    try {
      if (kIsWeb) {
        // On web, re-trigger the browser download of the sanitized image
        final exportService = ref.read(exportServiceProvider);
        if (state.sanitizedBytes != null) {
          await exportService.saveSanitizedImage(state.sanitizedBytes!);
          state = state.copyWith(isSavedToGallery: true);
          return true;
        }
        return false;
      }

      if (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS) {
        await Gal.putImage(result.filePath);
        state = state.copyWith(isSavedToGallery: true);
        return true;
      }
      return true;
    } catch (e) {
      debugPrint('Failed to save image to gallery: $e');
      return false;
    }
  }

  void reset() {
    state = const SanitizedExportState();
  }
}

final sanitizedExportNotifierProvider =
    NotifierProvider<SanitizedExportNotifier, SanitizedExportState>(
  SanitizedExportNotifier.new,
);
