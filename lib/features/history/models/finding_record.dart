import 'package:flutter/foundation.dart';

@immutable
class FindingRecord {
  final int? id;
  final int scanId;
  final String type;
  final String maskedPreview;
  final double x;
  final double y;
  final double w;
  final double h;
  final double confidence;
  final String recommendation;
  final String reason;
  final String userAction;
  final String source;

  const FindingRecord({
    this.id,
    required this.scanId,
    required this.type,
    required this.maskedPreview,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.confidence,
    required this.recommendation,
    required this.reason,
    required this.userAction,
    required this.source,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'scanId': scanId,
      'type': type,
      'maskedPreview': maskedPreview,
      'x': x,
      'y': y,
      'w': w,
      'h': h,
      'confidence': confidence,
      'recommendation': recommendation,
      'reason': reason,
      'userAction': userAction,
      'source': source,
    };
  }

  factory FindingRecord.fromMap(Map<String, dynamic> map) {
    return FindingRecord(
      id: map['id'] as int?,
      scanId: (map['scanId'] as int?) ?? 0,
      type: map['type'] as String? ?? 'General',
      maskedPreview: map['maskedPreview'] as String? ?? '••••',
      x: (map['x'] as num?)?.toDouble() ?? 0.0,
      y: (map['y'] as num?)?.toDouble() ?? 0.0,
      w: (map['w'] as num?)?.toDouble() ?? 0.0,
      h: (map['h'] as num?)?.toDouble() ?? 0.0,
      confidence: (map['confidence'] as num?)?.toDouble() ?? 1.0,
      recommendation: map['recommendation'] as String? ?? 'HIDE',
      reason: map['reason'] as String? ?? '',
      userAction: map['userAction'] as String? ?? 'HIDE',
      source: map['source'] as String? ?? 'ocr',
    );
  }
}
