import 'package:flutter/material.dart';

class ValidMoveIndicator extends StatelessWidget {
  final Offset position;

  const ValidMoveIndicator({super.key, required this.position});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.green.withOpacity(0.5),
      ),
    );
  }
}
