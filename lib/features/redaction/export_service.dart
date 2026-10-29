import 'dart:io' show Directory, File;
import 'package:flutter/foundation.dart';
import 'saver/export_saver.dart';
import 'saver/export_saver_io.dart';

class ExportResult {
  final String fileName;
  final String filePath;
  final int byteSize;
  final String formattedSize;
  final Uint8List bytes;
  final bool isWeb;
  final File? _file;

  File get file => _file ?? File(filePath);

  ExportResult({
    required this.fileName,
    String? filePath,
    File? file,
    required this.byteSize,
    required this.formattedSize,
    Uint8List? bytes,
    this.isWeb = false,
  })  : _file = file,
        filePath = filePath ?? (file != null ? file.path : ''),
        bytes = bytes ?? Uint8List(0);
}

class ExportService {
  final Directory? targetDirectory;
  final ExportSaver saver;

  const ExportService({
    this.targetDirectory,
    this.saver = const _DefaultExportSaverProvider(),
  });

  /// Saves [sanitizedBytes] to a brand new sanitized file or triggers a browser download.
  /// Never modifies or overwrites the original source image.
  Future<ExportResult> saveSanitizedImage(
    Uint8List sanitizedBytes, {
    String extension = 'png',
  }) async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final fileName = 'overshare_safe_$timestamp.$extension';

    final effectiveSaver = saver is _DefaultExportSaverProvider
        ? (targetDirectory != null
            ? IoExportSaver(targetDirectory: targetDirectory)
            : getExportSaver())
        : saver;

    final filePath = await effectiveSaver.saveImage(
      bytes: sanitizedBytes,
      fileName: fileName,
    );

    final byteSize = sanitizedBytes.lengthInBytes;
    final formattedSize = _formatBytes(byteSize);

    return ExportResult(
      fileName: fileName,
      filePath: filePath,
      file: kIsWeb ? null : File(filePath),
      byteSize: byteSize,
      formattedSize: formattedSize,
      bytes: sanitizedBytes,
      isWeb: kIsWeb,
    );
  }

  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }
}

class _DefaultExportSaverProvider implements ExportSaver {
  const _DefaultExportSaverProvider();

  @override
  Future<String> saveImage({required Uint8List bytes, required String fileName}) =>
      getExportSaver().saveImage(bytes: bytes, fileName: fileName);
}
