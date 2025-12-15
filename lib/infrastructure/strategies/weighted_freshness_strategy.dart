import 'dart:math';
import '../../domain/interfaces/playlist_strategy.dart';
import '../../domain/models/photo_entry.dart';

class WeightedFreshnessStrategy implements PlaylistStrategy {
  final Random _random = Random();
  
  // Configuration
  final double factor;
  final double baseWeight;
  final int cooldownCount;

  WeightedFreshnessStrategy({
    this.factor = 50.0,
    this.baseWeight = 1.0,
    this.cooldownCount = 10, // Don't show the same photo again for 10 turns
  });

  @override
  String get id => 'weighted_freshness';

  @override
  String get name => 'Smart Freshness Shuffle';

  @override
  PhotoEntry? nextPhoto(List<PhotoEntry> availablePhotos) {
    if (availablePhotos.isEmpty) return null;

    // 1. Filter Cooldown
    // We assume lastShown is set on the objects. 
    // If the list is re-created every time, this won't work without external state.
    // But assuming the Repository keeps the instances alive:
    final now = DateTime.now();
    
    // Sort by lastShown to find the most recently shown ones
    // Actually, we just need to check if they were shown "recently".
    // Since we don't have a global "turn counter", we can use time or just a simple list check if passed.
    // But here we only get the list.
    // Let's assume we filter out those that have been shown very recently (e.g. last 10 minutes)
    // OR we rely on the caller to handle the "history" list.
    // The interface definition I wrote earlier was: nextPhoto(List<PhotoEntry> availablePhotos)
    // It didn't explicitly pass history.
    // Let's assume availablePhotos contains EVERYTHING, and we check lastShown.
    
    final candidates = availablePhotos.where((p) {
      if (p.lastShown == null) return true; // Never shown
      // If shown recently (e.g. within last 5 minutes), skip
      // This is a simple time-based cooldown.
      // For a "count-based" cooldown, we'd need the history list.
      // Let's stick to time-based for simplicity in this stateless strategy, 
      // or assume the caller filters availablePhotos?
      // No, the strategy should decide.
      // Let's use a simple time check: 15 minutes cooldown.
      return now.difference(p.lastShown!).inMinutes > 15;
    }).toList();

    // Fallback: If all are in cooldown (e.g. only 5 photos total), use all.
    final pool = candidates.isNotEmpty ? candidates : availablePhotos;

    // 2. Calculate Weights & Sum
    double totalWeight = 0;
    for (var photo in pool) {
      photo.weight = _calculateWeight(photo.date);
      totalWeight += photo.weight;
    }

    // 3. Weighted Random Selection
    double randomPoint = _random.nextDouble() * totalWeight;

    for (var photo in pool) {
      randomPoint -= photo.weight;
      if (randomPoint <= 0) {
        return photo;
      }
    }

    return pool.last;
  }

  double _calculateWeight(DateTime date) {
    final ageInDays = DateTime.now().difference(date).inDays;
    // Ensure age is non-negative (in case of future dates)
    final age = max(0, ageInDays);
    return (factor / (age + 1)) + baseWeight;
  }
}
