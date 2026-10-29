import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';
import 'export_saver.dart';

@JS('overshareDownloadFile')
external JSString _overshareDownloadFile(
  JSString base64Data,
  JSString fileName,
  JSString mimeType,
);

class WebExportSaver implements ExportSaver {
  const WebExportSaver();

  @override
  Future<String> saveImage({
    required Uint8List bytes,
    required String fileName,
  }) async {
    try {
      final base64Str = base64Encode(bytes);
      final jsBlobUrl = _overshareDownloadFile(
        base64Str.toJS,
        fileName.toJS,
        'image/png'.toJS,
      );
      final blobUrl = jsBlobUrl.toDart;
      return blobUrl.isNotEmpty ? blobUrl : 'Browser Download ($fileName)';
    } catch (_) {
      return 'Browser Download ($fileName)';
    }
  }
}

ExportSaver createExportSaver() => const WebExportSaver();
