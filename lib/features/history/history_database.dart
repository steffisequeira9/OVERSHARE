import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'history_entry.dart';
import 'history_repository.dart';
import 'models/ai_advice_record.dart';
import 'models/finding_record.dart';
import 'models/redaction_record.dart';
import 'models/scan_details.dart';
import 'models/scan_record.dart';

export 'history_repository.dart';

class SqfliteHistoryDatabase implements HistoryRepository {
  static const String dbFileName = 'overshare_history.db';
  static const int currentVersion = 2;

  final Database? _overrideDb;
  Database? _db;

  SqfliteHistoryDatabase([this._overrideDb]);

  @override
  bool get isSupported => !kIsWeb;

  @override
  String? get unsupportedMessage => null;

  Future<Database> get database async {
    if (_overrideDb != null) return _overrideDb;
    if (_db != null && _db!.isOpen) return _db!;
    _db = await _initDatabase();
    return _db!;
  }

  Future<Database> _initDatabase() async {
    final databasesPath = await getDatabasesPath();
    final path = p.join(databasesPath, dbFileName);

    return await openDatabase(
      path,
      version: currentVersion,
      onConfigure: (db) async {
        // Enforce foreign key constraints with ON DELETE CASCADE
        await db.execute('PRAGMA foreign_keys = ON;');
      },
      onCreate: (db, version) async {
        await createV2Schema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await migrateV1ToV2(db);
        }
      },
    );
  }

  static Future<void> createV2Schema(DatabaseExecutor db) async {
    // 1. Scans Table
    await db.execute('''
      CREATE TABLE scans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        createdAt TEXT NOT NULL,
        purpose TEXT NOT NULL,
        audience TEXT NOT NULL,
        originalScore INTEGER NOT NULL,
        sanitizedScore INTEGER NOT NULL,
        status TEXT NOT NULL,
        verificationStatus TEXT NOT NULL,
        retainedImagePath TEXT
      );
    ''');

    // 2. Findings Table
    await db.execute('''
      CREATE TABLE findings (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scanId INTEGER NOT NULL,
        type TEXT NOT NULL,
        maskedPreview TEXT NOT NULL,
        x REAL NOT NULL,
        y REAL NOT NULL,
        w REAL NOT NULL,
        h REAL NOT NULL,
        confidence REAL NOT NULL,
        recommendation TEXT NOT NULL,
        reason TEXT NOT NULL,
        userAction TEXT NOT NULL,
        source TEXT NOT NULL,
        FOREIGN KEY (scanId) REFERENCES scans(id) ON DELETE CASCADE
      );
    ''');

    // 3. Redactions Table
    await db.execute('''
      CREATE TABLE redactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scanId INTEGER NOT NULL,
        findingId INTEGER,
        style TEXT NOT NULL,
        applied INTEGER NOT NULL,
        verified INTEGER NOT NULL,
        FOREIGN KEY (scanId) REFERENCES scans(id) ON DELETE CASCADE
      );
    ''');

    // 4. Optional AI Advice Table
    await db.execute('''
      CREATE TABLE ai_advice (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scanId INTEGER NOT NULL,
        findingId INTEGER,
        summary TEXT NOT NULL,
        model TEXT NOT NULL,
        createdAt TEXT NOT NULL,
        FOREIGN KEY (scanId) REFERENCES scans(id) ON DELETE CASCADE
      );
    ''');

    // Indexes on foreign keys for optimal performance
    await db.execute('CREATE INDEX idx_findings_scan_id ON findings(scanId);');
    await db.execute('CREATE INDEX idx_redactions_scan_id ON redactions(scanId);');
    await db.execute('CREATE INDEX idx_ai_advice_scan_id ON ai_advice(scanId);');
  }

  static Future<void> migrateV1ToV2(Database db) async {
    // Create new tables and relations
    await createV2Schema(db);

    // Check if legacy scan_history table exists from v1
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='scan_history';",
    );

    if (tables.isNotEmpty) {
      // Migrate legacy flat records into new scans table
      final legacyRows = await db.query('scan_history');
      for (final row in legacyRows) {
        await db.insert('scans', {
          'id': row['id'],
          'createdAt': row['timestamp'] ?? DateTime.now().toIso8601String(),
          'purpose': row['purpose'] ?? 'General Scan',
          'audience': 'Private Recipient',
          'originalScore': row['initial_score'] ?? 0,
          'sanitizedScore': row['final_score'] ?? 0,
          'status': 'completed',
          'verificationStatus': 'legacy_migrated',
          'retainedImagePath': null,
        });
      }
    }
  }

  @override
  Future<int> insertScan({
    required ScanRecord scan,
    List<FindingRecord> findings = const [],
    List<RedactionRecord> redactions = const [],
    List<AiAdviceRecord> advice = const [],
  }) async {
    final db = await database;
    return await db.transaction<int>((txn) async {
      final scanId = await txn.insert('scans', scan.toMap());

      for (final f in findings) {
        final map = f.toMap();
        map['scanId'] = scanId;
        await txn.insert('findings', map);
      }

      for (final r in redactions) {
        final map = r.toMap();
        map['scanId'] = scanId;
        await txn.insert('redactions', map);
      }

      for (final a in advice) {
        final map = a.toMap();
        map['scanId'] = scanId;
        await txn.insert('ai_advice', map);
      }

      return scanId;
    });
  }

  @override
  Future<int> insertEntry(HistoryEntry entry) async {
    // Backward compatibility conversion into ScanRecord
    final scan = ScanRecord(
      id: entry.id,
      createdAt: entry.timestamp,
      purpose: entry.purpose,
      audience: 'Private Recipient',
      originalScore: entry.initialExposureScore,
      sanitizedScore: entry.finalExposureScore,
      status: 'completed',
      verificationStatus: 'verified',
    );
    return await insertScan(scan: scan);
  }

  @override
  Future<List<ScanRecord>> getAllScans() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'scans',
      orderBy: 'createdAt DESC',
    );
    return maps.map((m) => ScanRecord.fromMap(m)).toList();
  }

  @override
  Future<List<HistoryEntry>> getAllEntries() async {
    final scans = await getAllScans();
    final List<HistoryEntry> entries = [];
    for (final s in scans) {
      final details = await getScanDetails(s.id!);
      final categoryCounts = <String, int>{};
      if (details != null) {
        for (final f in details.findings) {
          categoryCounts[f.type] = (categoryCounts[f.type] ?? 0) + 1;
        }
      }
      entries.add(
        HistoryEntry(
          id: s.id,
          timestamp: s.createdAt,
          purpose: s.purpose,
          initialExposureScore: s.originalScore,
          finalExposureScore: s.sanitizedScore,
          categoryCounts: categoryCounts,
          itemsRedactedCount: details?.redactions.length ?? 0,
        ),
      );
    }
    return entries;
  }

  @override
  Future<ScanDetails?> getScanDetails(int scanId) async {
    final db = await database;

    final scanRows = await db.query(
      'scans',
      where: 'id = ?',
      whereArgs: [scanId],
    );
    if (scanRows.isEmpty) return null;

    final scan = ScanRecord.fromMap(scanRows.first);

    final findingRows = await db.query(
      'findings',
      where: 'scanId = ?',
      whereArgs: [scanId],
    );
    final redactionRows = await db.query(
      'redactions',
      where: 'scanId = ?',
      whereArgs: [scanId],
    );
    final adviceRows = await db.query(
      'ai_advice',
      where: 'scanId = ?',
      whereArgs: [scanId],
    );

    return ScanDetails(
      scan: scan,
      findings: findingRows.map((m) => FindingRecord.fromMap(m)).toList(),
      redactions: redactionRows.map((m) => RedactionRecord.fromMap(m)).toList(),
      advice: adviceRows.map((m) => AiAdviceRecord.fromMap(m)).toList(),
    );
  }

  @override
  Future<int> deleteScan(int scanId) async {
    final db = await database;

    // Delete any retained image file from app-private storage
    final scanRows = await db.query(
      'scans',
      columns: ['retainedImagePath'],
      where: 'id = ?',
      whereArgs: [scanId],
    );
    if (scanRows.isNotEmpty) {
      final path = scanRows.first['retainedImagePath'] as String?;
      if (path != null && path.isNotEmpty) {
        try {
          final file = File(path);
          if (file.existsSync()) {
            file.deleteSync();
          }
        } catch (e) {
          debugPrint('Error deleting retained image file: $e');
        }
      }
    }

    // Deleting from scans cascades to findings, redactions, and ai_advice
    return await db.delete(
      'scans',
      where: 'id = ?',
      whereArgs: [scanId],
    );
  }

  @override
  Future<int> deleteEntry(int id) async {
    return await deleteScan(id);
  }

  @override
  Future<int> clearAll() async {
    final db = await database;

    // Clean up any retained files
    final scanRows = await db.query('scans', columns: ['retainedImagePath']);
    for (final row in scanRows) {
      final path = row['retainedImagePath'] as String?;
      if (path != null && path.isNotEmpty) {
        try {
          final file = File(path);
          if (file.existsSync()) {
            file.deleteSync();
          }
        } catch (_) {}
      }
    }

    return await db.delete('scans');
  }

  @override
  Future<void> deleteRetainedImage(int scanId) async {
    final db = await database;
    final scanRows = await db.query(
      'scans',
      columns: ['retainedImagePath'],
      where: 'id = ?',
      whereArgs: [scanId],
    );
    if (scanRows.isNotEmpty) {
      final path = scanRows.first['retainedImagePath'] as String?;
      if (path != null && path.isNotEmpty) {
        try {
          final file = File(path);
          if (file.existsSync()) {
            file.deleteSync();
          }
        } catch (e) {
          debugPrint('Error deleting retained image: $e');
        }
      }
    }

    await db.update(
      'scans',
      {'retainedImagePath': null},
      where: 'id = ?',
      whereArgs: [scanId],
    );
  }

  Future<void> close() async {
    if (_db != null && _db!.isOpen) {
      await _db!.close();
      _db = null;
    }
  }
}

/// Web implementation: persists zero data and exposes a clear explanation message.
class WebHistoryRepository implements HistoryRepository {
  const WebHistoryRepository();

  @override
  bool get isSupported => false;

  @override
  String? get unsupportedMessage =>
      'History is not available in web mode. Processing is on-device and in-memory only.';

  @override
  Future<int> insertScan({
    required ScanRecord scan,
    List<FindingRecord> findings = const [],
    List<RedactionRecord> redactions = const [],
    List<AiAdviceRecord> advice = const [],
  }) async => 0;

  @override
  Future<int> insertEntry(HistoryEntry entry) async => 0;

  @override
  Future<List<ScanRecord>> getAllScans() async => [];

  @override
  Future<List<HistoryEntry>> getAllEntries() async => [];

  @override
  Future<ScanDetails?> getScanDetails(int scanId) async => null;

  @override
  Future<int> deleteScan(int scanId) async => 0;

  @override
  Future<int> deleteEntry(int id) async => 0;

  @override
  Future<int> clearAll() async => 0;

  @override
  Future<void> deleteRetainedImage(int scanId) async {}
}

/// In-memory repository for unit tests and environments without platform channels.
class InMemoryHistoryRepository implements HistoryRepository {
  final List<ScanRecord> _scans = [];
  final List<HistoryEntry> _entries = [];
  final Map<int, List<FindingRecord>> _findings = {};
  final Map<int, List<RedactionRecord>> _redactions = {};
  final Map<int, List<AiAdviceRecord>> _advice = {};
  int _nextId = 1;

  @override
  bool get isSupported => true;

  @override
  String? get unsupportedMessage => null;

  @override
  Future<int> insertScan({
    required ScanRecord scan,
    List<FindingRecord> findings = const [],
    List<RedactionRecord> redactions = const [],
    List<AiAdviceRecord> advice = const [],
  }) async {
    final id = scan.id ?? _nextId++;
    final recordWithId = scan.copyWith(id: id);
    _scans.insert(0, recordWithId);

    _findings[id] = findings
        .map((f) => FindingRecord(
              id: f.id ?? _nextId++,
              scanId: id,
              type: f.type,
              maskedPreview: f.maskedPreview,
              x: f.x,
              y: f.y,
              w: f.w,
              h: f.h,
              confidence: f.confidence,
              recommendation: f.recommendation,
              reason: f.reason,
              userAction: f.userAction,
              source: f.source,
            ))
        .toList();

    _redactions[id] = redactions
        .map((r) => RedactionRecord(
              id: r.id ?? _nextId++,
              scanId: id,
              findingId: r.findingId,
              style: r.style,
              applied: r.applied,
              verified: r.verified,
            ))
        .toList();

    _advice[id] = advice
        .map((a) => AiAdviceRecord(
              id: a.id ?? _nextId++,
              scanId: id,
              findingId: a.findingId,
              summary: a.summary,
              model: a.model,
              createdAt: a.createdAt,
            ))
        .toList();

    return id;
  }

  @override
  Future<int> insertEntry(HistoryEntry entry) async {
    final id = entry.id ?? _nextId++;
    final record = entry.copyWith(id: id);
    _entries.insert(0, record);
    return id;
  }

  @override
  Future<List<ScanRecord>> getAllScans() async {
    return List<ScanRecord>.from(_scans);
  }

  @override
  Future<List<HistoryEntry>> getAllEntries() async {
    return List<HistoryEntry>.from(_entries);
  }

  @override
  Future<ScanDetails?> getScanDetails(int scanId) async {
    final index = _scans.indexWhere((s) => s.id == scanId);
    if (index == -1) return null;
    return ScanDetails(
      scan: _scans[index],
      findings: _findings[scanId] ?? [],
      redactions: _redactions[scanId] ?? [],
      advice: _advice[scanId] ?? [],
    );
  }

  @override
  Future<int> deleteScan(int scanId) async {
    final index = _scans.indexWhere((s) => s.id == scanId);
    if (index == -1) return 0;

    final scan = _scans.removeAt(index);
    if (scan.retainedImagePath != null) {
      try {
        final f = File(scan.retainedImagePath!);
        if (f.existsSync()) f.deleteSync();
      } catch (_) {}
    }

    // Cascade deletes in-memory
    _findings.remove(scanId);
    _redactions.remove(scanId);
    _advice.remove(scanId);
    return 1;
  }

  @override
  Future<int> deleteEntry(int id) async {
    final before = _entries.length;
    _entries.removeWhere((e) => e.id == id);
    if (before != _entries.length) return 1;
    return await deleteScan(id);
  }

  @override
  Future<int> clearAll() async {
    final entryCount = _entries.length;
    _entries.clear();
    final count = _scans.length;
    for (final s in _scans) {
      if (s.retainedImagePath != null) {
        try {
          final f = File(s.retainedImagePath!);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
    }
    _scans.clear();
    _findings.clear();
    _redactions.clear();
    _advice.clear();
    return count + entryCount;
  }

  @override
  Future<void> deleteRetainedImage(int scanId) async {
    final index = _scans.indexWhere((s) => s.id == scanId);
    if (index != -1) {
      final s = _scans[index];
      if (s.retainedImagePath != null) {
        try {
          final f = File(s.retainedImagePath!);
          if (f.existsSync()) f.deleteSync();
        } catch (_) {}
      }
      _scans[index] = s.copyWith(clearRetainedImage: true);
    }
  }
}
