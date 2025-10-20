import 'package:flutter/material.dart';

class GameEngine {
  static const int gridSize = 5;
  final double boardSize;

  List<Offset> gridPoints = [];
  Map<Offset, List<Offset>> adjacency = {};
  List<Offset> tigerPositions = [];
  List<Offset> goatPositions = [];

  bool tigerTurn = false;
  int? selectedTigerIndex;
  Offset? selectedGoat;

  int totalGoatsPlaced = 0;
  static const int maxGoats = 20;
  int goatsEaten = 0;

  bool gameOver = false;
  String winner = "";

  List<int> killedGoats = [];
  bool isTigerKilling = false;

  // Callbacks
  VoidCallback? onSelectToken;
  VoidCallback? onGoatMove;
  VoidCallback? onTigerMove;
  Function(int goatIndex, Offset tigerPos)? onGoatKill;

  GameEngine({required this.boardSize}) {
    _initializePositions();
    _initializeAdjacency();
  }

  void _initializePositions() {
    double step = boardSize / (gridSize - 1);
    gridPoints = [];
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        gridPoints.add(Offset(j * step, i * step));
      }
    }

    tigerPositions = [
      gridPoints[0],
      gridPoints[gridSize - 1],
      gridPoints[gridSize * (gridSize - 1)],
      gridPoints.last,
    ];

    goatPositions = [];
  }

  void _initializeAdjacency() {
    List<List<int>> connections = [
      [1,5,6],[0,2,6,7],[1,3,7,8],[2,4,8,9],[3,9,8],
      [0,6,10,11],[0,1,5,7,11,12],[1,2,6,8,12,13],[2,3,7,9,13,14],[3,4,8,14,13],
      [5,11,15,16],[5,6,10,12,16,17],[6,7,11,13,17,18],[7,8,12,14,18,19],[8,9,13,19,18],
      [10,16,20,21],[10,11,15,17,21,22],[11,12,16,18,22,23],[12,13,17,19,23,24],[13,14,18,24,23],
      [15,21,16],[15,16,20,22],[16,17,21,23],[17,18,22,24],[18,19,23],
    ];

    List<List<int>> invalidPairs = [
      [1,5],[5,1],[1,7],[7,1],[3,7],[7,3],[3,9],[9,3],
      [5,11],[11,5],[7,11],[11,7],[7,13],[13,7],[9,13],[13,9],
      [11,15],[15,11],[13,17],[17,13],[13,19],[19,13],[15,21],[21,15],
      [17,21],[21,17],[19,23],[23,19],
    ];

    adjacency.clear();
    for (int i = 0; i < gridPoints.length; i++) {
      adjacency[gridPoints[i]] = [];
      for (int j in connections[i]) {
        bool isInvalid = invalidPairs.any((pair) => pair[0] == i && pair[1] == j);
        if (!isInvalid) adjacency[gridPoints[i]]!.add(gridPoints[j]);
      }
    }
  }

  Offset snapToGrid(Offset tapPosition) {
    Offset nearest = gridPoints[0];
    double minDist = (tapPosition - nearest).distance;
    for (var p in gridPoints) {
      double dist = (tapPosition - p).distance;
      if (dist < minDist) {
        minDist = dist;
        nearest = p;
      }
    }
    return nearest;
  }

  bool _isPositionOccupied(Offset pos) {
    for (var t in tigerPositions) if ((t - pos).distance < 1) return true;
    for (var g in goatPositions) if ((g - pos).distance < 1) return true;
    return false;
  }

  bool _isTapOnToken(Offset token, Offset tap, [double threshold = 25]) {
    return (token - tap).distance <= threshold;
  }

  List<Offset> validTigerMoves(int index) {
    Offset from = tigerPositions[index];
    List<Offset> moves = [];
    for (var to in adjacency[from]!) {
      if (!_isPositionOccupied(to)) {
        moves.add(to);
      } else if (goatPositions.contains(to)) {
        Offset? beyond = _dotBeyond(from, to);
        if (beyond != null && !_isPositionOccupied(beyond)) moves.add(beyond);
      }
    }
    return moves;
  }

  List<Offset> validGoatMoves() {
    if (selectedGoat == null) return [];
    List<Offset> moves = [];
    for (var to in adjacency[selectedGoat!]!) {
      if (!_isPositionOccupied(to)) moves.add(to);
    }
    return moves;
  }

  Offset? _dotBeyond(Offset from, Offset goat) {
    double dx = goat.dx - from.dx;
    double dy = goat.dy - from.dy;
    Offset beyond = Offset(goat.dx + dx, goat.dy + dy);
    if (gridPoints.contains(beyond)) return beyond;
    return null;
  }

  void handleTap(Offset tap) {
    if (gameOver) return;

    if (tigerTurn) {
      for (int i = 0; i < tigerPositions.length; i++) {
        if (_isTapOnToken(tigerPositions[i], tap)) {
          selectedTigerIndex = i;
          onSelectToken?.call();
          return;
        }
      }

      if (selectedTigerIndex != null && !isTigerKilling) {
        List<Offset> moves = validTigerMoves(selectedTigerIndex!);
        if (moves.contains(tap)) {
          Offset mid = _middleGoat(tigerPositions[selectedTigerIndex!] , tap);
          if (mid != Offset.zero && goatPositions.contains(mid)) {
            int goatIdx = goatPositions.indexOf(mid);
            onGoatKill?.call(goatIdx, tigerPositions[selectedTigerIndex!]);
            goatsEaten++;
          }
          tigerPositions[selectedTigerIndex!] = tap;
          selectedTigerIndex = null;
          tigerTurn = false;
          onTigerMove?.call();
          _checkGameOver();
        }
      }
    } else {
      if (totalGoatsPlaced < maxGoats) {
        if (!_isPositionOccupied(tap)) {
          goatPositions.add(tap);
          totalGoatsPlaced++;
          tigerTurn = true;
          onGoatMove?.call();
        }
      } else {
        for (int i = 0; i < goatPositions.length; i++) {
          if (_isTapOnToken(goatPositions[i], tap)) {
            selectedGoat = goatPositions[i];
            onSelectToken?.call();
            return;
          }
        }
        if (selectedGoat != null) {
          List<Offset> moves = validGoatMoves();
          if (moves.contains(tap)) {
            int index = goatPositions.indexOf(selectedGoat!);
            goatPositions[index] = tap;
            selectedGoat = null;
            tigerTurn = true;
            onGoatMove?.call();
          }
        }
      }
    }
  }

  Offset _middleGoat(Offset from, Offset to) {
    Offset mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
    for (var g in goatPositions) {
      if ((g - mid).distance < 1) return g;
    }
    return Offset.zero;
  }

  void _checkGameOver() {
    if (goatsEaten >= 5) {
      gameOver = true;
      winner = 'Tiger wins! 🐯';
    } else if (_allTigersBlocked()) {
      gameOver = true;
      winner = 'Goats win! 🐐';
    }
  }

  bool _allTigersBlocked() {
    for (var t in tigerPositions) {
      if (validTigerMoves(tigerPositions.indexOf(t)).isNotEmpty) return false;
    }
    return true;
  }
}
