import 'dart:io';
import 'dart:typed_data';
import 'package:exif/exif.dart';
import 'package:logging/logging.dart';
import '../../domain/interfaces/metadata_provider.dart';

/// MetadataProvider that extracts EXIF data (capture date, GPS) from photos.
/// Only reads the first 64KB of the file for performance (EXIF is at the start).
class ExifMetadataProvider implements MetadataProvider {
  final _log = Logger('ExifMetadataProvider');
  
  /// Maximum bytes to read for EXIF data (64KB should be enough for all EXIF)
  static const int _maxExifBytes = 64 * 1024;

  @override
  Future<ExifMetadata> getExifMetadata(File file) async {
    try {
      // Only read first 64KB - EXIF is always at the start of the file
      final bytes = await _readFirstBytes(file, _maxExifBytes);
      final exifData = await readExifFromBytes(bytes);

      if (exifData.isEmpty) {
        _log.fine('No EXIF data in ${file.path}');
        return const ExifMetadata();
      }

      // Extract capture date (optional)
      final captureDate = _extractCaptureDate(exifData);

      // Extract GPS coordinates (optional)
      final location = _extractGpsCoordinates(exifData);

      return ExifMetadata(captureDate: captureDate, location: location);
    } catch (e) {
      _log.warning('Error reading EXIF from ${file.path}: $e');
      return const ExifMetadata();
    }
  }
  
  /// Reads only the first [maxBytes] from a file
  Future<Uint8List> _readFirstBytes(File file, int maxBytes) async {
    final raf = await file.open(mode: FileMode.read);
    try {
      final length = await raf.length();
      final bytesToRead = length < maxBytes ? length : maxBytes;
      return await raf.read(bytesToRead);
    } finally {
      await raf.close();
    }
  }

  /// Extracts the original capture date from EXIF data.
  DateTime? _extractCaptureDate(Map<String, IfdTag> exifData) {
    // Try DateTimeOriginal first (when photo was taken)
    // Then DateTimeDigitized (when photo was digitized)
    // Then DateTime (file modification time in EXIF)
    final dateTag = exifData['EXIF DateTimeOriginal'] ??
        exifData['EXIF DateTimeDigitized'] ??
        exifData['Image DateTime'];

    if (dateTag == null) return null;

    try {
      // EXIF date format: "2024:12:25 14:30:00"
      final dateString = dateTag.printable;
      return _parseExifDate(dateString);
    } catch (e) {
      _log.fine('Could not parse EXIF date: ${dateTag.printable}');
      return null;
    }
  }

  /// Parses EXIF date format "YYYY:MM:DD HH:MM:SS"
  DateTime? _parseExifDate(String dateString) {
    // Format: "2024:12:25 14:30:00"
    final regex = RegExp(r'(\d{4}):(\d{2}):(\d{2}) (\d{2}):(\d{2}):(\d{2})');
    final match = regex.firstMatch(dateString);

    if (match == null) return null;

    return DateTime(
      int.parse(match.group(1)!), // year
      int.parse(match.group(2)!), // month
      int.parse(match.group(3)!), // day
      int.parse(match.group(4)!), // hour
      int.parse(match.group(5)!), // minute
      int.parse(match.group(6)!), // second
    );
  }

  /// Extracts GPS coordinates from EXIF data.
  GpsCoordinates? _extractGpsCoordinates(Map<String, IfdTag> exifData) {
    final latTag = exifData['GPS GPSLatitude'];
    final latRefTag = exifData['GPS GPSLatitudeRef'];
    final lonTag = exifData['GPS GPSLongitude'];
    final lonRefTag = exifData['GPS GPSLongitudeRef'];

    if (latTag == null || lonTag == null) return null;

    try {
      final latitude = _convertGpsToDecimal(latTag.values, latRefTag?.printable);
      final longitude = _convertGpsToDecimal(lonTag.values, lonRefTag?.printable);

      if (latitude == null || longitude == null) return null;

      return GpsCoordinates(latitude, longitude);
    } catch (e) {
      _log.fine('Could not parse GPS coordinates: $e');
      return null;
    }
  }

  /// Converts GPS coordinates from EXIF format (degrees, minutes, seconds) to decimal.
  double? _convertGpsToDecimal(IfdValues? values, String? ref) {
    if (values == null) return null;

    // GPS values are stored as [degrees, minutes, seconds] as Ratios
    final ratios = values.toList();
    if (ratios.length < 3) return null;

    final degrees = _ratioToDouble(ratios[0]);
    final minutes = _ratioToDouble(ratios[1]);
    final seconds = _ratioToDouble(ratios[2]);

    if (degrees == null || minutes == null || seconds == null) return null;

    double decimal = degrees + (minutes / 60) + (seconds / 3600);

    // South and West are negative
    if (ref == 'S' || ref == 'W') {
      decimal = -decimal;
    }

    return decimal;
  }

  /// Converts a Ratio to double.
  double? _ratioToDouble(dynamic value) {
    if (value is Ratio) {
      if (value.denominator == 0) return null;
      return value.numerator / value.denominator;
    }
    if (value is int) {
      return value.toDouble();
    }
    if (value is double) {
      return value;
    }
    return null;
  }
}
