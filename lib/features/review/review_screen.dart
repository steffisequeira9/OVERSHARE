import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/app_state.dart';
import '../decision/purpose.dart';
import '../decision/risk_scorer.dart';
import '../scanner/models/sensitive_type.dart';
import 'coordinate_converter.dart';
import 'redaction_overlay_painter.dart';
import 'review_notifier.dart';
import '../redaction/safe_copy_screen.dart';

class ReviewScreen extends ConsumerStatefulWidget {
  const ReviewScreen({super.key});

  @override
  ConsumerState<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends ConsumerState<ReviewScreen> {
  Rect? _activeDragRect;
  Offset? _dragStart;
  double _imgNaturalWidth = 1080;
  double _imgNaturalHeight = 1920;
  bool _hasResolvedDimensions = false;
  int? _selectedFindingIndex;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resolveImageDimensions();
    });
  }

  void _resolveImageDimensions() {
    final imageFile = ref.read(selectedImageProvider);
    if (imageFile == null) return;

    final ImageProvider provider = kIsWeb
        ? NetworkImage(imageFile.path)
        : FileImage(File(imageFile.path)) as ImageProvider;

    provider.resolve(const ImageConfiguration()).addListener(
      ImageStreamListener((ImageInfo info, bool _) {
        if (mounted) {
          setState(() {
            _imgNaturalWidth = info.image.width.toDouble();
            _imgNaturalHeight = info.image.height.toDouble();
            _hasResolvedDimensions = true;
          });
          ref.read(reviewNotifierProvider.notifier).setImageDimensions(
                _imgNaturalWidth,
                _imgNaturalHeight,
              );
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final selectedImage = ref.watch(selectedImageProvider);
    final purpose = ref.watch(selectedPurposeProvider) ?? Purpose.paymentProof;
    final selectedAudience = ref.watch(selectedAudienceProvider);
    final reviewState = ref.watch(reviewNotifierProvider);
    final liveScore = ref.watch(liveExposureScoreProvider);
    final initialScore = ref.watch(initialDetectedScoreProvider);

    final scoreColor = liveScore.totalScore > 50
        ? const Color(0xFFEF4444)
        : liveScore.totalScore > 20
            ? const Color(0xFFF59E0B)
            : const Color(0xFF10B981);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review & Redact'),
        actions: [
          IconButton(
            tooltip: 'Undo last manual box',
            icon: const Icon(Icons.undo_rounded),
            onPressed: reviewState.manualBoxes.isNotEmpty
                ? () => ref.read(reviewNotifierProvider.notifier).undoManualBox()
                : null,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Canvas Area (Interactive Image + Redaction Overlays)
            Expanded(
              flex: 5,
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.dividerColor.withValues(alpha: 0.2),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: selectedImage == null
                    ? const Center(child: Text('No image selected'))
                    : LayoutBuilder(
                        builder: (context, constraints) {
                          final converter = CoordinateConverter(
                            imageWidth: _hasResolvedDimensions
                                ? _imgNaturalWidth
                                : (reviewState.imageWidth > 0
                                    ? reviewState.imageWidth
                                    : 1080),
                            imageHeight: _hasResolvedDimensions
                                ? _imgNaturalHeight
                                : (reviewState.imageHeight > 0
                                    ? reviewState.imageHeight
                                    : 1920),
                            displayWidth: constraints.maxWidth,
                            displayHeight: constraints.maxHeight,
                          );

                          return GestureDetector(
                            onTapUp: (details) {
                              // Tap detection on boxes to select and toggle HIDE <-> KEEP
                              final tapPos = details.localPosition;
                              for (int i = 0; i < reviewState.findings.length; i++) {
                                final screenRect = converter.imageToScreenRect(
                                  reviewState.findings[i].finding.boundingBox,
                                );
                                if (screenRect.contains(tapPos)) {
                                  setState(() {
                                    _selectedFindingIndex = i;
                                  });
                                  ref
                                      .read(reviewNotifierProvider.notifier)
                                      .toggleFinding(i);
                                  break;
                                }
                              }
                            },
                            onPanStart: (details) {
                              setState(() {
                                _dragStart = details.localPosition;
                                _activeDragRect = Rect.fromPoints(
                                  details.localPosition,
                                  details.localPosition,
                                );
                              });
                            },
                            onPanUpdate: (details) {
                              if (_dragStart != null) {
                                setState(() {
                                  _activeDragRect = Rect.fromPoints(
                                    _dragStart!,
                                    details.localPosition,
                                  );
                                });
                              }
                            },
                            onPanEnd: (_) {
                              if (_activeDragRect != null &&
                                  _activeDragRect!.width > 10 &&
                                  _activeDragRect!.height > 10) {
                                final imageBox =
                                    converter.screenToImageRect(_activeDragRect!);
                                ref
                                    .read(reviewNotifierProvider.notifier)
                                    .addManualBox(imageBox);
                              }
                              setState(() {
                                _dragStart = null;
                                _activeDragRect = null;
                              });
                            },
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                // Background base image
                                Center(
                                  child: kIsWeb
                                      ? Image.network(
                                          selectedImage.path,
                                          fit: BoxFit.contain,
                                        )
                                      : Image.file(
                                          File(selectedImage.path),
                                          fit: BoxFit.contain,
                                        ),
                                ),

                                // CustomPainter overlay with active selection highlight
                                CustomPaint(
                                  painter: RedactionOverlayPainter(
                                    findings: reviewState.findings,
                                    manualBoxes: reviewState.manualBoxes,
                                    currentDrawingRect: _activeDragRect,
                                    converter: converter,
                                    selectedIndex: _selectedFindingIndex,
                                  ),
                                ),

                                // Instruction Pill (Constrained with right: 10 to avoid overflow)
                                Positioned(
                                  top: 10,
                                  left: 10,
                                  right: 10,
                                  child: Align(
                                    alignment: Alignment.topLeft,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.75),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: const [
                                          Icon(
                                            Icons.touch_app_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              'Tap box to toggle • Drag to draw custom box',
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ),

            // Live Privacy Exposure Bar with Dual Score & Interactive Breakdown
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  InkWell(
                    onTap: () => _showScoreBreakdownSheet(
                      context,
                      liveScore,
                      initialScore,
                      purpose,
                      selectedAudience,
                      theme,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: scoreColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: scoreColor.withValues(alpha: 0.35),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 0,
                              end: liveScore.totalScore.toDouble(),
                            ),
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            builder: (context, val, child) {
                              return Text(
                                'Residual: ${val.round()}/100',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                  color: scoreColor,
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 4),
                          Icon(Icons.info_outline_rounded, size: 13, color: scoreColor),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          liveScore.exposureLevel,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: scoreColor,
                          ),
                        ),
                        if (initialScore.totalScore > 0)
                          Text(
                            'Original: ${initialScore.totalScore}/100 (${initialScore.exposureLevel})',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Audience Indicator & Quick Toggle
                  InkWell(
                    onTap: () {
                      final next = selectedAudience == Audience.privateAudience
                          ? Audience.publicAudience
                          : Audience.privateAudience;
                      ref.read(selectedAudienceProvider.notifier).setAudience(next);
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(selectedAudience.icon, size: 12, color: theme.textTheme.bodySmall?.color),
                          const SizedBox(width: 4),
                          Text(
                            selectedAudience == Audience.privateAudience ? 'Private' : 'Public',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  PopupMenuButton<Purpose>(
                    tooltip: 'Change sharing purpose',
                    onSelected: (newPurpose) {
                      ref.read(selectedPurposeProvider.notifier).setPurpose(newPurpose);
                    },
                    itemBuilder: (context) {
                      return Purpose.values.map((p) {
                        final isSelected = p == purpose;
                        return PopupMenuItem(
                          value: p,
                          child: Row(
                            children: [
                              Icon(
                                p.icon,
                                size: 16,
                                color: isSelected
                                    ? theme.colorScheme.primary
                                    : theme.iconTheme.color,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                p.label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  color: isSelected ? theme.colorScheme.primary : null,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(purpose.icon, size: 12, color: theme.textTheme.bodySmall?.color),
                          const SizedBox(width: 4),
                          Text(
                            purpose.label,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: theme.textTheme.bodySmall?.color,
                            ),
                          ),
                          const SizedBox(width: 2),
                          Icon(Icons.arrow_drop_down, size: 14, color: theme.textTheme.bodySmall?.color),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Bottom Findings & Visual Privacy Audit List
            Expanded(
              flex: 4,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
                children: [
                  // Before Sharing Warning Banner (if high-risk data kept unredacted)
                  if (reviewState.findings.any((f) =>
                      f.currentAction.isKeep &&
                      (f.finding.type == SensitiveType.aadhaar ||
                          f.finding.type == SensitiveType.card ||
                          f.finding.type == SensitiveType.pan ||
                          f.finding.type == SensitiveType.voterId ||
                          f.finding.type == SensitiveType.credential)))
                    Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Before Sharing Warning: High-Risk Data Unredacted',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 12,
                                    color: Color(0xFFEF4444),
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'One or more high-risk credentials (National ID, Card, or Password) are toggled to KEEP. Anyone receiving this image will be able to see these unredacted details.',
                                  style: TextStyle(fontSize: 11, height: 1.3),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Manual Boxes Section (if any)
                  if (reviewState.manualBoxes.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Manual Redactions (${reviewState.manualBoxes.length})',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          TextButton(
                            onPressed: () => ref
                                .read(reviewNotifierProvider.notifier)
                                .clearManualBoxes(),
                            child: const Text('Clear All'),
                          ),
                        ],
                      ),
                    ),
                    ...reviewState.manualBoxes.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final box = entry.value;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(
                            Icons.draw_rounded,
                            color: Color(0xFFEF4444),
                          ),
                          title: Text(
                            'Manual Box #${idx + 1}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            'Region: ${box.width.toStringAsFixed(0)}x${box.height.toStringAsFixed(0)} px (Always Redacted)',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 20),
                            onPressed: () => ref
                                .read(reviewNotifierProvider.notifier)
                                .deleteManualBox(idx),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                  ],

                  // Visual Privacy Audit Header: What This Image Reveals
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'What This Image Reveals (${reviewState.findings.length})',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          'Tap box or card to focus',
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.textTheme.bodySmall?.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (reviewState.findings.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(child: Text('No findings detected.')),
                    )
                  else
                    ...reviewState.findings.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final item = entry.value;
                      final isRedacted = !item.currentAction.isKeep;
                      final isSelected = _selectedFindingIndex == idx;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: isSelected
                            ? RoundedRectangleBorder(
                                side: const BorderSide(color: Colors.amberAccent, width: 1.5),
                                borderRadius: BorderRadius.circular(16),
                              )
                            : null,
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _selectedFindingIndex = idx;
                            });
                            ref
                                .read(reviewNotifierProvider.notifier)
                                .toggleFinding(idx);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: (isRedacted
                                            ? (item.currentAction.isBlurFace
                                                ? const Color(0xFF8B5CF6)
                                                : const Color(0xFFEF4444))
                                            : const Color(0xFF10B981))
                                        .withValues(alpha: isDark ? 0.2 : 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    item.currentAction.label,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11,
                                      color: isRedacted
                                          ? (item.currentAction.isBlurFace
                                              ? const Color(0xFF8B5CF6)
                                              : const Color(0xFFEF4444))
                                          : const Color(0xFF10B981),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            item.finding.type.displayName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          if (item.currentAction != item.defaultAction) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: Colors.blueAccent.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'Overridden',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.blueAccent,
                                                ),
                                              ),
                                            ),
                                          ],
                                          if (item.finding.confidence < 0.70) ...[
                                            const SizedBox(width: 4),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                              decoration: BoxDecoration(
                                                color: Colors.amber.withValues(alpha: 0.15),
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text(
                                                'Low confidence',
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.w700,
                                                  color: Colors.amber,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      Text(
                                        item.finding.maskedPreview,
                                        style: TextStyle(
                                          fontFamily: 'monospace',
                                          fontSize: 12,
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        item.reason,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: theme.textTheme.bodySmall?.color,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch.adaptive(
                                  value: isRedacted,
                                  activeTrackColor: const Color(0xFFEF4444),
                                  onChanged: (_) {
                                    setState(() {
                                      _selectedFindingIndex = idx;
                                    });
                                    ref
                                        .read(reviewNotifierProvider.notifier)
                                        .toggleFinding(idx);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),

            // Bottom Safe Copy Button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SafeCopyScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.shield_rounded),
                label: Text(
                  'Create safe copy (${reviewState.getFinalRedactionRegions().length} to redact)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showScoreBreakdownSheet(
    BuildContext context,
    RiskScoreResult score,
    RiskScoreResult initialScore,
    Purpose purpose,
    Audience audience,
    ThemeData theme,
  ) {
    final isDark = theme.brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: ListView(
                controller: scrollController,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.analytics_outlined, color: theme.colorScheme.primary, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Privacy Exposure Breakdown',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${purpose.label} • ${audience.label}',
                              style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (score.totalScore > 50 ? Colors.redAccent : Colors.amber).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${score.totalScore}/100',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: score.totalScore > 50 ? Colors.redAccent : Colors.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Exposure score reflects identifiable data exposed to the recipient. Redacted items contribute 0 points; kept sensitive items add risk points.',
                    style: TextStyle(fontSize: 12, color: theme.textTheme.bodySmall?.color, height: 1.35),
                  ),
                  const Divider(height: 24),
                  if (score.items.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24.0),
                      child: Center(child: Text('No sensitive findings detected.')),
                    )
                  else
                    ...score.items.map((item) {
                      final isZero = item.points == 0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isZero
                                ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                : const Color(0xFFEF4444).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isZero ? Icons.shield_rounded : Icons.warning_amber_rounded,
                              size: 20,
                              color: isZero ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        item.type.displayName,
                                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                      const Spacer(),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: (isZero ? const Color(0xFF10B981) : const Color(0xFFEF4444))
                                              .withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                          isZero ? '+0 pts (Redacted)' : '+${item.points} pts (Exposed)',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                            color: isZero ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    item.finding.maskedPreview,
                                    style: TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 12,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    item.explanation,
                                    style: TextStyle(fontSize: 11, color: theme.textTheme.bodySmall?.color),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
