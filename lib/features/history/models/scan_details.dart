import 'package:flutter/foundation.dart';
import 'ai_advice_record.dart';
import 'finding_record.dart';
import 'redaction_record.dart';
import 'scan_record.dart';

@immutable
class ScanDetails {
  final ScanRecord scan;
  final List<FindingRecord> findings;
  final List<RedactionRecord> redactions;
  final List<AiAdviceRecord> advice;

  const ScanDetails({
    required this.scan,
    this.findings = const [],
    this.redactions = const [],
    this.advice = const [],
  });
}
