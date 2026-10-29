import 'history_entry.dart';
import 'models/ai_advice_record.dart';
import 'models/finding_record.dart';
import 'models/redaction_record.dart';
import 'models/scan_details.dart';
import 'models/scan_record.dart';

abstract class HistoryRepository {
  /// Inserts a scan with associated findings, redactions, and advice within a transaction.
  Future<int> insertScan({
    required ScanRecord scan,
    List<FindingRecord> findings = const [],
    List<RedactionRecord> redactions = const [],
    List<AiAdviceRecord> advice = const [],
  });

  /// Legacy compatibility insert
  Future<int> insertEntry(HistoryEntry entry);

  /// Retrieves all scan records ordered by createdAt DESC
  Future<List<ScanRecord>> getAllScans();

  /// Legacy compatibility query
  Future<List<HistoryEntry>> getAllEntries();

  /// Retrieves full details (findings, redactions, advice) for a specific scan
  Future<ScanDetails?> getScanDetails(int scanId);

  /// Deletes a scan, cascading to findings, redactions, and advice.
  /// Also deletes any retained image file from disk.
  Future<int> deleteScan(int scanId);

  /// Legacy compatibility deletion
  Future<int> deleteEntry(int id);

  /// Clears all scans and cascading relations
  Future<int> clearAll();

  /// Deletes the retained image file from disk and clears the reference
  Future<void> deleteRetainedImage(int scanId);

  /// Indicates if history persistence is supported on the current platform
  bool get isSupported;

  /// Error or informative message if persistence is not supported
  String? get unsupportedMessage;
}
