import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'export_saver.dart';

class IoExportSaver implements ExportSaver {
  final Directory? targetDirectory;

  const IoExportSaver({this.targetDirectory});

  @override
  Future<String> saveImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    Directory dir = targetDirectory ?? Directory.systemTemp;
    if (targetDirectory == null) {
      try {
        dir = await getApplicationDocumentsDirectory();
      } catch (_) {
        try {
          dir = await getTemporaryDirectory();
        } catch (_) {
          dir = Directory.systemTemp;
        }
      }
    }

    final sanitizedDir = Directory('${dir.path}/overshare_sanitized');
    if (!sanitizedDir.existsSync()) {
      sanitizedDir.createSync(recursive: true);
    }

    final targetFile = File('${sanitizedDir.path}/$fileName');
    await targetFile.writeAsBytes(bytes, flush: true);
    return targetFile.path;
  }
}

ExportSaver createExportSaver() => const IoExportSaver();
