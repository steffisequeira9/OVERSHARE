import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'history_database.dart';
import 'history_entry.dart';
import 'models/ai_advice_record.dart';
import 'models/finding_record.dart';
import 'models/redaction_record.dart';
import 'models/scan_details.dart';
import 'models/scan_record.dart';

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  if (kIsWeb) {
    return const WebHistoryRepository();
  }
  return SqfliteHistoryDatabase();
});

class HistoryState {
  final bool isLoading;
  final List<ScanRecord> scans;
  final List<HistoryEntry> entries;
  final String? error;
  final bool isSupported;
  final String? unsupportedMessage;

  const HistoryState({
    this.isLoading = false,
    this.scans = const [],
    this.entries = const [],
    this.error,
    this.isSupported = true,
    this.unsupportedMessage,
  });

  HistoryState copyWith({
    bool? isLoading,
    List<ScanRecord>? scans,
    List<HistoryEntry>? entries,
    String? error,
    bool? isSupported,
    String? unsupportedMessage,
  }) {
    return HistoryState(
      isLoading: isLoading ?? this.isLoading,
      scans: scans ?? this.scans,
      entries: entries ?? this.entries,
      error: error,
      isSupported: isSupported ?? this.isSupported,
      unsupportedMessage: unsupportedMessage ?? this.unsupportedMessage,
    );
  }
}

class HistoryNotifier extends Notifier<HistoryState> {
  @override
  HistoryState build() {
    final repo = ref.watch(historyRepositoryProvider);
    if (!repo.isSupported) {
      return HistoryState(
        isSupported: false,
        unsupportedMessage: repo.unsupportedMessage,
      );
    }
    Future.microtask(() => loadHistory());
    return const HistoryState(isLoading: true);
  }

  Future<void> loadHistory() async {
    final repo = ref.read(historyRepositoryProvider);
    if (!repo.isSupported) {
      state = state.copyWith(
        isSupported: false,
        unsupportedMessage: repo.unsupportedMessage,
      );
      return;
    }

    state = state.copyWith(isLoading: true, error: null);
    try {
      final scans = await repo.getAllScans();
      final entries = await repo.getAllEntries();
      state = state.copyWith(
        isLoading: false,
        scans: scans,
        entries: entries,
      );
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  // Backward compatibility alias
  Future<void> loadEntries() => loadHistory();

  Future<void> addScan({
    required ScanRecord scan,
    List<FindingRecord> findings = const [],
    List<RedactionRecord> redactions = const [],
    List<AiAdviceRecord> advice = const [],
  }) async {
    try {
      final repo = ref.read(historyRepositoryProvider);
      await repo.insertScan(
        scan: scan,
        findings: findings,
        redactions: redactions,
        advice: advice,
      );
      await loadHistory();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> addEntry(HistoryEntry entry) async {
    try {
      final repo = ref.read(historyRepositoryProvider);
      await repo.insertEntry(entry);
      await loadHistory();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<ScanDetails?> getScanDetails(int scanId) async {
    final repo = ref.read(historyRepositoryProvider);
    return await repo.getScanDetails(scanId);
  }

  Future<void> deleteScan(int scanId) async {
    try {
      final repo = ref.read(historyRepositoryProvider);
      await repo.deleteScan(scanId);
      await loadHistory();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteEntry(int id) async {
    try {
      final repo = ref.read(historyRepositoryProvider);
      await repo.deleteEntry(id);
      await loadHistory();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> deleteRetainedImage(int scanId) async {
    try {
      final repo = ref.read(historyRepositoryProvider);
      await repo.deleteRetainedImage(scanId);
      await loadHistory();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  Future<void> clearAll() async {
    try {
      final repo = ref.read(historyRepositoryProvider);
      await repo.clearAll();
      state = state.copyWith(scans: const [], entries: const []);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }
}

final historyNotifierProvider =
    NotifierProvider<HistoryNotifier, HistoryState>(HistoryNotifier.new);
