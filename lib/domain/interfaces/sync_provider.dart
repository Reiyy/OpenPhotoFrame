abstract class SyncProvider {
  /// Starts the synchronization process.
  /// Returns a stream of progress updates or status messages if needed, 
  /// or just a Future if it's a one-off task.
  Future<void> sync();
  
  /// Returns a unique identifier for this provider (e.g. "nextcloud")
  String get id;
}
