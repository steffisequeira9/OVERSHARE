import 'package:flutter/foundation.dart';

@immutable
class RedactionRecord {
  final int? id;
  final int scanId;
  final int? findingId;
  final String style;
  final bool applied;
  final bool verified;

  const RedactionRecord({
    this.id,
    required this.scanId,
    this.findingId,
    required this.style,
    required this.applied,
    required this.verified,
  });

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'scanId': scanId,
      'findingId': findingId,
      'style': style,
      'applied': applied ? 1 : 0,
      'verified': verified ? 1 : 0,
    };
  }

  factory RedactionRecord.fromMap(Map<String, dynamic> map) {
    return RedactionRecord(
      id: map['id'] as int?,
      scanId: (map['scanId'] as int?) ?? 0,
      findingId: map['findingId'] as int?,
      style: map['style'] as String? ?? 'solidFill',
      applied: (map['applied'] as int?) == 1,
      verified: (map['verified'] as int?) == 1,
    );
  }
}
