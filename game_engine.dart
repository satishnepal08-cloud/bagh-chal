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
  bool get roundCompleted => _roundCompleted;

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
    
    // Regular adjacent moves
    for (var to in adjacency[from]!) {
      if (!_isPositionOccupied(to)) {
        moves.add(to);
      }
    }
    
    // Killing moves (jump over goats)
    for (var adjacent in adjacency[from]!) {
      // Check if adjacent position has a goat
      bool hasGoat = goatPositions.any((goat) => (goat - adjacent).distance < 2.0);
      
      if (hasGoat) {
        Offset? jumpPos = _getJumpPosition(from, adjacent);
        if (jumpPos != null && !_isPositionOccupied(jumpPos)) {
          moves.add(jumpPos);
        }
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

  Offset? _getJumpPosition(Offset from, Offset goat) {
    // Calculate direction vector
    double dx = goat.dx - from.dx;
    double dy = goat.dy - from.dy;
    
    // Calculate position beyond the goat
    Offset beyond = Offset(goat.dx + dx, goat.dy + dy);
    
    // Check if beyond position is valid (exists on board and not occupied)
    bool isValid = gridPoints.any((point) => (point - beyond).distance < 2.0);
    
    if (isValid) {
      return beyond;
    } else {
      return null;
    }
  }

  void handleTap(Offset tap) {
    if (gameOver || _roundCompleted) {
      return;
    }

    Offset snapped = snapToGrid(tap);

    if (tigerTurn) {
      _handleTigerTap(snapped);
    } else {
      _handleGoatTap(snapped);
    }
  }

  void _handleTigerTap(Offset snapped) {
    // Select tiger
    for (int i = 0; i < tigerPositions.length; i++) {
      if (_isTapOnToken(tigerPositions[i], snapped)) {
        selectedTigerIndex = i;
        onSelectToken?.call();
        onBoardUpdate?.call();
        return;
      }
    }

    // Move selected tiger
    if (selectedTigerIndex != null && !isTigerKilling) {
      List<Offset> moves = validTigerMoves(selectedTigerIndex!);
      if (moves.contains(snapped)) {
        _executeTigerMove(selectedTigerIndex!, snapped);
      }
    }
  }

  void _handleGoatTap(Offset snapped) {
    // Place new goat
    if (totalGoatsPlaced < maxGoats) {
      if (!_isPositionOccupied(snapped)) {
        goatPositions.add(snapped);
        totalGoatsPlaced++;
        onGoatMove?.call();
        _checkRoundCompletion();
        onBoardUpdate?.call();
      }
    } else {
      // Select goat for movement
      for (int i = 0; i < goatPositions.length; i++) {
        if (_isTapOnToken(goatPositions[i], snapped)) {
          selectedGoat = goatPositions[i];
          onSelectToken?.call();
          onBoardUpdate?.call();
          return;
        }
      }
      
      // Move selected goat
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

  void _executeTigerMove(int tigerIndex, Offset toPosition) {
    Offset fromPosition = tigerPositions[tigerIndex];
    
    // Check if this is a killing move using adjacency
    bool isKillingMove = _isKillingMove(fromPosition, toPosition);
    
    if (isKillingMove) {
      // CRITICAL FIX: Set isTigerKilling flag BEFORE the kill callback
      isTigerKilling = true;
      
      Offset? killedGoatPosition = _getKilledGoatPosition(fromPosition, toPosition);
      
      if (killedGoatPosition != null) {
        int goatIndex = goatPositions.indexOf(killedGoatPosition);
        
        if (goatIndex != -1) {
          // CRITICAL FIX: INCREMENT COUNTERS FIRST before anything else
          goatsEaten++;
          goatsKilledThisRound++;
          
          print('=== GOAT KILLED ===');
          print('goatsEaten: $goatsEaten');
          print('goatsKilledThisRound: $goatsKilledThisRound');
          print('goatPositions before remove: ${goatPositions.length}');
          
          // Trigger kill callback AFTER incrementing counters
          onGoatKill?.call(goatIndex, fromPosition);
          
          // Remove the killed goat
          goatPositions.removeAt(goatIndex);
          
          print('goatPositions after remove: ${goatPositions.length}');
        }
      }
    }
    
    // Move tiger
    tigerPositions[tigerIndex] = toPosition;
    selectedTigerIndex = null;
    
    // CRITICAL FIX: ALWAYS call onTigerMove for both regular and killing moves
    onTigerMove?.call();
    
    // CRITICAL FIX: Reset isTigerKilling flag after move is complete
    if (isKillingMove) {
      isTigerKilling = false;
      print('=== isTigerKilling reset to false ===');
    }
    
    _checkRoundCompletion();
    onBoardUpdate?.call();
  }

  bool _isKillingMove(Offset from, Offset to) {
    // Get all adjacent positions from the starting point
    List<Offset> adjacentPositions = adjacency[from] ?? [];
    
    // Check if the move goes through an adjacent goat to a position beyond
    for (var adjacent in adjacentPositions) {
      if (goatPositions.any((goat) => (goat - adjacent).distance < 2.0)) {
        // This adjacent position has a goat, check if 'to' is the jump position
        Offset? jumpPos = _getJumpPosition(from, adjacent);
        if (jumpPos != null && (jumpPos - to).distance < 2.0) {
          return true;
        }
      }
    }
    
    return false;
  }

  Offset? _getKilledGoatPosition(Offset from, Offset to) {
    // Calculate the exact middle position
    double midX = (from.dx + to.dx) / 2;
    double midY = (from.dy + to.dy) / 2;
    Offset middle = Offset(midX, midY);
    
    // Use a more generous threshold for position matching
    for (var goat in goatPositions) {
      double distance = (goat - middle).distance;
      
      if (distance < 5.0) { // Increased threshold to 5.0
        return goat;
      }
    }
    
    return null;
  }

 void _checkRoundCompletion() {
  if (_roundCompleted) {
    print('❌ _checkRoundCompletion: Round already completed, skipping');
    return;
  }
  
  print('=== CHECKING ROUND COMPLETION ===');
  print('Current Round: $currentRound');
  print('goatsKilledThisRound: $goatsKilledThisRound / $maxGoats');
  print('goatsEaten: $goatsEaten');
  print('goatPositions.length: ${goatPositions.length}');
  print('totalGoatsPlaced: $totalGoatsPlaced / $maxGoats');
  print('_roundCompleted: $_roundCompleted');
  print('gameOver: $gameOver');
  
  // FIXED: Condition 1 - All goats placed AND no goats left on board (by any means)
  if (totalGoatsPlaced >= maxGoats && goatPositions.isEmpty) {
    print('🎯 ROUND COMPLETED: Condition 1 - All goats eliminated from board!');
    print('🎯 totalGoatsPlaced: $totalGoatsPlaced >= $maxGoats AND goatPositions.isEmpty: ${goatPositions.isEmpty}');
    _completeRound('Tigers Dominated Round $currentRound!');
    return;
  }
  
  // Condition 2: All goats placed AND all tigers blocked (Goats win round)
  bool allTigersBlocked = _allTigersBlocked();
  if (totalGoatsPlaced >= maxGoats && allTigersBlocked) {
    print('🎯 ROUND COMPLETED: Condition 2 - Goats blocked all tigers!');
    print('🎯 totalGoatsPlaced: $totalGoatsPlaced >= $maxGoats AND allTigersBlocked: $allTigersBlocked');
    _completeRound('Goats Protected Round $currentRound!');
    return;
  }

  // Condition 3: All goats placed AND all goats blocked but tigers still have moves (Tigers win round)
  bool allGoatsBlocked = _allGoatsBlocked();
  bool tigersHaveMoves = !_allTigersBlocked();
  if (totalGoatsPlaced >= maxGoats && allGoatsBlocked && tigersHaveMoves) {
    print('🎯 ROUND COMPLETED: Condition 3 - Tigers trapped goats!');
    print('🎯 totalGoatsPlaced: $totalGoatsPlaced >= $maxGoats AND allGoatsBlocked: $allGoatsBlocked AND tigersHaveMoves: $tigersHaveMoves');
    _completeRound('Tigers Trapped Goats in Round $currentRound!');
    return;
  }
  
  print('❌ Round not completed - No conditions met');
  print('---');
}
  void _completeRound(String roundWinner) {
    if (_roundCompleted) return;
    
    print('🚀 === ROUND COMPLETION PROCESS STARTING ===');
    print('🚀 Round Winner: $roundWinner');
    print('🚀 Current Round: $currentRound');
    print('🚀 goatsKilledThisRound: $goatsKilledThisRound');
    print('🚀 Setting _roundCompleted = true');
    
    _roundCompleted = true;
    
    // CRITICAL FIX: Only set gameOver = true for the final round (Round 2)
    gameOver = (currentRound == 2);
    print('🚀 gameOver set to: $gameOver (currentRound == 2: ${currentRound == 2})');
    
    winner = roundWinner;
    
    // Notify about round end
    print('🚀 Calling onRoundEnd callback with round: $currentRound, goatsKilled: $goatsKilledThisRound');
    onRoundEnd?.call(currentRound, goatsKilledThisRound);
    
    print('🚀 Calling onBoardUpdate callback');
    onBoardUpdate?.call();
    
    print('🚀 === ROUND COMPLETION PROCESS FINISHED ===');
  }

  bool _allTigersBlocked() {
    print('🐯 CHECKING IF ALL TIGERS ARE BLOCKED');
    print('🐯 Number of tigers: ${tigerPositions.length}');
    
    for (int i = 0; i < tigerPositions.length; i++) {
      List<Offset> moves = validTigerMoves(i);
      print('🐯 Tiger $i at ${tigerPositions[i]} has ${moves.length} moves');
      
      if (moves.isNotEmpty) {
        print('🐯 Tiger $i CAN move - NOT all tigers blocked');
        return false;
      }
    }
    
    print('🐯 ALL TIGERS ARE BLOCKED - no moves available');
    return true;
  }

  bool _allGoatsBlocked() {
    print('🐐 CHECKING IF ALL GOATS ARE BLOCKED');
    print('🐐 totalGoatsPlaced: $totalGoatsPlaced / $maxGoats');
    print('🐐 goatPositions.length: ${goatPositions.length}');
    
    if (totalGoatsPlaced < maxGoats) {
      print('🐐 NOT all goats placed yet - returning false');
      return false;
    }
    
    for (var goat in goatPositions) {
      selectedGoat = goat;
      List<Offset> moves = validGoatMoves();
      selectedGoat = null;
      
      print('🐐 Goat at $goat has ${moves.length} moves');
      
      if (moves.isNotEmpty) {
        print('🐐 Goat CAN move - NOT all goats blocked');
        return false;
      }
    }
    
    print('🐐 ALL GOATS ARE BLOCKED - no moves available');
    return true;
  }

  void startNewRound(int round, bool playerIsTiger) {
    print('🔄 STARTING NEW ROUND: $round, playerIsTiger: $playerIsTiger');
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
    isTigerKilling = false;
    
    _initializePositions();
    
    // Set turn based on player side
    tigerTurn = playerIsTiger;
    
    print('🔄 New round initialized - tigerTurn: $tigerTurn');
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
        Offset? killedGoat = _getKilledGoatPosition(from, to);
        bool isKill = killedGoat != null && goatPositions.contains(killedGoat);
        
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
      // Placement phase
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
      // Movement phase
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
    if (move['isValid'] != true || gameOver || _roundCompleted) {
      return;
    }

    switch (move['type']) {
      case 'tiger_move':
      case 'tiger_kill':
        int tigerIndex = move['tigerIndex'];
        Offset toPosition = move['toPosition'];
        
        List<Offset> validMoves = validTigerMoves(tigerIndex);
        if (!validMoves.contains(toPosition)) {
          return;
        }
        
        _executeTigerMove(tigerIndex, toPosition);
        break;

      case 'goat_place':
        Offset toPosition = move['toPosition'];
        
        if (_isPositionOccupied(toPosition)) {
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
    isTigerKilling = false;
    
    _initializePositions();
    onBoardUpdate?.call();
  }

  bool shouldProceedToNextRound() {
    return _roundCompleted && currentRound == 1;
  }

  bool isGameFinished() {
    return _roundCompleted && currentRound == 2;
  }
}
