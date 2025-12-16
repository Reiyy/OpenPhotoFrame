abstract class SyncProvider {
  /// Starts the synchronization process.
  /// If [deleteOrphanedFiles] is true, local files not present on the server will be deleted.
  Future<void> sync({bool deleteOrphanedFiles = false});
  
  /// Returns a unique identifier for this provider (e.g. "nextcloud")
  String get id;
}
