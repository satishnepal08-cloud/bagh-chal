import 'package:flutter/material.dart';
import 'game_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _goatAnimation;

  @override
  void initState() {
    super.initState();
    _controller =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..repeat(reverse: true);


    _goatAnimation = Tween<double>(begin: 0, end: -10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _animatedImage(String assetPath, Animation<double> animation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, animation.value),
          child: child,
        );
      },
      child: Image.asset(
        assetPath,
        width: 120,
        height: 120,
      ),
    );
  }

  Widget _greenButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: 180,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green[600],
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        child: Text(
          text,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          // Center content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated tiger and goat
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(width: 30),
                    _animatedImage('assets/images/goat_face.png', _goatAnimation),
                  ],
                ),
                const SizedBox(height: 50),
                // Buttons
                _greenButton("Login", () {
                  // Navigate to GameScreen for now
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GameScreen()),
                  );
                }),
                const SizedBox(height: 20),
                _greenButton("Create Account", () {
                  // Navigate to GameScreen for now
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const GameScreen()),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
