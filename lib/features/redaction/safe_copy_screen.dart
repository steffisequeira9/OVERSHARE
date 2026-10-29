import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_state.dart';
import '../history/history_providers.dart';
import '../history/models/finding_record.dart';
import '../history/models/redaction_record.dart';
import '../history/models/scan_record.dart';
import '../review/before_after_screen.dart';
import '../review/review_notifier.dart';
import 'redaction_providers.dart';
import 'redaction_service.dart';

class SafeCopyScreen extends ConsumerWidget {
  const SafeCopyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final selectedImage = ref.watch(selectedImageProvider);
    final regions = ref.watch(finalRedactionRegionsProvider);
    final selectedStyle = ref.watch(selectedRedactionStyleProvider);
    final metadataAsync = ref.watch(originalMetadataProvider);
    final exportState = ref.watch(sanitizedExportNotifierProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Safe Copy'),
      ),
      body: SafeArea(
        child: exportState.exportResult != null
            ? _buildSuccessView(context, ref, exportState)
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Header Status Banner
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.security_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${regions.length} Region${regions.length == 1 ? '' : 's'} to Redact',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Permanent pixel mutation into file buffer. No removable overlay layers.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.textTheme.bodySmall?.color,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Section 1: Redaction Style Choice
                    Text(
                      'Redaction Style',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: RedactionStyle.values.map((style) {
                        final isSelected = style == selectedStyle;
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: style == RedactionStyle.solidFill ? 8.0 : 0,
                              left: style == RedactionStyle.pixelate ? 8.0 : 0,
                            ),
                            child: InkWell(
                              onTap: () => ref
                                  .read(selectedRedactionStyleProvider.notifier)
                                  .setStyle(style),
                              borderRadius: BorderRadius.circular(14),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? theme.colorScheme.primary.withValues(alpha: 0.1)
                                      : theme.cardTheme.color,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isSelected
                                        ? theme.colorScheme.primary
                                        : theme.dividerColor.withValues(alpha: 0.3),
                                    width: isSelected ? 2 : 1,
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          style == RedactionStyle.solidFill
                                              ? Icons.format_paint_rounded
                                              : Icons.blur_on_rounded,
                                          color: isSelected
                                              ? theme.colorScheme.primary
                                              : theme.iconTheme.color,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            style.label,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: isSelected
                                                  ? theme.colorScheme.primary
                                                  : null,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      style.description,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: theme.textTheme.bodySmall?.color,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),

                    // Section 2: Metadata Stripping Summary
                    Text(
                      'Metadata Clean Check',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'EXIF & Hardware Metadata Removal',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.textTheme.bodySmall?.color,
                      ),
                    ),
                    const SizedBox(height: 10),
                    metadataAsync.when(
                      data: (items) {
                        if (items.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: theme.cardTheme.color,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: theme.dividerColor.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.check_circle_rounded,
                                  size: 18,
                                  color: Color(0xFF10B981),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'No EXIF or location tags detected in original image (e.g. screenshot or pre-stripped). Fresh PNG export will ensure zero metadata is stored.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: theme.textTheme.bodySmall?.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }
                        return Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: theme.dividerColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (final item in items) ...[
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.check_circle_outline_rounded,
                                        size: 16,
                                        color: Color(0xFF10B981),
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        item.category,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '(${item.value})',
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: theme.textTheme.bodySmall?.color,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'WILL STRIP',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w800,
                                            color: Color(0xFFEF4444),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (_, _) => const Text('Unable to read metadata'),
                    ),
                    const SizedBox(height: 32),

                    // Export Error message if any
                    if (exportState.error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          'Export error: ${exportState.error}',
                          style: const TextStyle(color: Color(0xFFEF4444)),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Action Button: Export
                    ElevatedButton.icon(
                      onPressed: exportState.isProcessing
                          ? null
                          : () async {
                              if (selectedImage == null) return;
                              final bytes = await selectedImage.readAsBytes();
                              await ref
                                  .read(sanitizedExportNotifierProvider.notifier)
                                  .exportImage(
                                    originalBytes: bytes,
                                    regions: regions,
                                    style: selectedStyle,
                                  );

                              final updatedState = ref.read(sanitizedExportNotifierProvider);
                              if (updatedState.exportResult != null) {
                                final purpose = ref.read(selectedPurposeProvider)?.label ?? 'General Proof';
                                final audience = ref.read(selectedAudienceProvider).label;
                                final initialScore = ref.read(liveExposureScoreProvider).totalScore;
                                final residualScore = updatedState.residualScoreResult?.totalScore ?? 0;
                                final reviewState = ref.read(reviewNotifierProvider);

                                final scanRecord = ScanRecord(
                                  createdAt: DateTime.now(),
                                  purpose: purpose,
                                  audience: audience,
                                  originalScore: initialScore,
                                  sanitizedScore: residualScore,
                                  status: 'completed',
                                  verificationStatus: residualScore == 0 ? 'verified' : 'residual_detected',
                                );

                                final findingRecords = reviewState.findings.map((f) {
                                  return FindingRecord(
                                    scanId: 0,
                                    type: f.finding.type.displayName,
                                    maskedPreview: f.finding.maskedPreview,
                                    x: f.finding.boundingBox.left,
                                    y: f.finding.boundingBox.top,
                                    w: f.finding.boundingBox.width,
                                    h: f.finding.boundingBox.height,
                                    confidence: f.finding.confidence,
                                    recommendation: f.defaultAction.label,
                                    reason: f.reason,
                                    userAction: f.currentAction.label,
                                    source: f.finding.source.name,
                                  );
                                }).toList();

                                final redactionRecords = regions.map((r) {
                                  return RedactionRecord(
                                    scanId: 0,
                                    style: selectedStyle.name,
                                    applied: true,
                                    verified: true,
                                  );
                                }).toList();

                                await ref.read(historyNotifierProvider.notifier).addScan(
                                  scan: scanRecord,
                                  findings: findingRecords,
                                  redactions: redactionRecords,
                                  advice: const [],
                                );
                              }
                            },
                      icon: exportState.isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.lock_rounded),
                      label: Text(
                        exportState.isProcessing
                            ? 'Burning Redactions & Verifying...'
                            : 'Generate & Export Safe Copy',
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSuccessView(
    BuildContext context,
    WidgetRef ref,
    SanitizedExportState state,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final result = state.exportResult!;
    final residualResult = state.residualScoreResult;
    final residualScore = residualResult?.totalScore ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 42,
                color: Color(0xFF10B981),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Sanitized Copy Created',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            state.isMetadataStrippedVerified
                ? 'Pixels burned permanently into file data. EXIF metadata verified stripped.'
                : 'Pixels burned permanently into file data.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 20),

          // Residual Exposure Report
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: residualScore == 0
                  ? const Color(0xFF10B981).withValues(alpha: 0.1)
                  : const Color(0xFFF59E0B).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: residualScore == 0
                    ? const Color(0xFF10B981).withValues(alpha: 0.3)
                    : const Color(0xFFF59E0B).withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      residualScore == 0
                          ? Icons.verified_user_rounded
                          : Icons.warning_amber_rounded,
                      color: residualScore == 0
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Post-Export Residual Verification',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Re-scan of sanitized image yielded a residual exposure score of $residualScore/100 (${state.residualFindings.length} detected token${state.residualFindings.length == 1 ? '' : 's'}).',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      state.isMetadataStrippedVerified
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      size: 14,
                      color: state.isMetadataStrippedVerified
                          ? const Color(0xFF10B981)
                          : const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      state.isMetadataStrippedVerified
                          ? 'EXIF Status: Verified Clean (0 tags remaining)'
                          : 'EXIF Status: Verification inconclusive',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: state.isMetadataStrippedVerified
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B),
                      ),
                    ),
                  ],
                ),
                if (state.residualFindings.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Residual findings detected: ${state.residualFindings.map((f) => f.type.displayName).toSet().join(', ')}',
                    style: TextStyle(
                      fontSize: 11,
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Redacted Image Preview
          if (state.sanitizedBytes != null)
            Container(
              height: 220,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: theme.dividerColor.withValues(alpha: 0.3),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Center(
                child: Image.memory(
                  state.sanitizedBytes!,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          const SizedBox(height: 16),

          // File Info Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.file_present_rounded, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          result.fileName,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        result.formattedSize,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Text(
                    kIsWeb
                        ? 'Download destination: ${result.filePath}'
                        : 'Saved at: ${result.filePath}',
                    style: TextStyle(
                      fontSize: 11,
                      fontFamily: 'monospace',
                      color: theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Save to Device Gallery button / Web Download
          FilledButton.icon(
            onPressed: () async {
              final ok = await ref
                  .read(sanitizedExportNotifierProvider.notifier)
                  .saveToDeviceGallery();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ok
                        ? (kIsWeb
                            ? 'Downloaded safe copy to browser!'
                            : 'Saved to device photo gallery!')
                        : 'Could not complete save operation.'),
                    backgroundColor:
                        ok ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  ),
                );
              }
            },
            icon: Icon(kIsWeb
                ? Icons.download_rounded
                : (state.isSavedToGallery
                    ? Icons.check_circle_outline
                    : Icons.photo_library_rounded)),
            label: Text(kIsWeb
                ? 'Download Safe Copy Again'
                : (state.isSavedToGallery
                    ? 'Saved to Photo Gallery'
                    : 'Save to Device Gallery')),
          ),
          const SizedBox(height: 10),

          // Compare Before & After
          ElevatedButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BeforeAfterScreen(),
                ),
              );
            },
            icon: const Icon(Icons.compare_arrows_rounded),
            label: const Text('Compare Before & After'),
          ),
          const SizedBox(height: 10),

          // Share / Copy Path Button
          FilledButton.tonalIcon(
            onPressed: () {
              final textToCopy = kIsWeb ? result.fileName : result.filePath;
              Clipboard.setData(ClipboardData(text: textToCopy));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(kIsWeb
                      ? 'File name copied: $textToCopy'
                      : 'File path copied: $textToCopy'),
                  backgroundColor: const Color(0xFF10B981),
                ),
              );
            },
            icon: Icon(kIsWeb ? Icons.copy_rounded : Icons.share_rounded),
            label: Text(kIsWeb ? 'Copy File Name' : 'Copy File Path'),
          ),
          const SizedBox(height: 10),

          // Done & Return Home
          OutlinedButton(
            onPressed: () {
              ref.read(sanitizedExportNotifierProvider.notifier).reset();
              ref.read(selectedImageProvider.notifier).clear();
              ref.read(selectedPurposeProvider.notifier).clear();
              ref.read(reviewNotifierProvider.notifier).clearManualBoxes();
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
            child: const Text('Done • Start New Scan'),
          ),
        ],
      ),
    );
  }
}
