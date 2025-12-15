import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../infrastructure/services/photo_service.dart';
import '../../domain/models/photo_entry.dart';
import '../widgets/photo_slide.dart';

class SlideshowScreen extends StatefulWidget {
  const SlideshowScreen({super.key});

  @override
  State<SlideshowScreen> createState() => _SlideshowScreenState();
}

class _SlideshowScreenState extends State<SlideshowScreen> {
  PhotoEntry? _currentPhoto;
  Timer? _timer;
  bool _isLoading = true;
  StreamSubscription? _photosSubscription;

  @override
  void initState() {
    super.initState();
    // Keep screen on (Safe implementation for Linux/Dev)
    _enableWakelock();
    
    // Initialize Service
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initService();
    });
  }

  Future<void> _enableWakelock() async {
    try {
      await WakelockPlus.enable();
    } catch (e) {
      print("Wakelock not supported or failed on this platform (ignoring): $e");
    }
  }

  Future<void> _initService() async {
    final service = context.read<PhotoService>();
    
    // Listen for updates
    _photosSubscription = service.onPhotosChanged.listen((_) {
      if (mounted) {
        // If we were loading or showing "No photos", try to start slideshow
        if (_isLoading || _currentPhoto == null) {
           final next = service.nextPhoto();
           if (next != null) {
             setState(() {
               _isLoading = false;
               _currentPhoto = next;
             });
             _startTimer();
           }
        }
      }
    });

    await service.initialize();
    
    // Initial check
    final firstPhoto = service.nextPhoto();
    if (mounted) {
      setState(() {
        _isLoading = false;
        _currentPhoto = firstPhoto;
      });
      if (_currentPhoto != null) {
        _startTimer();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _nextSlide();
    });
  }

  Future<void> _nextSlide() async {
    final service = context.read<PhotoService>();
    final photo = service.nextPhoto();
    
    if (photo != null && photo.file.path != _currentPhoto?.file.path) {
      // Precache to avoid loading gap
      await precacheImage(FileImage(photo.file), context);
      
      if (mounted) {
        setState(() {
          _currentPhoto = photo;
        });
      }
    }
  }

  Future<void> _manualNavigation(bool forward) async {
    _timer?.cancel(); // Stop auto-advance
    
    final service = context.read<PhotoService>();
    final photo = forward ? service.nextPhoto() : service.previousPhoto();
    
    if (photo != null) {
      // Precache
      await precacheImage(FileImage(photo.file), context);
      
      if (mounted) {
        setState(() {
          _currentPhoto = photo;
        });
      }
    }
    
    // Restart timer after interaction
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _photosSubscription?.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_currentPhoto == null) {
      return const Scaffold(
        body: Center(
          child: Text(
            "No photos found.\nWaiting for sync...",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white),
          ),
        ),
      );
    }

    return Scaffold(
      body: GestureDetector(
        behavior: HitTestBehavior.opaque, // Ensure gestures are captured on the whole screen
        onTapUp: (details) {
          final width = MediaQuery.of(context).size.width;
          if (details.globalPosition.dx > width * 0.75) {
            _manualNavigation(true); // Right 25% -> Next
          } else if (details.globalPosition.dx < width * 0.25) {
            _manualNavigation(false); // Left 25% -> Previous
          }
        },
        onHorizontalDragEnd: (details) {
          if (details.primaryVelocity! < 0) {
            _manualNavigation(true); // Swipe Left -> Next
          } else if (details.primaryVelocity! > 0) {
            _manualNavigation(false); // Swipe Right -> Previous
          }
        },
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 800),
          layoutBuilder: (currentChild, previousChildren) {
            return Stack(
              fit: StackFit.expand,
              children: [
                ...previousChildren,
                if (currentChild != null) currentChild,
              ],
            );
          },
          transitionBuilder: (Widget child, Animation<double> animation) {
            // "Keep Old Opaque" Strategy:
            // The new slide fades in (0 -> 1).
            // The old slide stays at 1.0 until it is removed.
            // Since PhotoSlide is fully opaque (due to the blurred background),
            // this creates a perfect cross-dissolve without dipping to black.
            final isNew = child.key == ValueKey(_currentPhoto!.file.path);
            return FadeTransition(
              opacity: isNew ? animation : const AlwaysStoppedAnimation(1.0),
              child: child,
            );
          },
          child: _buildPhotoSlide(_currentPhoto!),
        ),
      ),
    );
  }

  Widget _buildPhotoSlide(PhotoEntry photo) {
    return Stack(
      key: ValueKey(photo.file.path),
      fit: StackFit.expand,
      children: [
        // 1. Blurred Background
        Image.file(
          photo.file,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        ),
        BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            color: Colors.black.withOpacity(0.4),
          ),
        ),
        
        // 2. Main Image
        Center(
          child: Image.file(
            photo.file,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        ),
        
        // 3. Debug Info (Optional)
        Positioned(
          bottom: 20,
          right: 20,
          child: Text(
            photo.date.toString().split('.')[0],
            style: const TextStyle(
              color: Colors.white54, 
              fontSize: 12,
              shadows: [Shadow(blurRadius: 2, color: Colors.black)],
            ),
          ),
        ),
      ],
    );
  }
}



