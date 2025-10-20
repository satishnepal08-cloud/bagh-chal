import 'package:flutter/material.dart';

class TigerToken extends StatelessWidget {
  final Offset position;
  final bool highlight;
  final bool isKillingMove;

  const TigerToken({
    super.key,
    required this.position,
    this.highlight = false,
    this.isKillingMove = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: highlight ? Colors.orangeAccent : Colors.orange,
        border: highlight
            ? Border.all(color: Colors.greenAccent, width: 3)
            : null,
        boxShadow: isKillingMove
            ? [
                BoxShadow(
                  color: Colors.redAccent.withOpacity(0.6),
                  blurRadius: 8,
                  spreadRadius: 2,
                )
              ]
            : [],
      ),
      child: Center(
        child: Text(
          "🐯",
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }
}
