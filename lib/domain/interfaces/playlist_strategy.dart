import '../models/photo_entry.dart';

abstract class PlaylistStrategy {
  /// Selects the next photo to display from the list of available photos.
  /// [availablePhotos] is the list of all photos on the device.
  /// [history] is a list of recently shown photos (optional context).
  PhotoEntry? nextPhoto(List<PhotoEntry> availablePhotos);
  
  /// Returns a unique identifier for this strategy (e.g. "weighted_freshness")
  String get id;
  
  /// Returns a human readable name (e.g. "Smart Shuffle")
  String get name;
}
