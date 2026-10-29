import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_state.dart';
import '../scanner/scanner_providers.dart';
import 'purpose.dart';
import 'recommendation.dart';
import 'risk_scorer.dart';

final riskScorerProvider = Provider<RiskScorer>((ref) {
  return const RiskScorer();
});

final recommendationsProvider = Provider<List<Recommendation>>((ref) {
  final findingsAsync = ref.watch(scanFindingsProvider);
  final purpose = ref.watch(selectedPurposeProvider) ?? Purpose.paymentProof;
  final audience = ref.watch(selectedAudienceProvider);

  return findingsAsync.maybeWhen(
    data: (findings) => generateRecommendations(findings, purpose, audience),
    orElse: () => [],
  );
});

final riskScoreResultProvider = Provider<RiskScoreResult>((ref) {
  final findingsAsync = ref.watch(scanFindingsProvider);
  final purpose = ref.watch(selectedPurposeProvider) ?? Purpose.paymentProof;
  final audience = ref.watch(selectedAudienceProvider);
  final scorer = ref.watch(riskScorerProvider);

  return findingsAsync.maybeWhen(
    data: (findings) => scorer.calculateScore(findings, purpose, audience),
    orElse: () => const RiskScoreResult.zero(),
  );
});
