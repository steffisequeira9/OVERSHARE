import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_state.dart';
import '../decision/decision_providers.dart';
import '../decision/purpose.dart';
import '../decision/rules_table.dart';
import '../scanner/scanner_providers.dart';
import 'review_screen.dart';

class ResultsScreen extends ConsumerWidget {
  const ResultsScreen({super.key});

  Color _actionColor(RedactionAction action) {
    switch (action) {
      case RedactionAction.keep:
        return const Color(0xFF10B981);
      case RedactionAction.hide:
      case RedactionAction.coverFace:
        return const Color(0xFFEF4444);
      case RedactionAction.blurFace:
        return const Color(0xFF8B5CF6);
      case RedactionAction.optional:
        return const Color(0xFFF59E0B);
    }
  }

  Color _actionBgColor(RedactionAction action, bool isDark) {
    if (isDark) {
      return _actionColor(action).withValues(alpha: 0.2);
    }
    switch (action) {
      case RedactionAction.keep:
        return const Color(0xFFE8F5E9);
      case RedactionAction.hide:
      case RedactionAction.coverFace:
        return const Color(0xFFFEE2E2);
      case RedactionAction.blurFace:
        return const Color(0xFFEDE9FE);
      case RedactionAction.optional:
        return const Color(0xFFFEF3C7);
    }
  }

  IconData _actionIcon(RedactionAction action) {
    switch (action) {
      case RedactionAction.keep:
        return Icons.check_circle_outline_rounded;
      case RedactionAction.hide:
      case RedactionAction.coverFace:
        return Icons.visibility_off_outlined;
      case RedactionAction.blurFace:
        return Icons.blur_on_rounded;
      case RedactionAction.optional:
        return Icons.help_outline_rounded;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final currentPurpose =
        ref.watch(selectedPurposeProvider) ?? Purpose.paymentProof;
    final scanState = ref.watch(scanFindingsProvider);
    final recommendations = ref.watch(recommendationsProvider);
    final scoreResult = ref.watch(riskScoreResultProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Analysis Results'),
      ),
      body: SafeArea(
        child: scanState.when(
          loading: () => Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 3),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Scanning Screenshot...',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Extracting text & matching sensitive patterns on-device',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          error: (err, _) => Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.error_outline_rounded,
                      size: 56,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Detection Incomplete',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    err.toString(),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(height: 1.4),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => ref.refresh(scanFindingsProvider),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Retry Scan'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ReviewScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.edit_note_rounded),
                    label: const Text('Continue to Manual Redaction'),
                  ),
                ],
              ),
            ),
          ),
          data: (findings) {
            final scoreColor = scoreResult.totalScore > 50
                ? const Color(0xFFEF4444)
                : scoreResult.totalScore > 20
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF10B981);

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              children: [
                // Web Limited Mode Notice
                if (kIsWeb)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline_rounded,
                          color: Color(0xFFF59E0B),
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Web Mode: Client-side in-browser OCR is powered by Tesseract.js. Face detection is mobile-only; use Review & Redact for manual face redaction.',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Purpose Switcher Banner
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
                    child: Row(
                      children: [
                        Icon(currentPurpose.icon, size: 20, color: theme.colorScheme.primary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Active Purpose',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                              ),
                              Text(
                                currentPurpose.label,
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<Purpose>(
                          tooltip: 'Change sharing purpose',
                          icon: const Icon(Icons.tune_rounded, size: 20),
                          onSelected: (newPurpose) {
                            ref
                                .read(selectedPurposeProvider.notifier)
                                .setPurpose(newPurpose);
                          },
                          itemBuilder: (context) {
                            return Purpose.values.map((p) {
                              final isSelected = p == currentPurpose;
                              return PopupMenuItem(
                                value: p,
                                child: Row(
                                  children: [
                                    Icon(
                                      p.icon,
                                      size: 18,
                                      color: isSelected
                                          ? theme.colorScheme.primary
                                          : theme.iconTheme.color,
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      p.label,
                                      style: TextStyle(
                                        fontWeight:
                                            isSelected ? FontWeight.w700 : FontWeight.w500,
                                        color: isSelected ? theme.colorScheme.primary : null,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Privacy Exposure Score Card
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
                                    'Quantifies visible private data volume & sensitivity (exposure score, not a probability of harm).',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: theme.textTheme.bodySmall?.color,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: scoreColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TweenAnimationBuilder<double>(
                                    tween: Tween<double>(
                                      begin: 0,
                                      end: scoreResult.totalScore.toDouble(),
                                    ),
                                    duration: const Duration(milliseconds: 800),
                                    curve: Curves.easeOutCubic,
                                    builder: (context, val, child) {
                                      return Text(
                                        '${val.round()}',
                                        style: TextStyle(
                                          fontSize: 26,
                                          fontWeight: FontWeight.w900,
                                          color: scoreColor,
                                        ),
                                      );
                                    },
                                  ),
                                  Text(
                                    '/100',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: scoreColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        TweenAnimationBuilder<double>(
                          tween: Tween<double>(
                            begin: 0,
                            end: scoreResult.totalScore / 100,
                          ),
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeOutCubic,
                          builder: (context, val, child) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: val,
                                minHeight: 8,
                                backgroundColor: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFE2E8F0),
                                valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: scoreColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              scoreResult.exposureLevel,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: scoreColor,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${recommendations.where((r) => r.action.isHide).length} HIDE  •  ${recommendations.where((r) => r.action.isOptional).length} OPTIONAL',
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          scoreResult.exposureDescription,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),

                        // Expandable Itemized Score Breakdown
                        if (scoreResult.items.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Theme(
                            data: theme.copyWith(dividerColor: Colors.transparent),
                            child: ExpansionTile(
                              tilePadding: EdgeInsets.zero,
                              childrenPadding: const EdgeInsets.only(top: 8),
                              title: const Text(
                                'View Score Breakdown',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              subtitle: Text(
                                'See exactly which findings contributed to this score',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: theme.textTheme.bodySmall?.color,
                                ),
                              ),
                              children: scoreResult.items.map((item) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHighest
                                        .withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: _actionBgColor(item.action, isDark),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          item.action.label,
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w800,
                                            color: _actionColor(item.action),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.type.displayName,
                                              style: const TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            Text(
                                              item.explanation,
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: theme.textTheme.bodySmall?.color,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '+${item.points} pts',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: item.points > 0
                                              ? scoreColor
                                              : const Color(0xFF10B981),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Recommendations Section Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Privacy Recommendations',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      '${recommendations.length} items',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (recommendations.isEmpty)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 48,
                            color: Color(0xFF10B981),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No Sensitive Patterns Found',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '0 sensitive patterns detected from image text. If this image contains sensitive details that were not recognized by OCR, you can manually redact them in Review & Redact.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ...recommendations.map((rec) {
                    final finding = rec.finding;
                    final action = rec.action;
                    final color = _actionColor(action);
                    final bgColor = _actionBgColor(action, isDark);
                    final icon = _actionIcon(action);

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
                                      color: bgColor,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(icon, size: 14, color: color),
                                        const SizedBox(width: 4),
                                        Text(
                                          action.label,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                            color: color,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surfaceContainerHighest
                                          .withValues(alpha: 0.5),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'box: ${finding.boundingBox.width.toStringAsFixed(0)}x${finding.boundingBox.height.toStringAsFixed(0)}',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.textTheme.bodySmall?.color,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                finding.type.displayName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                finding.maskedPreview,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.primary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                rec.reason,
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
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ReviewScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.tune_rounded),
                  label: const Text('Review & Redact'),
                ),
                const SizedBox(height: 10),
                OutlinedButton(
                  onPressed: () {
                    ref.read(selectedImageProvider.notifier).clear();
                    ref.read(selectedPurposeProvider.notifier).clear();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  child: const Text('Start Over'),
                ),
                const SizedBox(height: 24),
              ],
            );
          },
        ),
      ),
    );
  }
}
