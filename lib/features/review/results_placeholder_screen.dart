import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_state.dart';
import '../../core/purpose.dart';

enum RecommendationTag {
  keep(
    label: 'KEEP',
    color: Color(0xFF10B981),
    backgroundColor: Color(0xFFE8F5E9),
    icon: Icons.check_circle_outline_rounded,
  ),
  hide(
    label: 'HIDE',
    color: Color(0xFFEF4444),
    backgroundColor: Color(0xFFFEE2E2),
    icon: Icons.visibility_off_outlined,
  ),
  optional(
    label: 'OPTIONAL',
    color: Color(0xFFF59E0B),
    backgroundColor: Color(0xFFFEF3C7),
    icon: Icons.help_outline_rounded,
  );

  const RecommendationTag({
    required this.label,
    required this.color,
    required this.backgroundColor,
    required this.icon,
  });

  final String label;
  final Color color;
  final Color backgroundColor;
  final IconData icon;
}

class FakeFinding {
  final String title;
  final String matchedText;
  final RecommendationTag tag;
  final String reason;
  final int points;

  const FakeFinding({
    required this.title,
    required this.matchedText,
    required this.tag,
    required this.reason,
    required this.points,
  });
}

class ResultsPlaceholderScreen extends ConsumerWidget {
  const ResultsPlaceholderScreen({super.key});

  static const List<FakeFinding> _placeholderFindings = [
    FakeFinding(
      title: 'Bank Account Number',
      matchedText: '•••• •••• 4589',
      tag: RecommendationTag.hide,
      reason: 'Unnecessary for payment proof; high risk for account probing.',
      points: 35,
    ),
    FakeFinding(
      title: 'Phone / UPI ID',
      matchedText: '9876543210@oksbi',
      tag: RecommendationTag.hide,
      reason: 'Exposes private direct contact detail.',
      points: 25,
    ),
    FakeFinding(
      title: 'Payer Full Name',
      matchedText: 'Steffi Sequeira',
      tag: RecommendationTag.optional,
      reason: 'Keep if the recipient explicitly needs to confirm sender identity.',
      points: 12,
    ),
    FakeFinding(
      title: 'Transaction / UTR ID',
      matchedText: 'UTR32918840192',
      tag: RecommendationTag.keep,
      reason: 'Essential reference required for payment verification.',
      points: 0,
    ),
    FakeFinding(
      title: 'Amount',
      matchedText: '₹2,450.00',
      tag: RecommendationTag.keep,
      reason: 'Core detail necessary to confirm payment amount.',
      points: 0,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final purpose = ref.watch(selectedPurposeProvider) ?? SharingPurpose.paymentProof;
    final isDark = theme.brightness == Brightness.dark;

    const sampleRiskScore = 72; // Sample placeholder score out of 100

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Results'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          children: [
            // Purpose badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(purpose.icon, size: 18, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Purpose: ${purpose.label}',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Risk Score Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Privacy Exposure Score',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Quantifies sensitive data volume & exposure level (not a probability of harm).',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                '$sampleRiskScore',
                                style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                              Text(
                                '/100',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFFEF4444),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: sampleRiskScore / 100,
                        minHeight: 8,
                        backgroundColor: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFE2E8F0),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Color(0xFFEF4444),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'High Exposure: Contains 2 identifiers recommended to hide.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFEF4444),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Detected Findings (Demo)',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '${_placeholderFindings.length} items',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Findings list
            ..._placeholderFindings.map((finding) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? finding.tag.color.withValues(alpha: 0.2)
                                    : finding.tag.backgroundColor,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    finding.tag.icon,
                                    size: 14,
                                    color: finding.tag.color,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    finding.tag.label,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      color: finding.tag.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Spacer(),
                            if (finding.points > 0)
                              Text(
                                '+${finding.points} pts',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  color: theme.colorScheme.error,
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          finding.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          finding.matchedText,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          finding.reason,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Stage 2 UI Shell ready! Real OCR & Review will be enabled in later stages.',
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.tune_rounded),
              label: const Text('Review & Redact (Stage 5)'),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () {
                // Clear selection and go back to home
                ref.read(selectedImageProvider.notifier).clear();
                ref.read(selectedPurposeProvider.notifier).clear();
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
              child: const Text('Start Over'),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
