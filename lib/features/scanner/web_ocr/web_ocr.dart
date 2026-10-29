import '../models/ocr_line.dart';
import 'web_ocr_stub.dart'
    if (dart.library.js_interop) 'web_ocr_impl.dart';

Future<List<OcrLine>> runWebOcr(String imageSource) => runWebOcrImpl(imageSource);
