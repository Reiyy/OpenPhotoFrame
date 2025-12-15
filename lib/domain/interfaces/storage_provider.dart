import 'dart:io';

abstract class StorageProvider {
  /// Returns the directory where photos should be stored.
  Future<Directory> getPhotoDirectory();
}
