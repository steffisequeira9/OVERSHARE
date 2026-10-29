import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

@immutable
class MetadataItem {
  final String category;
  final String label;
  final String value;
  final bool isSensitive;

  const MetadataItem({
    required this.category,
    required this.label,
    required this.value,
    this.isSensitive = true,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MetadataItem &&
          runtimeType == other.runtimeType &&
          category == other.category &&
          label == other.label &&
          value == other.value &&
          isSensitive == other.isSensitive;

  @override
  int get hashCode => Object.hash(category, label, value, isSensitive);

  @override
  String toString() => '$category - $label: $value';
}

class MetadataService {
  const MetadataService();

  /// Extracts EXIF metadata items from [imageBytes].
  List<MetadataItem> extractMetadata(Uint8List imageBytes) {
    final List<MetadataItem> items = [];

    try {
      final image = img.decodeImage(imageBytes);
      if (image == null) return items;

      final exif = image.exif;

      // 1. Device Info
      final make = _getExifString(exif, 0x010F) ?? exif.imageIfd['Make']?.toString();
      final model = _getExifString(exif, 0x0110) ?? exif.imageIfd['Model']?.toString();
      final software = _getExifString(exif, 0x0131) ?? exif.imageIfd['Software']?.toString();

      if (make != null && make.isNotEmpty) {
        items.add(MetadataItem(
          category: 'Device Hardware',
          label: 'Manufacturer',
          value: make,
          isSensitive: false,
        ));
      }
      if (model != null && model.isNotEmpty) {
        items.add(MetadataItem(
          category: 'Device Hardware',
          label: 'Device Model',
          value: model,
          isSensitive: true,
        ));
      }
      if (software != null && software.isNotEmpty) {
        items.add(MetadataItem(
          category: 'System',
          label: 'Software / OS',
          value: software,
          isSensitive: false,
        ));
      }

      // 2. Timestamps
      final dt = _getExifString(exif, 0x0132) ??
          _getExifString(exif, 0x9003) ??
          exif.imageIfd['DateTime']?.toString();
      if (dt != null && dt.isNotEmpty) {
        items.add(MetadataItem(
          category: 'Timestamp',
          label: 'Capture Date/Time',
          value: dt,
          isSensitive: true,
        ));
      }

      // 3. GPS Coordinates
      if (exif.gpsIfd.data.isNotEmpty) {
        final lat = exif.gpsIfd.data[0x0002]?.toString() ?? 'Present';
        final lon = exif.gpsIfd.data[0x0004]?.toString() ?? 'Present';
        items.add(MetadataItem(
          category: 'Location (GPS)',
          label: 'Latitude / Longitude',
          value: '$lat, $lon',
          isSensitive: true,
        ));
        if (exif.gpsIfd.data.containsKey(0x0006)) {
          items.add(MetadataItem(
            category: 'Location (GPS)',
            label: 'Altitude',
            value: '${exif.gpsIfd.data[0x0006]} m',
            isSensitive: true,
          ));
        }
      }

      // Check generic IFD tags if standard fields were empty
      if (items.isEmpty) {
        for (final entry in exif.imageIfd.data.entries) {
          final tagValue = entry.value.toString();
          if (tagValue.isNotEmpty && tagValue != 'null') {
            items.add(
              MetadataItem(
                category: 'Camera / EXIF',
                label: 'Tag 0x${entry.key.toRadixString(16).toUpperCase()}',
                value: tagValue,
                isSensitive: false,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Metadata extraction warning: $e');
    }

    return items;
  }

  String? _getExifString(img.ExifData exif, int tag) {
    if (exif.imageIfd.containsKey(tag)) {
      return exif.imageIfd[tag]?.toString();
    }
    if (exif.exifIfd.containsKey(tag)) {
      return exif.exifIfd[tag]?.toString();
    }
    return null;
  }

  /// Verifies that no EXIF metadata or header markers exist in [imageBytes].
  bool verifyExifStripped(Uint8List imageBytes) {
    // 1. Image decoder EXIF check
    try {
      final image = img.decodeImage(imageBytes);
      if (image != null) {
        if (image.exif.imageIfd.data.isNotEmpty ||
            image.exif.exifIfd.data.isNotEmpty ||
            image.exif.gpsIfd.data.isNotEmpty) {
          return false;
        }
      }
    } catch (_) {}

    // 2. Raw JPEG EXIF marker scan: 0xFF, 0xE1 (APP1) followed by "Exif\0\0"
    if (imageBytes.length > 10) {
      for (int i = 0; i < imageBytes.length - 8; i++) {
        if (imageBytes[i] == 0xFF && imageBytes[i + 1] == 0xE1) {
          // Check for 'Exif' ASCII header (69, 120, 105, 102)
          if (imageBytes[i + 4] == 0x45 &&
              imageBytes[i + 5] == 0x78 &&
              imageBytes[i + 6] == 0x69 &&
              imageBytes[i + 7] == 0x66) {
            return false;
          }
        }
      }
    }

    return true;
  }
}
