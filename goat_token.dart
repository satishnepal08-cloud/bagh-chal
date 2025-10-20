import 'package:flutter/material.dart';

class GoatToken extends StatelessWidget {
  final Offset position;
  final bool isDead;

  const GoatToken({super.key, required this.position, this.isDead = false});

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isDead ? 0.0 : 1.0,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white,
          border: Border.all(color: Colors.brown, width: 2),
        ),
        child: const Center(
          child: Text(
            "🐐",
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
