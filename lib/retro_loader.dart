import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Loader widget: static bg.png behind, car.png spins in the center
/// of the screen around a vertical axis (left-to-right, like a
/// record turning face-on to you), not a flat clockwise spin.
///
/// Usage:
///   Navigator.push(context, MaterialPageRoute(builder: (_) => const RetroLoader()));
/// or just place `const RetroLoader()` anywhere in your widget tree.
///
/// Place your images at:
///   assets/bg.png
///   assets/car.png
/// and register them in pubspec.yaml:
///   flutter:
///     assets:
///       - assets/bg.png
///       - assets/car.png
class RetroLoader extends StatefulWidget {
  const RetroLoader({super.key});

  @override
  State<RetroLoader> createState() => _RetroLoaderState();
}

class _RetroLoaderState extends State<RetroLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _carController;

  @override
  void initState() {
    super.initState();

    // One full left-to-right spin every 3 seconds.
    _carController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _carController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        alignment: Alignment.center,
        children: [
          // Static background, covers the whole screen.
          Positioned.fill(
            child: Image.asset(
              'assets/bg.png',
              fit: BoxFit.cover,
            ),
          ),

          // Car centered on screen, spinning around the vertical (Y) axis.
          Center(
            child: AnimatedBuilder(
              animation: _carController,
              builder: (context, child) {
                final angle = _carController.value * 2 * math.pi;
                return Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..setEntry(3, 2, 0.002) // perspective
                    ..rotateY(angle),
                  child: child,
                );
              },
              child: Image.asset(
                'assets/car.png',
                width: 220,
                height: 220,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
