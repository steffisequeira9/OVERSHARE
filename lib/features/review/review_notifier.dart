import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_state.dart';
import '../decision/decision_providers.dart';
import '../decision/purpose.dart';
import '../decision/recommendation.dart';
import '../decision/risk_scorer.dart';
import '../decision/rules_table.dart';
import '../scanner/models/bounding_box.dart';
import '../scanner/scanner_providers.dart';
import 'models/review_state.dart';

class ReviewNotifier extends Notifier<ReviewState> {
  @override
  ReviewState build() {
    final findingsAsync = ref.watch(scanFindingsProvider);
    final purpose = ref.watch(selectedPurposeProvider) ?? Purpose.paymentProof;
    final audience = ref.watch(selectedAudienceProvider);

    final List<FindingReviewItem> initialItems = [];

    findingsAsync.whenData((findings) {
      final recs = generateRecommendations(findings, purpose, audience);
      for (final r in recs) {
        // Defaults come from Decision Engine: KEEP defaults to keep, others default to their respective redaction action
        final initialAction = r.action.isKeep ? RedactionAction.keep : r.action;
        initialItems.add(
          FindingReviewItem(
            finding: r.finding,
            currentAction: initialAction,
            defaultAction: r.action,
            reason: r.reason,
          ),
        );
      }
    });

    return ReviewState(findings: initialItems);
  }

  void setImageDimensions(double width, double height) {
    if (state.imageWidth != width || state.imageHeight != height) {
      state = state.copyWith(imageWidth: width, imageHeight: height);
    }
  }

  /// Toggles a finding between its redaction action and KEEP
  void toggleFinding(int index) {
    if (index < 0 || index >= state.findings.length) return;

    final updated = List<FindingReviewItem>.from(state.findings);
    final current = updated[index];
    final nextAction = current.currentAction.isKeep
        ? (current.defaultAction.isKeep ? RedactionAction.hide : current.defaultAction)
        : RedactionAction.keep;

    updated[index] = current.copyWith(currentAction: nextAction);
    state = state.copyWith(findings: updated);
  }

  /// Adds a manual redaction rectangle in image pixels
  void addManualBox(BoundingBox box) {
    if (box.width < 5 || box.height < 5) return;
    state = state.copyWith(
      manualBoxes: [...state.manualBoxes, box],
    );
  }

  /// Removes the most recently added manual box
  void undoManualBox() {
    if (state.manualBoxes.isEmpty) return;
    final updated = List<BoundingBox>.from(state.manualBoxes)..removeLast();
    state = state.copyWith(manualBoxes: updated);
  }

  /// Deletes a specific manual box by index
  void deleteManualBox(int index) {
    if (index < 0 || index >= state.manualBoxes.length) return;
    final updated = List<BoundingBox>.from(state.manualBoxes)..removeAt(index);
    state = state.copyWith(manualBoxes: updated);
  }

  void clearManualBoxes() {
    state = state.copyWith(manualBoxes: const []);
  }
}

final reviewNotifierProvider =
    NotifierProvider<ReviewNotifier, ReviewState>(ReviewNotifier.new);

/// Derived provider delivering the final set of regions to redact
/// in original image-pixel coordinates, directly consumable by RedactionService.
final finalRedactionRegionsProvider = Provider<List<RedactionRegion>>((ref) {
  final reviewState = ref.watch(reviewNotifierProvider);
  return reviewState.getFinalRedactionRegions();
});

/// Live recalculated exposure score based on active user toggle state.
/// KEPT findings that are sensitive contribute exposure risk points.
/// REDACTED findings (hidden or blurred) contribute 0 residual risk points.
final liveExposureScoreProvider = Provider<RiskScoreResult>((ref) {
  final reviewState = ref.watch(reviewNotifierProvider);
  final scorer = ref.watch(riskScorerProvider);
  final purpose = ref.watch(selectedPurposeProvider) ?? Purpose.paymentProof;
  final audience = ref.watch(selectedAudienceProvider);

  if (reviewState.findings.isEmpty) {
    return const RiskScoreResult.zero();
  }

  // Active findings kept by user
  final List<RiskScoreItem> scoreItems = [];
  int runningTotal = 0;

  for (final item in reviewState.findings) {
    final type = item.finding.type;
    final isKept = item.currentAction.isKeep;

    if (isKept) {
      // Kept finding: check if it exposes sensitive data according to the scorer
      final itemScore = scorer.calculateScore([item.finding], purpose, audience);
      final pts = itemScore.totalScore;
      runningTotal += pts;

      scoreItems.add(
        RiskScoreItem(
          finding: item.finding,
          type: type,
          action: RedactionAction.keep,
          points: pts,
          explanation: pts > 0
              ? 'Unredacted exposure (+$pts pts): ${item.reason}'
              : 'Kept (+0 pts): ${item.reason}',
        ),
      );
    } else {
      // Redacted item: contributes 0 residual exposure points
      scoreItems.add(
        RiskScoreItem(
          finding: item.finding,
          type: type,
          action: item.currentAction,
          points: 0,
          explanation: 'Redacted (0 pts residual exposure): ${item.reason}',
        ),
      );
    }
  }

  return RiskScoreResult(
    totalScore: runningTotal.clamp(0, 100),
    uncappedScore: runningTotal,
    items: scoreItems,
    isResidual: true,
  );
});

/// Initial detected exposure score of the original unedited image
final initialDetectedScoreProvider = Provider<RiskScoreResult>((ref) {
  final findingsAsync = ref.watch(scanFindingsProvider);
  final purpose = ref.watch(selectedPurposeProvider) ?? Purpose.paymentProof;
  final audience = ref.watch(selectedAudienceProvider);
  final scorer = ref.watch(riskScorerProvider);

  return findingsAsync.maybeWhen(
    data: (findings) => scorer.calculateScore(findings, purpose, audience),
    orElse: () => const RiskScoreResult.zero(),
  );
});
