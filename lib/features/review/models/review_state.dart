import 'package:flutter/foundation.dart';
import '../../decision/rules_table.dart';
import '../../scanner/models/bounding_box.dart';
import '../../scanner/models/finding.dart';

enum RedactionSource {
  detectedFinding,
  manual,
}

@immutable
class RedactionRegion {
  final String id;
  final BoundingBox rect; // In original image pixel coordinates
  final RedactionSource source;
  final String label;
  final RedactionAction action;

  const RedactionRegion({
    required this.id,
    required this.rect,
    required this.source,
    required this.label,
    this.action = RedactionAction.hide,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RedactionRegion &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          rect == other.rect &&
          source == other.source &&
          label == other.label &&
          action == other.action;

  @override
  int get hashCode => Object.hash(id, rect, source, label, action);
}

@immutable
class FindingReviewItem {
  final Finding finding;
  final RedactionAction currentAction;
  final RedactionAction defaultAction; // From RulesTable
  final String reason;

  const FindingReviewItem({
    required this.finding,
    required this.currentAction,
    required this.defaultAction,
    required this.reason,
  });

  FindingReviewItem copyWith({
    Finding? finding,
    RedactionAction? currentAction,
    RedactionAction? defaultAction,
    String? reason,
  }) {
    return FindingReviewItem(
      finding: finding ?? this.finding,
      currentAction: currentAction ?? this.currentAction,
      defaultAction: defaultAction ?? this.defaultAction,
      reason: reason ?? this.reason,
    );
  }
}

@immutable
class ReviewState {
  final List<FindingReviewItem> findings;
  final List<BoundingBox> manualBoxes; // In image pixels
  final double imageWidth;
  final double imageHeight;

  const ReviewState({
    this.findings = const [],
    this.manualBoxes = const [],
    this.imageWidth = 0,
    this.imageHeight = 0,
  });

  ReviewState copyWith({
    List<FindingReviewItem>? findings,
    List<BoundingBox>? manualBoxes,
    double? imageWidth,
    double? imageHeight,
  }) {
    return ReviewState(
      findings: findings ?? this.findings,
      manualBoxes: manualBoxes ?? this.manualBoxes,
      imageWidth: imageWidth ?? this.imageWidth,
      imageHeight: imageHeight ?? this.imageHeight,
    );
  }

  /// Extracts the final list of regions to redact (in image pixels)
  /// including findings where action is not KEEP, plus all manual boxes.
  List<RedactionRegion> getFinalRedactionRegions() {
    final List<RedactionRegion> regions = [];

    // 1. Findings where action is not KEEP
    for (int i = 0; i < findings.length; i++) {
      final item = findings[i];
      if (!item.currentAction.isKeep) {
        regions.add(
          RedactionRegion(
            id: 'finding_$i',
            rect: item.finding.boundingBox,
            source: RedactionSource.detectedFinding,
            label: '${item.finding.type.displayName} (${item.finding.maskedPreview})',
            action: item.currentAction,
          ),
        );
      }
    }

    // 2. Manual user-drawn boxes (always redacted with solid fill)
    for (int i = 0; i < manualBoxes.length; i++) {
      regions.add(
        RedactionRegion(
          id: 'manual_$i',
          rect: manualBoxes[i],
          source: RedactionSource.manual,
          label: 'Manual Redaction #${i + 1}',
          action: RedactionAction.hide,
        ),
      );
    }

    return regions;
  }
}
