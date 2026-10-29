import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_state.dart';
import '../decision/purpose.dart';
import '../history/history_screen.dart';
import '../redaction/redaction_providers.dart';
import 'review_notifier.dart';

enum ComparisonMode { slider, sideBySide, toggle }

class BeforeAfterScreen extends ConsumerStatefulWidget {
  const BeforeAfterScreen({super.key});

  @override
  ConsumerState<BeforeAfterScreen> createState() => _BeforeAfterScreenState();
}

class _BeforeAfterScreenState extends ConsumerState<BeforeAfterScreen> {
  double _sliderPosition = 0.5; // 0.0 to 1.0 for draggable split
  ComparisonMode _mode = ComparisonMode.slider;
  bool _showingOriginalInToggle = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedImage = ref.watch(selectedImageProvider);
    final purpose = ref.watch(selectedPurposeProvider) ?? Purpose.paymentProof;
    final exportState = ref.watch(sanitizedExportNotifierProvider);
    final reviewState = ref.watch(reviewNotifierProvider);
    final scoreResult = ref.watch(liveExposureScoreProvider);

    final sanitizedBytes = exportState.sanitizedBytes;
    final originalPath = selectedImage?.path;

    // Filter redacted items (hide, blurFace, coverFace)
    final hiddenItems = reviewState.findings
        .where((f) => !f.currentAction.isKeep)
        .toList();
    final manualBoxes = reviewState.manualBoxes;

    final initialScore = scoreResult.totalScore;
    final finalScore = exportState.residualScoreResult?.totalScore ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Before & After Comparison'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'View Scan History',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header: Purpose & Privacy Transformation Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark
                        ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                        : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            purpose.label,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const Spacer(),
                        const Icon(
                          Icons.verified_user_rounded,
                          color: Color(0xFF10B981),
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        const Text(
                          'Redaction Applied',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF10B981),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Score Comparison Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // Before Score
                        _buildScoreBadge(
                          title: 'Original Exposure',
                          score: initialScore,
                          color: _scoreColor(initialScore),
                          label: initialScore > 50 ? 'High Risk' : 'Moderate',
                        ),
                        const Icon(
                          Icons.arrow_forward_rounded,
                          size: 28,
                          color: Colors.grey,
                        ),
                        // After Score
                        _buildScoreBadge(
                          title: 'Sanitized Exposure',
                          score: finalScore,
                          color: const Color(0xFF10B981),
                          label: 'Safe to Share',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // View Mode Selector
              SegmentedButton<ComparisonMode>(
                segments: const [
                  ButtonSegment(
                    value: ComparisonMode.slider,
                    icon: Icon(Icons.compare_arrows_rounded),
                    label: Text('Slider'),
                  ),
                  ButtonSegment(
                    value: ComparisonMode.sideBySide,
                    icon: Icon(Icons.view_agenda_outlined),
                    label: Text('Side by Side'),
                  ),
                  ButtonSegment(
                    value: ComparisonMode.toggle,
                    icon: Icon(Icons.flip_rounded),
                    label: Text('Tap to Flip'),
                  ),
                ],
                selected: {_mode},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _mode = newSelection.first;
                  });
                },
              ),
              const SizedBox(height: 14),

              // Interactive Image Comparison Area
              if (originalPath != null && sanitizedBytes != null)
                _buildComparisonView(originalPath, sanitizedBytes, theme)
              else
                Container(
                  height: 200,
                  alignment: Alignment.center,
                  child: const Text('Image preview unavailable'),
                ),
              const SizedBox(height: 20),

              // What Was Hidden & Why Section
              Text(
                'What Was Hidden & Why',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              if (hiddenItems.isEmpty && manualBoxes.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline_rounded, color: Colors.blue),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'No sensitive items were selected for hiding. The image was re-encoded and metadata stripped.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: theme.dividerColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...hiddenItems.map((item) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.visibility_off_rounded,
                                    size: 16,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.finding.type.displayName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.reason,
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
                          );
                        }),
                        if (manualBoxes.isNotEmpty) ...[
                          const Divider(height: 16),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4.0),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.brush_rounded,
                                    size: 16,
                                    color: Color(0xFF8B5CF6),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '${manualBoxes.length} Custom Drawn Region${manualBoxes.length == 1 ? '' : 's'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Manually highlighted by you for permanent redaction.',
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
                        ],
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Post-Export Residual Exposure Report
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: finalScore == 0
                        ? const Color(0xFF10B981).withValues(alpha: 0.4)
                        : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (finalScore == 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B))
                                .withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            finalScore == 0 ? Icons.verified_user_rounded : Icons.info_outline_rounded,
                            color: finalScore == 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Post-Export Residual Exposure Report',
                                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                              ),
                              Text(
                                finalScore == 0
                                    ? 'Zero residual exposure verified (0/100)'
                                    : 'Residual exposure: $finalScore/100 remaining',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: finalScore == 0 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      finalScore == 0
                          ? 'All detected sensitive items have been permanently sanitized. The output carries zero identifiable privacy risk for ${purpose.label}.'
                          : 'Specific items were intentionally kept visible to fulfill recipient requirements for ${purpose.label}. Review kept items below.',
                      style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color, height: 1.35),
                    ),
                    const Divider(height: 20),
                    _buildReportItem(
                      icon: Icons.layers_clear_rounded,
                      title: 'Direct Pixel Buffer Overwrite',
                      description: 'Redacted regions were burned directly into the raw pixel bitmap; no reversible vector overlays.',
                    ),
                    const SizedBox(height: 8),
                    _buildReportItem(
                      icon: Icons.location_off_rounded,
                      title: 'EXIF Metadata & GPS Purged',
                      description: 'Re-encoded from scratch; camera model, GPS coordinates, and hardware timestamps removed.',
                    ),
                    const SizedBox(height: 8),
                    _buildReportItem(
                      icon: Icons.shield_outlined,
                      title: 'Kept Findings Audit',
                      description: reviewState.findings.where((f) => f.currentAction.isKeep).isEmpty
                          ? 'All findings were sanitized; no sensitive values kept.'
                          : '${reviewState.findings.where((f) => f.currentAction.isKeep).length} item(s) kept by purpose/choice.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Irreversible Redaction Guarantee Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF10B981).withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_reset_rounded,
                      color: Color(0xFF10B981),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Irreversible Pixel Mutation',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Redacted pixels are overwritten in the raw pixel buffer. Original EXIF GPS & metadata completely purged.',
                            style: TextStyle(
                              fontSize: 11,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action Buttons
              if (exportState.exportResult != null) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    final textToCopy = kIsWeb
                        ? exportState.exportResult!.fileName
                        : exportState.exportResult!.filePath;
                    Clipboard.setData(ClipboardData(text: textToCopy));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          kIsWeb
                              ? 'Safe copy file name copied: $textToCopy'
                              : 'Safe copy saved! Path copied: $textToCopy',
                        ),
                        backgroundColor: const Color(0xFF10B981),
                      ),
                    );
                  },
                  icon: Icon(kIsWeb ? Icons.copy_rounded : Icons.share_rounded),
                  label: Text(kIsWeb ? 'Copy File Name' : 'Share / Copy File Path'),
                ),
                const SizedBox(height: 10),
              ],

              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  );
                },
                icon: const Icon(Icons.history_rounded),
                label: const Text('View Scan History'),
              ),
              const SizedBox(height: 10),

              TextButton.icon(
                onPressed: () {
                  ref.read(sanitizedExportNotifierProvider.notifier).reset();
                  ref.read(selectedImageProvider.notifier).clear();
                  ref.read(selectedPurposeProvider.notifier).clear();
                  ref.read(reviewNotifierProvider.notifier).clearManualBoxes();
                  Navigator.of(context).popUntil((route) => route.isFirst);
                },
                icon: const Icon(Icons.done_all_rounded),
                label: const Text('Done • Start New Scan'),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScoreBadge({
    required String title,
    required int score,
    required Color color,
    required String label,
  }) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const SizedBox(height: 4),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: score.toDouble()),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, child) {
            return Text(
              '${value.round()}',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            );
          },
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Color _scoreColor(int score) {
    if (score >= 60) return const Color(0xFFEF4444);
    if (score >= 25) return const Color(0xFFF59E0B);
    return const Color(0xFF10B981);
  }

  Widget _buildReportItem({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF10B981)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
              const SizedBox(height: 1),
              Text(
                description,
                style: const TextStyle(fontSize: 11, height: 1.3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOriginalImageWidget(String path, {BoxFit fit = BoxFit.contain, double? height}) {
    if (kIsWeb) {
      return Image.network(path, fit: fit, height: height);
    }
    return Image.file(File(path), fit: fit, height: height);
  }

  Widget _buildComparisonView(
    String originalPath,
    Uint8List sanitizedBytes,
    ThemeData theme,
  ) {
    final isDark = theme.brightness == Brightness.dark;
    final sanitizedImageWidget = Image.memory(
      sanitizedBytes,
      fit: BoxFit.contain,
      height: 200,
    );

    if (_mode == ComparisonMode.sideBySide) {
      return Column(
        children: [
          _buildImageCard(
            label: 'Original (Unsafe)',
            labelColor: const Color(0xFFEF4444),
            child: _buildOriginalImageWidget(originalPath, fit: BoxFit.contain, height: 200),
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildImageCard(
            label: 'Sanitized (Safe Copy)',
            labelColor: const Color(0xFF10B981),
            child: sanitizedImageWidget,
            isDark: isDark,
          ),
        ],
      );
    }

    if (_mode == ComparisonMode.toggle) {
      return GestureDetector(
        onTap: () {
          setState(() {
            _showingOriginalInToggle = !_showingOriginalInToggle;
          });
        },
        child: _buildImageCard(
          label: _showingOriginalInToggle
              ? 'Showing: Original (Tap to flip)'
              : 'Showing: Sanitized (Tap to flip)',
          labelColor: _showingOriginalInToggle ? const Color(0xFFEF4444) : const Color(0xFF10B981),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: _showingOriginalInToggle
                ? _buildOriginalImageWidget(
                    originalPath,
                    fit: BoxFit.contain,
                    height: 240,
                  )
                : Image.memory(
                    sanitizedBytes,
                    key: const ValueKey('sani'),
                    fit: BoxFit.contain,
                    height: 240,
                  ),
          ),
          isDark: isDark,
        ),
      );
    }

    // Default: Draggable Split Slider
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        const height = 260.0;

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: height,
            width: width,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
              border: Border.all(color: theme.dividerColor.withValues(alpha: 0.3)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                // 1. Sanitized Base Image (Full width background)
                Positioned.fill(
                  child: Image.memory(
                    sanitizedBytes,
                    fit: BoxFit.contain,
                  ),
                ),

                // 2. Original Image Clipped to slider width
                Positioned.fill(
                  child: ClipRect(
                    clipper: _HorizontalSplitClipper(_sliderPosition),
                    child: _buildOriginalImageWidget(
                      originalPath,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                // 3. Top Badges
                Positioned(
                  top: 10,
                  left: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.65),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Original',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Sanitized',
                      style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                // 4. Draggable Divider Handle
                Positioned(
                  left: (width * _sliderPosition) - 18,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (details) {
                      setState(() {
                        final newPos = (details.localPosition.dx + (width * _sliderPosition) - 18) / width;
                        _sliderPosition = newPos.clamp(0.05, 0.95);
                      });
                    },
                    child: Center(
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.drag_indicator_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                // Thin vertical line along slider
                Positioned(
                  left: width * _sliderPosition - 1,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Container(
                      width: 2,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageCard({
    required String label,
    required Color labelColor,
    required Widget child,
    required bool isDark,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          child,
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: labelColor,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalSplitClipper extends CustomClipper<Rect> {
  final double position;

  _HorizontalSplitClipper(this.position);

  @override
  Rect getClip(Size size) {
    return Rect.fromLTWH(0, 0, size.width * position, size.height);
  }

  @override
  bool shouldReclip(_HorizontalSplitClipper oldClipper) =>
      oldClipper.position != position;
}
