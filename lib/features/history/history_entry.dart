import 'dart:convert';

/// Privacy-safe record of a past redaction scan.
///
/// CRITICAL PRIVACY ASSURANCE:
/// To protect user privacy, this model strictly excludes:
/// - Images (no raw pixel bytes or thumbnails)
/// - File paths (no original or sanitized file system locations)
/// - Extracted sensitive text strings (e.g. actual card or phone numbers)
///
/// Only aggregate metadata is preserved (date, scan purpose, risk score,
/// count of items redacted, and count per sensitive category).
class HistoryEntry {
  final int? id;
  final DateTime timestamp;
  final String purpose;
  final int initialExposureScore;
  final int finalExposureScore;
  final Map<String, int> categoryCounts;
  final int itemsRedactedCount;

  const HistoryEntry({
    this.id,
    required this.timestamp,
    required this.purpose,
    required this.initialExposureScore,
    this.finalExposureScore = 0,
    required this.categoryCounts,
    required this.itemsRedactedCount,
  });

  /// Total number of detected findings across all categories.
  int get totalFindingsDetected =>
      categoryCounts.values.fold(0, (sum, count) => sum + count);

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'timestamp': timestamp.toIso8601String(),
      'purpose': purpose,
      'initial_score': initialExposureScore,
      'final_score': finalExposureScore,
      'category_counts': jsonEncode(categoryCounts),
      'items_redacted_count': itemsRedactedCount,
    };
  }

  factory HistoryEntry.fromMap(Map<String, dynamic> map) {
    Map<String, int> counts = {};
    if (map['category_counts'] != null) {
      try {
        final decoded = jsonDecode(map['category_counts'] as String);
        if (decoded is Map) {
          counts = decoded.map((k, v) => MapEntry(k.toString(), (v as num).toInt()));
        }
      } catch (_) {}
    }

    return HistoryEntry(
      id: map['id'] as int?,
      timestamp: DateTime.tryParse(map['timestamp'] as String? ?? '') ?? DateTime.now(),
      purpose: map['purpose'] as String? ?? 'General Scan',
      initialExposureScore: (map['initial_score'] as int?) ?? 0,
      finalExposureScore: (map['final_score'] as int?) ?? 0,
      categoryCounts: counts,
      itemsRedactedCount: (map['items_redacted_count'] as int?) ?? 0,
    );
  }

  HistoryEntry copyWith({
    int? id,
    DateTime? timestamp,
    String? purpose,
    int? initialExposureScore,
    int? finalExposureScore,
    Map<String, int>? categoryCounts,
    int? itemsRedactedCount,
  }) {
    return HistoryEntry(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      purpose: purpose ?? this.purpose,
      initialExposureScore: initialExposureScore ?? this.initialExposureScore,
      finalExposureScore: finalExposureScore ?? this.finalExposureScore,
      categoryCounts: categoryCounts ?? this.categoryCounts,
      itemsRedactedCount: itemsRedactedCount ?? this.itemsRedactedCount,
    );
  }
}
