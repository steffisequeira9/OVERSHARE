import 'package:flutter/foundation.dart';
import '../scanner/models/finding.dart';
import '../scanner/models/sensitive_type.dart';
import 'purpose.dart';
import 'rules_table.dart';

@immutable
class Recommendation {
  final Finding finding;
  final RedactionAction action;
  final String reason;

  const Recommendation({
    required this.finding,
    required this.action,
    required this.reason,
  });

  factory Recommendation.fromFinding(
    Finding finding,
    Purpose purpose, [
    Audience audience = Audience.privateAudience,
  ]) {
    final decision = RulesTable.getDecision(finding.type, purpose, audience);

    // Low-confidence demotion logic: if confidence < 0.70, demote to OPTIONAL with notice.
    // Findings like personName are heuristic (confidence 0.45) by design; if the purpose
    // explicitly designated KEEP, respect the purpose rule and preserve it.
    if (finding.confidence < 0.70 && !decision.action.isOptional) {
      if (!(decision.action.isKeep && finding.type == SensitiveType.personName)) {
        return Recommendation(
          finding: finding,
          action: RedactionAction.optional,
          reason: 'Low confidence detection; please check if sensitive. (${decision.reason})',
        );
      }
    }

    return Recommendation(
      finding: finding,
      action: decision.action,
      reason: decision.reason,
    );
  }

  Recommendation copyWith({
    Finding? finding,
    RedactionAction? action,
    String? reason,
  }) {
    return Recommendation(
      finding: finding ?? this.finding,
      action: action ?? this.action,
      reason: reason ?? this.reason,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Recommendation &&
          runtimeType == other.runtimeType &&
          finding == other.finding &&
          action == other.action &&
          reason == other.reason;

  @override
  int get hashCode => Object.hash(finding, action, reason);

  @override
  String toString() =>
      'Recommendation(${finding.type.displayName}, action: ${action.label}, reason: "$reason")';
}

List<Recommendation> generateRecommendations(
  List<Finding> findings,
  Purpose purpose, [
  Audience audience = Audience.privateAudience,
]) {
  return findings.map((f) => Recommendation.fromFinding(f, purpose, audience)).toList();
}
