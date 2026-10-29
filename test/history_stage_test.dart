import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:overshare/features/history/history_database.dart';
import 'package:overshare/features/history/history_entry.dart';
import 'package:overshare/features/history/history_providers.dart';
import 'package:overshare/features/history/history_screen.dart';
import 'package:overshare/features/history/models/ai_advice_record.dart';
import 'package:overshare/features/history/models/finding_record.dart';
import 'package:overshare/features/history/models/redaction_record.dart';
import 'package:overshare/features/history/models/scan_record.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('History Privacy & Model Tests', () {
    test('HistoryEntry strictly stores aggregate metadata and NEVER sensitive data', () {
      final now = DateTime.now();
      final entry = HistoryEntry(
        id: 1,
        timestamp: now,
        purpose: 'Payment Proof',
        initialExposureScore: 85,
        finalExposureScore: 0,
        categoryCounts: {
          'Card Number': 1,
          'UPI ID': 2,
          'Phone Number': 1,
        },
        itemsRedactedCount: 4,
      );

      final map = entry.toMap();

      // STRICT PRIVACY VERIFICATIONS:
      // 1. Verify permitted keys only
      final allowedKeys = {
        'id',
        'timestamp',
        'purpose',
        'initial_score',
        'final_score',
        'category_counts',
        'items_redacted_count',
      };
      expect(map.keys.toSet(), equals(allowedKeys));

      // 2. Prohibit image data, paths, or extracted texts
      expect(map.containsKey('image'), isFalse);
      expect(map.containsKey('image_bytes'), isFalse);
      expect(map.containsKey('file_path'), isFalse);
      expect(map.containsKey('original_path'), isFalse);
      expect(map.containsKey('text'), isFalse);
      expect(map.containsKey('extracted_text'), isFalse);
      expect(map.containsKey('matched_text'), isFalse);

      // 3. Deserialization
      final restored = HistoryEntry.fromMap(map);
      expect(restored.id, 1);
      expect(restored.purpose, 'Payment Proof');
      expect(restored.initialExposureScore, 85);
      expect(restored.finalExposureScore, 0);
      expect(restored.itemsRedactedCount, 4);
      expect(restored.categoryCounts['Card Number'], 1);
      expect(restored.categoryCounts['UPI ID'], 2);
      expect(restored.totalFindingsDetected, 4);
    });

    test('ScanRecord and FindingRecord never store unmasked sensitive data', () {
      final finding = FindingRecord(
        scanId: 1,
        type: 'Aadhaar',
        maskedPreview: 'XXXX-XXXX-1234',
        x: 10,
        y: 20,
        w: 100,
        h: 30,
        confidence: 0.95,
        recommendation: 'HIDE',
        reason: 'Sensitive National ID',
        userAction: 'REDACT',
        source: 'ocr',
      );

      final map = finding.toMap();
      expect(map['maskedPreview'], 'XXXX-XXXX-1234');
      expect(map.containsKey('rawText'), isFalse);
      expect(map.containsKey('sensitiveValue'), isFalse);
    });

    test('InMemoryHistoryRepository insert, getAll, deleteEntry, clearAll', () async {
      final repo = InMemoryHistoryRepository();

      // Initially empty
      expect(await repo.getAllEntries(), isEmpty);

      // Insert 2 entries
      final id1 = await repo.insertEntry(
        HistoryEntry(
          timestamp: DateTime.now(),
          purpose: 'Payment Proof',
          initialExposureScore: 70,
          categoryCounts: {'Card Number': 1},
          itemsRedactedCount: 1,
        ),
      );
      final id2 = await repo.insertEntry(
        HistoryEntry(
          timestamp: DateTime.now(),
          purpose: 'Social Media',
          initialExposureScore: 40,
          categoryCounts: {'Phone Number': 1},
          itemsRedactedCount: 1,
        ),
      );

      expect(id1, isNotNull);
      expect(id2, isNotNull);

      var all = await repo.getAllEntries();
      expect(all.length, 2);
      expect(all.first.purpose, 'Social Media'); // Most recent first

      // Delete one
      final deletedCount = await repo.deleteEntry(id1);
      expect(deletedCount, 1);

      all = await repo.getAllEntries();
      expect(all.length, 1);
      expect(all.first.id, id2);

      // Clear all
      final cleared = await repo.clearAll();
      expect(cleared, 1);
      expect(await repo.getAllEntries(), isEmpty);
    });
  });

  group('SQLite Relational Schema, CRUD, Foreign Keys & Migrations', () {
    late Database testDb;
    late SqfliteHistoryDatabase historyDb;

    setUp(() async {
      testDb = await openDatabase(
        inMemoryDatabasePath,
        version: SqfliteHistoryDatabase.currentVersion,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onCreate: (db, version) async {
          await SqfliteHistoryDatabase.createV2Schema(db);
        },
      );
      historyDb = SqfliteHistoryDatabase(testDb);
    });

    tearDown(() async {
      await testDb.close();
    });

    test('Insert scan with findings, redactions, advice and retrieve details', () async {
      final scan = ScanRecord(
        createdAt: DateTime.now(),
        purpose: 'Payment Proof',
        audience: 'Private Recipient',
        originalScore: 85,
        sanitizedScore: 0,
        status: 'sanitized',
        verificationStatus: 'verified',
      );

      final findings = [
        FindingRecord(
          scanId: 0,
          type: 'Card Number',
          maskedPreview: '**** **** **** 1234',
          x: 10,
          y: 20,
          w: 120,
          h: 40,
          confidence: 0.99,
          recommendation: 'HIDE',
          reason: 'Exposes financial account',
          userAction: 'REDACT',
          source: 'rule',
        ),
        FindingRecord(
          scanId: 0,
          type: 'Phone Number',
          maskedPreview: '+91 98765*****',
          x: 10,
          y: 70,
          w: 100,
          h: 30,
          confidence: 0.90,
          recommendation: 'OPTIONAL',
          reason: 'Direct contact info',
          userAction: 'REDACT',
          source: 'ocr',
        ),
      ];

      final redactions = [
        RedactionRecord(
          scanId: 0,
          findingId: null,
          style: 'pixelate',
          applied: true,
          verified: true,
        ),
      ];

      final advice = [
        AiAdviceRecord(
          scanId: 0,
          findingId: null,
          summary: 'Redact card number to prevent fraud.',
          model: 'rule-engine',
          createdAt: DateTime.now(),
        ),
      ];

      final scanId = await historyDb.insertScan(
        scan: scan,
        findings: findings,
        redactions: redactions,
        advice: advice,
      );

      expect(scanId, greaterThan(0));

      // Verify list
      final allScans = await historyDb.getAllScans();
      expect(allScans.length, 1);
      expect(allScans.first.purpose, 'Payment Proof');
      expect(allScans.first.originalScore, 85);
      expect(allScans.first.sanitizedScore, 0);

      // Verify details
      final details = await historyDb.getScanDetails(scanId);
      expect(details, isNotNull);
      expect(details!.scan.id, scanId);
      expect(details.findings.length, 2);
      expect(details.findings.first.type, 'Card Number');
      expect(details.findings.first.maskedPreview, '**** **** **** 1234');
      expect(details.redactions.length, 1);
      expect(details.redactions.first.style, 'pixelate');
      expect(details.advice.length, 1);
      expect(details.advice.first.summary, contains('card number'));
    });

    test('Foreign key ON DELETE CASCADE automatically removes child findings and redactions', () async {
      final scanId = await historyDb.insertScan(
        scan: ScanRecord(
          createdAt: DateTime.now(),
          purpose: 'College Submission',
          audience: 'Public',
          originalScore: 60,
          sanitizedScore: 10,
          status: 'sanitized',
          verificationStatus: 'verified',
        ),
        findings: [
          FindingRecord(
            scanId: 0,
            type: 'Email',
            maskedPreview: 's****@univ.edu',
            x: 0,
            y: 0,
            w: 50,
            h: 20,
            confidence: 0.95,
            recommendation: 'KEEP',
            reason: 'Legitimate identification',
            userAction: 'KEEP',
            source: 'ocr',
          ),
        ],
        redactions: [
          RedactionRecord(
            scanId: 0,
            findingId: null,
            style: 'solid',
            applied: true,
            verified: true,
          ),
        ],
      );

      // Verify child rows exist before delete
      final rawFindingsBefore = await testDb.query(
        'findings',
        where: 'scanId = ?',
        whereArgs: [scanId],
      );
      final rawRedactionsBefore = await testDb.query(
        'redactions',
        where: 'scanId = ?',
        whereArgs: [scanId],
      );
      expect(rawFindingsBefore.length, 1);
      expect(rawRedactionsBefore.length, 1);

      // Delete scan
      final deleted = await historyDb.deleteScan(scanId);
      expect(deleted, 1);

      // Verify scan is gone
      expect(await historyDb.getAllScans(), isEmpty);

      // Verify CASCADE deleted findings and redactions
      final rawFindingsAfter = await testDb.query(
        'findings',
        where: 'scanId = ?',
        whereArgs: [scanId],
      );
      final rawRedactionsAfter = await testDb.query(
        'redactions',
        where: 'scanId = ?',
        whereArgs: [scanId],
      );
      expect(rawFindingsAfter, isEmpty);
      expect(rawRedactionsAfter, isEmpty);
    });

    test('v1 -> v2 Schema Migration preserves legacy history into scans table', () async {
      final tempDir = Directory.systemTemp.createTempSync('overshare_migration_');
      final dbPath = p.join(tempDir.path, 'migration_test.db');

      // 1. Create a fresh db at v1
      final v1Db = await openDatabase(
        dbPath,
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE scan_history (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              timestamp TEXT NOT NULL,
              purpose TEXT NOT NULL,
              initial_score INTEGER NOT NULL,
              final_score INTEGER NOT NULL,
              category_counts TEXT NOT NULL,
              items_redacted_count INTEGER NOT NULL
            );
          ''');
        },
      );

      // Insert legacy v1 entry
      await v1Db.insert('scan_history', {
        'timestamp': DateTime.now().toIso8601String(),
        'purpose': 'Bank Dispute',
        'initial_score': 90,
        'final_score': 10,
        'category_counts': '{"Aadhaar": 1}',
        'items_redacted_count': 1,
      });

      // Verify legacy v1 row exists
      final v1Rows = await v1Db.query('scan_history');
      expect(v1Rows.length, 1);
      await v1Db.close();

      // 2. Re-open at v2 with migration logic
      final v2Db = await openDatabase(
        dbPath,
        version: 2,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON;');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await SqfliteHistoryDatabase.migrateV1ToV2(db);
          }
        },
      );

      final migratedRepo = SqfliteHistoryDatabase(v2Db);
      final allScans = await migratedRepo.getAllScans();

      expect(allScans.length, 1);
      expect(allScans.first.purpose, 'Bank Dispute');
      expect(allScans.first.originalScore, 90);
      expect(allScans.first.sanitizedScore, 10);
      expect(allScans.first.verificationStatus, 'legacy_migrated');

      // Verify new relational tables are functional in migrated database
      await v2Db.insert('findings', {
        'scanId': allScans.first.id,
        'type': 'Aadhaar',
        'maskedPreview': 'XXXX-XXXX-9999',
        'x': 0.0,
        'y': 0.0,
        'w': 100.0,
        'h': 30.0,
        'confidence': 0.95,
        'recommendation': 'HIDE',
        'reason': 'National ID',
        'userAction': 'REDACT',
        'source': 'ocr',
      });

      final findings = await v2Db.query('findings');
      expect(findings.length, 1);

      await v2Db.close();
      tempDir.deleteSync(recursive: true);
    });

    test('deleteRetainedImage removes image file and resets column to null', () async {
      final tempDir = Directory.systemTemp.createTempSync('overshare_test_');
      final testFile = File('${tempDir.path}/retained_test.png');
      testFile.writeAsStringSync('dummy_image_data');
      expect(testFile.existsSync(), isTrue);

      final scanId = await historyDb.insertScan(
        scan: ScanRecord(
          createdAt: DateTime.now(),
          purpose: 'General',
          audience: 'Private',
          originalScore: 50,
          sanitizedScore: 0,
          status: 'sanitized',
          verificationStatus: 'verified',
          retainedImagePath: testFile.path,
        ),
      );

      expect(testFile.existsSync(), isTrue);

      // Call deleteRetainedImage
      await historyDb.deleteRetainedImage(scanId);

      // Verify physical file was removed
      expect(testFile.existsSync(), isFalse);

      // Verify DB record now has retainedImagePath = null
      final updatedDetails = await historyDb.getScanDetails(scanId);
      expect(updatedDetails?.scan.retainedImagePath, isNull);
      expect(updatedDetails?.scan.hasRetainedImage, isFalse);

      tempDir.deleteSync(recursive: true);
    });

    test('WebHistoryRepository reports unsupported and returns clear message', () async {
      final webRepo = WebHistoryRepository();
      expect(webRepo.isSupported, isFalse);
      expect(
        webRepo.unsupportedMessage,
        'History is not available in web mode. Processing is on-device and in-memory only.',
      );
      expect(await webRepo.getAllScans(), isEmpty);
      expect(await webRepo.getScanDetails(1), isNull);
      expect(await webRepo.insertScan(scan: ScanRecord(
        createdAt: DateTime.now(),
        purpose: 'Test',
        audience: 'Test',
        originalScore: 0,
        sanitizedScore: 0,
        status: 'test',
        verificationStatus: 'test',
      )), 0);
    });
  });

  group('HistoryScreen Widget Tests', () {
    testWidgets('Displays empty state when no scan history exists', (tester) async {
      final inMemoryRepo = InMemoryHistoryRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            historyRepositoryProvider.overrideWithValue(inMemoryRepo),
          ],
          child: const MaterialApp(
            home: HistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Scan History'), findsOneWidget);
      expect(find.text('No Scan History Yet'), findsOneWidget);
      expect(
        find.textContaining('Strict Privacy Guarantee: No images, file paths'),
        findsOneWidget,
      );
    });

    testWidgets('Renders scan history entries with score and purpose badges', (tester) async {
      final inMemoryRepo = InMemoryHistoryRepository();
      await inMemoryRepo.insertEntry(
        HistoryEntry(
          id: 101,
          timestamp: DateTime.now(),
          purpose: 'Payment Proof',
          initialExposureScore: 80,
          finalExposureScore: 0,
          categoryCounts: {'Card Number': 1, 'UPI ID': 1},
          itemsRedactedCount: 2,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            historyRepositoryProvider.overrideWithValue(inMemoryRepo),
          ],
          child: const MaterialApp(
            home: HistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Payment Proof'), findsOneWidget);
      expect(find.text('80'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('2 redacted'), findsOneWidget);
      expect(find.text('Card Number: 1'), findsOneWidget);
      expect(find.text('UPI ID: 1'), findsOneWidget);

      // Verify clear all button in AppBar
      expect(find.byIcon(Icons.delete_sweep_rounded), findsOneWidget);

      // Tap delete on item
      await tester.tap(find.byIcon(Icons.delete_outline_rounded));
      await tester.pumpAndSettle();

      // Should now show empty state
      expect(find.text('No Scan History Yet'), findsOneWidget);
    });

    testWidgets('Displays Web Mode Unsupported Banner when repo is unsupported', (tester) async {
      final webRepo = WebHistoryRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            historyRepositoryProvider.overrideWithValue(webRepo),
          ],
          child: const MaterialApp(
            home: HistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Web Mode — History Disabled'), findsOneWidget);
      expect(
        find.textContaining('History is not available in web mode'),
        findsOneWidget,
      );
    });
  });
}
