import 'dart:typed_data';
import 'export_saver_stub.dart'
    if (dart.library.js_interop) 'export_saver_web.dart'
    if (dart.library.io) 'export_saver_io.dart';

abstract class ExportSaver {
  Future<String> saveImage({
    required Uint8List bytes,
    required String fileName,
  });
}

ExportSaver getExportSaver() => createExportSaver();
