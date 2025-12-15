import 'dart:io';

class PhotoEntry {
  final File file;
  final DateTime date;
  final int sizeBytes;
  
  // Runtime properties (not persisted)
  double weight = 0;
  DateTime? lastShown;

  PhotoEntry({
    required this.file,
    required this.date,
    required this.sizeBytes,
  });

  @override
  String toString() => 'PhotoEntry(path: ${file.path}, date: $date)';
}
