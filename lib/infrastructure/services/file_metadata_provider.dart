import 'dart:io';
import '../../domain/interfaces/metadata_provider.dart';

class FileMetadataProvider implements MetadataProvider {
  @override
  Future<DateTime> getDate(File file) async {
    return await file.lastModified();
  }
}
