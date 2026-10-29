import 'package:flutter/foundation.dart';
import 'bounding_box.dart';
import 'sensitive_type.dart';

enum FindingSource {
  ocr,
  rule,
  face,
  manual,
}

enum DetectionStatus {
  detected,
  inferred,
  cannotBeIdentified,
}

@immutable
class Finding {
  final SensitiveType type;
  final String matchedText;
  final String maskedPreview;
  final BoundingBox boundingBox;
  final double confidence; // 0.0 - 1.0
  final FindingSource source;
  final DetectionStatus status;

  Finding({
    required this.type,
    required this.matchedText,
    required this.boundingBox,
    String? maskedPreview,
    this.confidence = 1.0,
    this.source = FindingSource.ocr,
    this.status = DetectionStatus.detected,
  }) : maskedPreview = maskedPreview ?? generateMaskedPreview(type, matchedText);

  static String generateMaskedPreview(SensitiveType type, String text) {
    final clean = text.trim();
    if (clean.isEmpty) return '••••';

    switch (type) {
      case SensitiveType.card:
        final digits = clean.replaceAll(RegExp(r'\D'), '');
        final last4 = digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
        return '•••• •••• •••• $last4';

      case SensitiveType.aadhaar:
        final digits = clean.replaceAll(RegExp(r'\D'), '');
        final last4 = digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
        return '•••• •••• $last4';

      case SensitiveType.pan:
        if (clean.length >= 10) {
          return '${clean.substring(0, 2)}••• •••• ${clean.substring(clean.length - 1)}';
        }
        return '••••• •••• •';

      case SensitiveType.voterId:
        if (clean.length >= 6) {
          return '${clean.substring(0, 3)}••••${clean.substring(clean.length - 3)}';
        }
        return '••••••••';

      case SensitiveType.dob:
        return '••/••/••••';

      case SensitiveType.credential:
        return '••••••••';

      case SensitiveType.email:
        final parts = clean.split('@');
        if (parts.length == 2 && parts[0].isNotEmpty) {
          final first = parts[0][0];
          return '$first***@${parts[1]}';
        }
        return '***@••••';

      case SensitiveType.phone:
        final digits = clean.replaceAll(RegExp(r'\D'), '');
        final last4 = digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
        return '•••• ••$last4';

      case SensitiveType.senderUpiId:
      case SensitiveType.recipientUpiId:
      case SensitiveType.upiId:
        final parts = clean.split('@');
        if (parts.length == 2) {
          final prefix = parts[0].length > 2 ? '${parts[0].substring(0, 2)}•••' : '•••';
          return '$prefix@${parts[1]}';
        }
        return '••••@••••';

      case SensitiveType.accountNumber:
        final digits = clean.replaceAll(RegExp(r'\D'), '');
        final last4 = digits.length >= 4 ? digits.substring(digits.length - 4) : digits;
        return '••••••$last4';

      case SensitiveType.transactionId:
        if (clean.length > 4) {
          return '••••${clean.substring(clean.length - 4)}';
        }
        return '••••••••';

      case SensitiveType.ifsc:
        if (clean.length >= 4) {
          return '${clean.substring(0, 4)}•••••••';
        }
        return '••••••••';

      case SensitiveType.amount:
        return '₹••••';

      case SensitiveType.dateTime:
        return '••/••/••••';

      case SensitiveType.personName:
        return '•••• ••••';

      case SensitiveType.face:
        return '[Face detected]';

      case SensitiveType.url:
        final uri = Uri.tryParse(clean);
        if (uri != null && uri.host.isNotEmpty) {
          return '${uri.host}/••••';
        }
        return 'https://••••';
    }
  }

  Finding copyWith({
    SensitiveType? type,
    String? matchedText,
    String? maskedPreview,
    BoundingBox? boundingBox,
    double? confidence,
    FindingSource? source,
    DetectionStatus? status,
  }) {
    return Finding(
      type: type ?? this.type,
      matchedText: matchedText ?? this.matchedText,
      maskedPreview: maskedPreview ?? this.maskedPreview,
      boundingBox: boundingBox ?? this.boundingBox,
      confidence: confidence ?? this.confidence,
      source: source ?? this.source,
      status: status ?? this.status,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Finding &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          matchedText == other.matchedText &&
          maskedPreview == other.maskedPreview &&
          boundingBox == other.boundingBox &&
          confidence == other.confidence &&
          source == other.source &&
          status == other.status;

  @override
  int get hashCode => Object.hash(
        type,
        matchedText,
        maskedPreview,
        boundingBox,
        confidence,
        source,
        status,
      );

  @override
  String toString() =>
      'Finding(type: $type, preview: "$maskedPreview", box: $boundingBox, conf: $confidence, source: $source)';
}
