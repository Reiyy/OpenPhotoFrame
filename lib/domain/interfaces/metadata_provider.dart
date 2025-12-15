import 'dart:io';

abstract class MetadataProvider {
  /// Extracts the relevant date for the photo (e.g. creation date, upload date).
  Future<DateTime> getDate(File file);
}
