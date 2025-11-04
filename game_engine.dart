import 'dart:math';
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
  static const int maxGoats = 18;
  int goatsEaten = 0;

  bool gameOver = false;
  String winner = "";

  List<int> killedGoats = [];
  bool isTigerKilling = false;

  int currentRound = 1;
  int goatsKilledThisRound = 0;
  bool _roundCompleted = false;

  VoidCallback? onSelectToken;
  VoidCallback? onGoatMove;
  VoidCallback? onTigerMove;
  Function(int goatIndex, Offset tigerPos)? onGoatKill;
  Function(int round, int goatsKilled)? onRoundEnd;
  VoidCallback? onBoardUpdate;

  GameEngine({required this.boardSize}) {
    _initializePositions();
    _initializeAdjacency();
  }

  int get unplacedGoats => maxGoats - totalGoatsPlaced;

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
      [1,5,6],
      [0,2,6,7],
      [1,3,6,7,8],
      [2,4,7,8,9],
      [3,8,9],
      [0,6,10,11],
      [0,1,2,5,7,10,11,12],
      [1,2,3,6,8,12,13],
      [2,3,4,7,9,12,13,14],
      [3,4,8,13,14],
      [5,6,11,15,16],
      [5,6,10,12,16],
      [6,7,8,11,13,16,17,18],
      [7,8,9,12,14,17,18,19],
      [8,9,13,18,19],
      [10,16,20,21],
      [10,11,12,15,17,20,21,22],
      [12,13,16,18,22],
      [12,13,14,17,19,22,23,24],
      [13,14,18,23,24],
      [15,16,21],
      [15,16,20,22],
      [16,17,18,21,23],
      [18,19,22,24],
      [18,19,23],
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
    if (gameOver || _roundCompleted) {
      debugPrint('Cannot tap - game over: $gameOver, round completed: $_roundCompleted');
      return;
    }

    Offset snapped = snapToGrid(tap);

    if (tigerTurn) {
      for (int i = 0; i < tigerPositions.length; i++) {
        if (_isTapOnToken(tigerPositions[i], snapped)) {
          selectedTigerIndex = i;
          onSelectToken?.call();
          onBoardUpdate?.call();
          return;
        }
      }

      if (selectedTigerIndex != null && !isTigerKilling) {
        List<Offset> moves = validTigerMoves(selectedTigerIndex!);
        if (moves.contains(snapped)) {
          Offset mid = _middleGoat(tigerPositions[selectedTigerIndex!] , snapped);
          if (mid != Offset.zero && goatPositions.contains(mid)) {
            int goatIdx = goatPositions.indexOf(mid);
            onGoatKill?.call(goatIdx, tigerPositions[selectedTigerIndex!]);
            goatPositions.removeAt(goatIdx);
            goatsEaten++;
            goatsKilledThisRound++;
          }
          tigerPositions[selectedTigerIndex!] = snapped;
          selectedTigerIndex = null;
          
          onTigerMove?.call();
          _checkRoundCompletion();
          onBoardUpdate?.call();
        }
      }
    } else {
      if (totalGoatsPlaced < maxGoats) {
        if (!_isPositionOccupied(snapped)) {
          goatPositions.add(snapped);
          totalGoatsPlaced++;
          
          onGoatMove?.call();
          _checkRoundCompletion();
          onBoardUpdate?.call();
        }
      } else {
        for (int i = 0; i < goatPositions.length; i++) {
          if (_isTapOnToken(goatPositions[i], snapped)) {
            selectedGoat = goatPositions[i];
            onSelectToken?.call();
            onBoardUpdate?.call();
            return;
          }
        }
        if (selectedGoat != null) {
          List<Offset> moves = validGoatMoves();
          if (moves.contains(snapped)) {
            int index = goatPositions.indexOf(selectedGoat!);
            goatPositions[index] = snapped;
            selectedGoat = null;
            
            onGoatMove?.call();
            _checkRoundCompletion();
            onBoardUpdate?.call();
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

  void _checkRoundCompletion() {
    // Don't check if round is already completed
    if (_roundCompleted) return;
    
    // Debug info
    debugPrint('Checking round completion:');
    debugPrint('  Goats eaten: $goatsEaten');
    debugPrint('  Total goats placed: $totalGoatsPlaced');
    debugPrint('  Max goats: $maxGoats');
    debugPrint('  All tigers blocked: ${_allTigersBlocked()}');

    // Round ends when:
    // 1. Tigers eat 5 goats (Tigers win the round)
    if (goatsEaten >= 5) {
      debugPrint('Round completed: Tigers ate 5 goats');
      _completeRound('Tigers Win Round $currentRound!');
      return;
    }
    
    // 2. Goats successfully block all tigers (Goats win the round)
    // BUT only check this after all goats are placed on board
    if (totalGoatsPlaced >= maxGoats) {
      bool allTigersBlocked = _allTigersBlocked();
      debugPrint('All goats placed - Tigers blocked: $allTigersBlocked');
      
      if (allTigersBlocked) {
        debugPrint('Round completed: Goats blocked all tigers');
        _completeRound('Goats Win Round $currentRound!');
        return;
      }
    }

    // 3. Additional condition: If goats can't make any legal moves and all are placed
    if (totalGoatsPlaced >= maxGoats && _allGoatsBlocked()) {
      debugPrint('Round completed: All goats are blocked');
      _completeRound('Tigers Win Round $currentRound!');
      return;
    }

    debugPrint('Round continues - no completion condition met');
  }

  void _completeRound(String roundWinner) {
    if (_roundCompleted) return;
    
    _roundCompleted = true;
    gameOver = true;
    winner = roundWinner;
    
    debugPrint('Round $currentRound completed: $winner - Goats killed: $goatsKilledThisRound');
    
    // Notify about round end with goats killed count
    onRoundEnd?.call(currentRound, goatsKilledThisRound);
    onBoardUpdate?.call();
  }

  bool _allTigersBlocked() {
    for (int i = 0; i < tigerPositions.length; i++) {
      List<Offset> moves = validTigerMoves(i);
      if (moves.isNotEmpty) {
        debugPrint('Tiger $i at ${tigerPositions[i]} can move to: $moves');
        return false;
      }
    }
    debugPrint('All tigers are completely blocked!');
    return true;
  }

  bool _allGoatsBlocked() {
    // Only check if all goats are placed
    if (totalGoatsPlaced < maxGoats) return false;
    
    for (var goat in goatPositions) {
      selectedGoat = goat;
      List<Offset> moves = validGoatMoves();
      selectedGoat = null;
      
      if (moves.isNotEmpty) {
        debugPrint('Goat at $goat can move to: $moves');
        return false;
      }
    }
    debugPrint('All goats are completely blocked!');
    return true;
  }

  void debugGameState() {
    debugPrint('=== GAME STATE DEBUG ===');
    debugPrint('Round: $currentRound');
    debugPrint('Tiger Turn: $tigerTurn');
    debugPrint('Total Goats Placed: $totalGoatsPlaced/$maxGoats');
    debugPrint('Goats Eaten: $goatsEaten');
    debugPrint('Game Over: $gameOver');
    debugPrint('Round Completed: $_roundCompleted');
    debugPrint('Tiger Positions: ${tigerPositions.length}');
    debugPrint('Goat Positions: ${goatPositions.length}');
    
    // Check each tiger's possible moves
    for (int i = 0; i < tigerPositions.length; i++) {
      List<Offset> moves = validTigerMoves(i);
      debugPrint('Tiger $i moves: ${moves.length}');
    }
    
    debugPrint('========================');
  }

  void startNewRound(int round, bool playerIsTiger) {
    currentRound = round;
    goatsKilledThisRound = 0;
    gameOver = false;
    _roundCompleted = false;
    winner = "";
    
    tigerPositions.clear();
    goatPositions.clear();
    selectedTigerIndex = null;
    selectedGoat = null;
    totalGoatsPlaced = 0;
    goatsEaten = 0;
    killedGoats.clear();
    isTigerKilling = false;
    
    _initializePositions();
    tigerTurn = false;
    onBoardUpdate?.call();
  }

  int getGoatsKilledThisRound() {
    return goatsKilledThisRound;
  }

  List<Map<String, dynamic>> getAllPossibleTigerMoves() {
    List<Map<String, dynamic>> allMoves = [];
    for (int i = 0; i < tigerPositions.length; i++) {
      Offset from = tigerPositions[i];
      List<Offset> moves = validTigerMoves(i);
      for (var to in moves) {
        Offset mid = _middleGoat(from, to);
        bool isKill = mid != Offset.zero && goatPositions.contains(mid);
        
        allMoves.add({
          'tigerIndex': i,
          'fromPosition': from,
          'toPosition': to,
          'isKill': isKill,
          'type': isKill ? 'tiger_kill' : 'tiger_move',
          'isValid': true,
        });
      }
    }
    return allMoves;
  }

  List<Map<String, dynamic>> getAllPossibleGoatMoves() {
    List<Map<String, dynamic>> allMoves = [];
    
    if (totalGoatsPlaced < maxGoats) {
      for (var point in gridPoints) {
        if (!_isPositionOccupied(point)) {
          allMoves.add({
            'type': 'goat_place',
            'toPosition': point,
            'isValid': true,
          });
        }
      }
    } else {
      for (int i = 0; i < goatPositions.length; i++) {
        Offset from = goatPositions[i];
        selectedGoat = from;
        List<Offset> moves = validGoatMoves();
        selectedGoat = null;
        
        for (var to in moves) {
          allMoves.add({
            'type': 'goat_move',
            'goatIndex': i,
            'fromPosition': from,
            'toPosition': to,
            'isValid': true,
          });
        }
      }
    }
    return allMoves;
  }

  void executeBotMove(Map<String, dynamic> move) {
    if (move['isValid'] != true || gameOver || _roundCompleted) return;

    switch (move['type']) {
      case 'tiger_move':
      case 'tiger_kill':
        int tigerIndex = move['tigerIndex'];
        Offset toPosition = move['toPosition'];
        
        List<Offset> validMoves = validTigerMoves(tigerIndex);
        if (!validMoves.contains(toPosition)) {
          debugPrint('Invalid tiger move attempted by bot');
          return;
        }
        
        Offset mid = _middleGoat(tigerPositions[tigerIndex], toPosition);
        if (mid != Offset.zero && goatPositions.contains(mid)) {
          int goatIdx = goatPositions.indexOf(mid);
          onGoatKill?.call(goatIdx, tigerPositions[tigerIndex]);
          goatPositions.removeAt(goatIdx);
          goatsEaten++;
          goatsKilledThisRound++;
        }
        
        tigerPositions[tigerIndex] = toPosition;
        selectedTigerIndex = null;
        
        onTigerMove?.call();
        _checkRoundCompletion();
        onBoardUpdate?.call();
        break;

      case 'goat_place':
        Offset toPosition = move['toPosition'];
        
        if (_isPositionOccupied(toPosition)) {
          debugPrint('Invalid goat placement attempted by bot');
          return;
        }
        
        goatPositions.add(toPosition);
        totalGoatsPlaced++;
        onGoatMove?.call();
        _checkRoundCompletion();
        onBoardUpdate?.call();
        break;

      case 'goat_move':
        int goatIndex = move['goatIndex'];
        Offset toPosition = move['toPosition'];
        
        selectedGoat = goatPositions[goatIndex];
        List<Offset> validMoves = validGoatMoves();
        selectedGoat = null;
        
        if (!validMoves.contains(toPosition)) {
          debugPrint('Invalid goat move attempted by bot');
          return;
        }
        
        goatPositions[goatIndex] = toPosition;
        onGoatMove?.call();
        _checkRoundCompletion();
        onBoardUpdate?.call();
        break;
    }
  }

  void reset() {
    currentRound = 1;
    goatsKilledThisRound = 0;
    tigerPositions.clear();
    goatPositions.clear();
    selectedTigerIndex = null;
    selectedGoat = null;
    totalGoatsPlaced = 0;
    goatsEaten = 0;
    gameOver = false;
    _roundCompleted = false;
    winner = "";
    tigerTurn = false;
    killedGoats.clear();
    isTigerKilling = false;
    
    _initializePositions();
    onBoardUpdate?.call();
  }
}
