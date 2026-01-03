import 'dart:io';
import '../../domain/interfaces/metadata_provider.dart';

/// Simple MetadataProvider that returns no EXIF data.
/// Used as fallback or for platforms where EXIF parsing is not needed.
class FileMetadataProvider implements MetadataProvider {
  @override
  Future<ExifMetadata> getExifMetadata(File file) async {
    // File system has no EXIF information
    return const ExifMetadata();
  }
}
