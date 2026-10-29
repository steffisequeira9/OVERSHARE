import 'dart:math' as math;
import '../scanner/models/finding.dart';
import '../scanner/models/sensitive_type.dart';
import 'purpose.dart';
import 'recommendation.dart';
import 'rules_table.dart';

class RiskScoreItem {
  final Finding finding;
  final SensitiveType type;
  final RedactionAction action;
  final int points;
  final String explanation;

  const RiskScoreItem({
    required this.finding,
    required this.type,
    required this.action,
    required this.points,
    required this.explanation,
  });
}

class RiskScoreResult {
  final int totalScore; // 0 - 100
  final int uncappedScore;
  final List<RiskScoreItem> items;
  final bool isResidual;

  const RiskScoreResult({
    required this.totalScore,
    required this.uncappedScore,
    required this.items,
    this.isResidual = false,
  });

  const RiskScoreResult.zero()
      : totalScore = 0,
        uncappedScore = 0,
        items = const [],
        isResidual = false;

  bool get isEmpty => items.isEmpty;
  bool get hasFindings => items.isNotEmpty;

  String get exposureLevel {
    if (totalScore == 0) {
      if (isResidual && hasFindings) {
        return 'Protected (0/100)';
      }
      return 'No Exposure';
    }
    if (totalScore <= 30) return 'Low Exposure';
    if (totalScore <= 60) return 'Moderate Exposure';
    if (totalScore <= 85) return 'High Exposure';
    return 'Critical Exposure';
  }

  String get exposureDescription {
    if (totalScore == 0) {
      if (isResidual && hasFindings) {
        return 'All detected sensitive elements are shielded from view.';
      }
      return 'No sensitive data detected for this sharing purpose.';
    }
    if (totalScore <= 30) {
      return 'Minimal sensitive exposure; minor optional details detected.';
    }
    if (totalScore <= 60) {
      return 'Moderate exposure; contains contact or identifiable data that should be redacted.';
    }
    if (totalScore <= 85) {
      return 'High exposure; exposes financial or personal identifiers not needed by recipient.';
    }
    return 'Critical exposure; contains highly sensitive credentials or national identity numbers.';
  }
}

class RiskScorer {
  const RiskScorer();

  // Heuristic sensitivity weights
  static const Map<SensitiveType, int> _baseWeights = {
    SensitiveType.credential: 40,
    SensitiveType.card: 35,
    SensitiveType.aadhaar: 30,
    SensitiveType.voterId: 30,
    SensitiveType.pan: 25,
    SensitiveType.accountNumber: 25,
    SensitiveType.face: 25,
    SensitiveType.dob: 20,
    SensitiveType.senderUpiId: 20,
    SensitiveType.phone: 20,
    SensitiveType.upiId: 20,
    SensitiveType.recipientUpiId: 15,
    SensitiveType.email: 15,
    SensitiveType.transactionId: 15,
    SensitiveType.personName: 15,
    SensitiveType.amount: 10,
    SensitiveType.ifsc: 10,
    SensitiveType.dateTime: 10,
    SensitiveType.url: 10,
  };

  /// Calculates an explainable heuristic privacy exposure score (0-100) based on recommendations.
  /// Only findings marked HIDE, BLUR/COVER FACE, or OPTIONAL contribute to the score.
  /// Findings marked KEEP contribute 0 points.
  RiskScoreResult calculateScore(
    List<Finding> findings,
    Purpose purpose, [
    Audience audience = Audience.privateAudience,
  ]) {
    if (findings.isEmpty) {
      return const RiskScoreResult.zero();
    }

    final recommendations = generateRecommendations(findings, purpose, audience);
    final List<RiskScoreItem> scoreItems = [];
    final Map<SensitiveType, int> countPerType = {};
    int runningTotal = 0;

    final audienceMultiplier = audience == Audience.publicAudience ? 1.25 : 1.0;

    for (final rec in recommendations) {
      final type = rec.finding.type;
      final action = rec.action;
      final baseWeight = _baseWeights[type] ?? 10;

      countPerType[type] = (countPerType[type] ?? 0) + 1;
      final count = countPerType[type]!;
      // Multi-instance diminishing return (1st full, 2nd 70%, 3rd+ 40%)
      final repetitionMultiplier = count == 1
          ? 1.0
          : count == 2
              ? 0.70
              : 0.40;

      if (action.isKeep) {
        // Findings legitimately kept for the selected purpose add 0 exposure points
        scoreItems.add(
          RiskScoreItem(
            finding: rec.finding,
            type: type,
            action: action,
            points: 0,
            explanation: 'Required or legitimate for ${purpose.label} (+0 pts). ${rec.reason}',
          ),
        );
      } else {
        final actionFactor = action.isOptional ? 0.50 : 1.0;
        final rawPoints = baseWeight *
            actionFactor *
            repetitionMultiplier *
            rec.finding.confidence *
            audienceMultiplier;
        final itemPoints = math.max(1, rawPoints.round());

        runningTotal += itemPoints;

        final roleDesc = action.isOptional
            ? 'Optional detail (+$itemPoints pts): ${rec.reason}'
            : 'Unredacted sensitive exposure (+$itemPoints pts): ${rec.reason}';

        scoreItems.add(
          RiskScoreItem(
            finding: rec.finding,
            type: type,
            action: action,
            points: itemPoints,
            explanation: roleDesc,
          ),
        );
      }
    }

    final cappedScore = math.min(100, runningTotal);

    return RiskScoreResult(
      totalScore: cappedScore,
      uncappedScore: runningTotal,
      items: scoreItems,
      isResidual: false,
    );
  }
}
