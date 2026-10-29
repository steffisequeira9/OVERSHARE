import 'package:flutter/foundation.dart';

@immutable
class ScanRecord {
  final int? id;
  final DateTime createdAt;
  final String purpose;
  final String audience;
  final int originalScore;
  final int sanitizedScore;
  final String status;
  final String verificationStatus;
  final String? retainedImagePath; // Explicit opt-in only; null by default

  const ScanRecord({
    this.id,
    required this.createdAt,
    required this.purpose,
    required this.audience,
    required this.originalScore,
    required this.sanitizedScore,
    this.status = 'completed',
    this.verificationStatus = 'verified',
    this.retainedImagePath,
  });

  bool get hasRetainedImage =>
      retainedImagePath != null && retainedImagePath!.isNotEmpty;

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'createdAt': createdAt.toIso8601String(),
      'purpose': purpose,
      'audience': audience,
      'originalScore': originalScore,
      'sanitizedScore': sanitizedScore,
      'status': status,
      'verificationStatus': verificationStatus,
      'retainedImagePath': retainedImagePath,
    };
  }

  factory ScanRecord.fromMap(Map<String, dynamic> map) {
    return ScanRecord(
      id: map['id'] as int?,
      createdAt: DateTime.tryParse(map['createdAt'] as String? ?? '') ??
          DateTime.now(),
      purpose: map['purpose'] as String? ?? 'General',
      audience: map['audience'] as String? ?? 'Private Recipient',
      originalScore: (map['originalScore'] as int?) ?? 0,
      sanitizedScore: (map['sanitizedScore'] as int?) ?? 0,
      status: map['status'] as String? ?? 'completed',
      verificationStatus: map['verificationStatus'] as String? ?? 'verified',
      retainedImagePath: map['retainedImagePath'] as String?,
    );
  }

  ScanRecord copyWith({
    int? id,
    DateTime? createdAt,
    String? purpose,
    String? audience,
    int? originalScore,
    int? sanitizedScore,
    String? status,
    String? verificationStatus,
    String? retainedImagePath,
    bool clearRetainedImage = false,
  }) {
    return ScanRecord(
      id: id ?? this.id,
      createdAt: createdAt ?? this.createdAt,
      purpose: purpose ?? this.purpose,
      audience: audience ?? this.audience,
      originalScore: originalScore ?? this.originalScore,
      sanitizedScore: sanitizedScore ?? this.sanitizedScore,
      status: status ?? this.status,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      retainedImagePath: clearRetainedImage
          ? null
          : (retainedImagePath ?? this.retainedImagePath),
    );
  }
}
