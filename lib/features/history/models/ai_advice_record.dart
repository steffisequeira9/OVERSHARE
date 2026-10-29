import 'package:flutter/foundation.dart';

@immutable
class AiAdviceRecord {
  final int? id;
  final int scanId;
  final int? findingId;
  final String summary;
  final String model;
  final DateTime createdAt;

  const AiAdviceRecord({
    this.id,
    required this.scanId,
    this.findingId,
    required this.summary,
    required this.model,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'scanId': scanId,
      'findingId': findingId,
      'summary': summary,
      'model': model,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory AiAdviceRecord.fromMap(Map<String, dynamic> map) {
    return AiAdviceRecord(
      id: map['id'] as int?,
      scanId: (map['scanId'] as int?) ?? 0,
      findingId: map['findingId'] as int?,
      summary: map['summary'] as String? ?? '',
      model: map['model'] as String? ?? 'on-device-rule-engine',
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}
