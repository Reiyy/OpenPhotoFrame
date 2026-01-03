import 'dart:io';

/// Represents GPS coordinates extracted from photo metadata
class GpsCoordinates {
  final double latitude;
  final double longitude;
  
  const GpsCoordinates(this.latitude, this.longitude);
  
  @override
  String toString() => 'GpsCoordinates($latitude, $longitude)';
}

/// Represents EXIF metadata extracted from a photo.
/// All fields are optional since EXIF data may not be present.
class ExifMetadata {
  /// Original capture date from EXIF (DateTimeOriginal)
  final DateTime? captureDate;
  /// GPS coordinates
  final GpsCoordinates? location;
  
  const ExifMetadata({
    this.captureDate,
    this.location,
  });
}

abstract class MetadataProvider {
  /// Extracts EXIF metadata (capture date and GPS) from the photo.
  /// Returns ExifMetadata with null fields if EXIF data is not available.
  Future<ExifMetadata> getExifMetadata(File file);
}
