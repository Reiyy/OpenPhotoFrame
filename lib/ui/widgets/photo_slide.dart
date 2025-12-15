import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';

class PhotoSlide extends StatelessWidget {
  final File file;

  const PhotoSlide({
    super.key,
    required this.file,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Blurred Background
        Image.file(
          file,
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
            file,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
        ),
      ],
    );
  }
}
