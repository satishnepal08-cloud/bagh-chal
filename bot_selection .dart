// lib/services/bot_service.dart
import 'dart:math';
import 'dart:ui';

import 'package:bagh_chal_game/logic/game_engine.dart';

class BotService {
  final Random random = Random();
  
  static const int minDelaySeconds = 1;
  static const int maxDelaySeconds = 3;
  
  // Track previous moves to avoid repetition
  List<Map<String, dynamic>> _previousGoatMoves = [];
  List<Map<String, dynamic>> _previousTigerMoves = [];
  static const int maxHistorySize = 5;
  
  // FIXED: Proper bot turn detection
  bool isBotTurn(GameEngine engine, String playerSide) {
    if (playerSide == 'tiger') {
      // Player is tiger, bot is goat - bot plays when it's NOT tiger's turn
      return !engine.tigerTurn;
    } else if (playerSide == 'goat') {
      // Player is goat, bot is tiger - bot plays when it IS tiger's turn
      return engine.tigerTurn;
    }
    return false; // Local 2-player mode
  }
  
  Future<Map<String, dynamic>> getBotMoveWithDelay(GameEngine engine) async {
    // Reduced delay for faster bot response
    int delaySeconds = min(2, minDelaySeconds + random.nextInt(maxDelaySeconds - minDelaySeconds + 1));
    await Future.delayed(Duration(seconds: delaySeconds));
    
    final move = getBotMove(engine);
    return move;
  }

  // MAIN LOGIC: CHOOSE WHICH SIDE'S LOGIC TO RUN
  Map<String, dynamic> getBotMove(GameEngine engine) {
    return engine.tigerTurn ? _getTigerMove(engine) : _getGoatMove(engine);
  }

  Map<String, dynamic> _getTigerMove(GameEngine engine) {
    final moves = engine.getAllPossibleTigerMoves();
    if (moves.isEmpty) return {'type': 'invalid', 'isValid': false};

    // Filter out recent moves to avoid repetition
    final availableMoves = _filterRecentMoves(moves, _previousTigerMoves);
    
    if (availableMoves.isEmpty) {
      // If all moves are recent, use original moves but shuffle
      return _getShuffledTigerMove(moves);
    }

    // 1. PRIORITY: Immediate kills
    final killMoves = availableMoves.where((m) => m['isKill'] == true).toList();
    if (killMoves.isNotEmpty) {
      final bestKill = _chooseBestAggressiveKill(engine, killMoves);
      _addToHistory(bestKill, _previousTigerMoves);
      return bestKill;
    }

    // 2. Setup for next turn kill
    final setupKills = _findKillSetupMoves(engine, availableMoves);
    if (setupKills.isNotEmpty) {
      final chosen = _getRandomMove(setupKills);
      _addToHistory(chosen, _previousTigerMoves);
      return {
        'type': 'tiger_move',
        'tigerIndex': chosen['tigerIndex'],
        'fromPosition': chosen['fromPosition'],
        'toPosition': chosen['toPosition'],
        'isValid': true,
      };
    }

    // 3. Hunt isolated goats
    final huntMoves = _findHuntingMoves(engine, availableMoves);
    if (huntMoves.isNotEmpty) {
      final chosen = _getRandomMove(huntMoves);
      _addToHistory(chosen, _previousTigerMoves);
      return {
        'type': 'tiger_move',
        'tigerIndex': chosen['tigerIndex'],
        'fromPosition': chosen['fromPosition'],
        'toPosition': chosen['toPosition'],
        'isValid': true,
      };
    }

    // 4. Move to center
    final centerMoves = _findCenterMoves(engine, availableMoves);
    if (centerMoves.isNotEmpty) {
      final chosen = _getRandomMove(centerMoves);
      _addToHistory(chosen, _previousTigerMoves);
      return {
        'type': 'tiger_move',
        'tigerIndex': chosen['tigerIndex'],
        'fromPosition': chosen['fromPosition'],
        'toPosition': chosen['toPosition'],
        'isValid': true,
      };
    }

    // 5. Fallback - use shuffled random move
    final randomMove = _getRandomMove(availableMoves);
    _addToHistory(randomMove, _previousTigerMoves);
    return {
      'type': 'tiger_move',
      'tigerIndex': randomMove['tigerIndex'],
      'fromPosition': randomMove['fromPosition'],
      'toPosition': randomMove['toPosition'],
      'isValid': true,
    };
  }

  Map<String, dynamic> _getShuffledTigerMove(List<Map<String, dynamic>> moves) {
    final shuffled = List<Map<String, dynamic>>.from(moves)..shuffle(random);
    final chosen = shuffled.first;
    _addToHistory(chosen, _previousTigerMoves);
    return {
      'type': 'tiger_move',
      'tigerIndex': chosen['tigerIndex'],
      'fromPosition': chosen['fromPosition'],
      'toPosition': chosen['toPosition'],
      'isValid': true,
    };
  }

  // ============ IMPROVED GOAT AI ============
  Map<String, dynamic> _getGoatMove(GameEngine engine) {
    final moves = engine.getAllPossibleGoatMoves();
    if (moves.isEmpty) return {'type': 'invalid', 'isValid': false};

    // Filter out recent moves to avoid repetition
    final availableMoves = _filterRecentMoves(moves, _previousGoatMoves);
    
    if (availableMoves.isEmpty) {
      // If all moves are recent, use original moves but shuffle
      return _getShuffledGoatMove(moves);
    }

    if (engine.totalGoatsPlaced < GameEngine.maxGoats) {
      return _getSmartPlacement(engine, availableMoves);
    }

    return _getSmartMovement(engine, availableMoves);
  }

  Map<String, dynamic> _getShuffledGoatMove(List<Map<String, dynamic>> moves) {
    final shuffled = List<Map<String, dynamic>>.from(moves)..shuffle(random);
    final chosen = shuffled.first;
    _addToHistory(chosen, _previousGoatMoves);
    
    if (chosen['type'] == 'goat_place') {
      return {
        'type': 'goat_place',
        'toPosition': chosen['toPosition'],
        'isValid': true,
      };
    } else {
      return {
        'type': 'goat_move',
        'goatIndex': chosen['goatIndex'],
        'fromPosition': chosen['fromPosition'],
        'toPosition': chosen['toPosition'],
        'isValid': true,
      };
    }
  }

  Map<String, dynamic> _getSmartPlacement(GameEngine engine, List<Map<String, dynamic>> moves) {
    // 1. Block tiger kill opportunities
    final blockingMoves = _findKillBlockingPlacements(engine, moves);
    if (blockingMoves.isNotEmpty) {
      final chosen = _getRandomMove(blockingMoves);
      _addToHistory(chosen, _previousGoatMoves);
      return {
        'type': 'goat_place',
        'toPosition': chosen['toPosition'],
        'isValid': true,
      };
    }

    // 2. Place near other goats for defense
    final formationMoves = _findFormationPlacements(engine, moves);
    if (formationMoves.isNotEmpty) {
      final chosen = _getRandomMove(formationMoves);
      _addToHistory(chosen, _previousGoatMoves);
      return {
        'type': 'goat_place',
        'toPosition': chosen['toPosition'],
        'isValid': true,
      };
    }

    // 3. Place in safe positions away from tigers
    final safeMoves = _findSafePlacements(engine, moves);
    if (safeMoves.isNotEmpty) {
      final chosen = _getRandomMove(safeMoves);
      _addToHistory(chosen, _previousGoatMoves);
      return {
        'type': 'goat_place',
        'toPosition': chosen['toPosition'],
        'isValid': true,
      };
    }

    // 4. Random placement from available moves
    final chosen = _getRandomMove(moves);
    _addToHistory(chosen, _previousGoatMoves);
    return {
      'type': 'goat_place',
      'toPosition': chosen['toPosition'],
      'isValid': true,
    };
  }

  Map<String, dynamic> _getSmartMovement(GameEngine engine, List<Map<String, dynamic>> moves) {
    // 1. Move goats that are in immediate danger
    final escapeMoves = _findEscapeMoves(engine, moves);
    if (escapeMoves.isNotEmpty) {
      final chosen = _getRandomMove(escapeMoves);
      _addToHistory(chosen, _previousGoatMoves);
      return {
        'type': 'goat_move',
        'goatIndex': chosen['goatIndex'],
        'fromPosition': chosen['fromPosition'],
        'toPosition': chosen['toPosition'],
        'isValid': true,
      };
    }

    // 2. Block tiger movements
    final blockingMoves = _findMovementBlockingMoves(engine, moves);
    if (blockingMoves.isNotEmpty) {
      final chosen = _getRandomMove(blockingMoves);
      _addToHistory(chosen, _previousGoatMoves);
      return {
        'type': 'goat_move',
        'goatIndex': chosen['goatIndex'],
        'fromPosition': chosen['fromPosition'],
        'toPosition': chosen['toPosition'],
        'isValid': true,
      };
    }

    // 3. Improve formation
    final formationMoves = _findFormationImprovementMoves(engine, moves);
    if (formationMoves.isNotEmpty) {
      final chosen = _getRandomMove(formationMoves);
      _addToHistory(chosen, _previousGoatMoves);
      return {
        'type': 'goat_move',
        'goatIndex': chosen['goatIndex'],
        'fromPosition': chosen['fromPosition'],
        'toPosition': chosen['toPosition'],
        'isValid': true,
      };
    }

    // 4. Random move from available options
    final chosen = _getRandomMove(moves);
    _addToHistory(chosen, _previousGoatMoves);
    return {
      'type': 'goat_move',
      'goatIndex': chosen['goatIndex'],
      'fromPosition': chosen['fromPosition'],
      'toPosition': chosen['toPosition'],
      'isValid': true,
    };
  }

  // ============ IMPROVED GOAT HELPERS ============

  List<Map<String, dynamic>> _findKillBlockingPlacements(GameEngine engine, List<Map<String, dynamic>> moves) {
    List<Map<String, dynamic>> blocking = [];
    
    for (var move in moves) {
      if (move['type'] != 'goat_place') continue;
      
      Offset pos = move['toPosition'];
      int blockScore = 0;
      
      // Check if this position blocks any potential tiger kills
      for (var tiger in engine.tigerPositions) {
        for (var goat in engine.goatPositions) {
          Offset? beyond = _calculateBeyond(tiger, goat, engine);
          if (beyond != null && _arePositionsEqual(beyond, pos)) {
            blockScore += 10;
          }
        }
      }
      
      if (blockScore > 0) {
        blocking.add({...move, 'score': blockScore});
      }
    }
    
    blocking.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return blocking;
  }

  List<Map<String, dynamic>> _findFormationPlacements(GameEngine engine, List<Map<String, dynamic>> moves) {
    List<Map<String, dynamic>> formations = [];
    
    for (var move in moves) {
      if (move['type'] != 'goat_place') continue;
      
      Offset pos = move['toPosition'];
      int nearbyGoats = engine.goatPositions.where((g) => 
        (g - pos).distance >= 1.0 && (g - pos).distance <= 2.0
      ).length;
      
      double minTigerDist = engine.tigerPositions.isEmpty ? 100.0 :
        engine.tigerPositions.map((t) => (pos - t).distance).reduce(min);
      
      if (nearbyGoats >= 1 && nearbyGoats <= 3 && minTigerDist > 1.5) {
        formations.add({...move, 'score': nearbyGoats * 5 + minTigerDist.toInt()});
      }
    }
    
    return formations;
  }

  List<Map<String, dynamic>> _findSafePlacements(GameEngine engine, List<Map<String, dynamic>> moves) {
    List<Map<String, dynamic>> safeMoves = [];
    
    for (var move in moves) {
      if (move['type'] != 'goat_place') continue;
      
      Offset pos = move['toPosition'];
      double minTigerDist = engine.tigerPositions.isEmpty ? 100.0 :
        engine.tigerPositions.map((t) => (pos - t).distance).reduce(min);
      
      if (minTigerDist > 2.0) {
        safeMoves.add({...move, 'score': minTigerDist.toInt()});
      }
    }
    
    safeMoves.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return safeMoves;
  }

  List<Map<String, dynamic>> _findEscapeMoves(GameEngine engine, List<Map<String, dynamic>> moves) {
    List<Map<String, dynamic>> escapes = [];
    
    for (var move in moves) {
      if (move['type'] != 'goat_move') continue;
      
      Offset from = move['fromPosition'];
      Offset to = move['toPosition'];
      
      // Check if current position is dangerous
      bool isDangerous = false;
      for (var tiger in engine.tigerPositions) {
        Offset? beyond = _calculateBeyond(tiger, from, engine);
        if (beyond != null && !_isPositionOccupied(engine, beyond)) {
          if (_isAdjacent(engine, tiger, from)) {
            isDangerous = true;
            break;
          }
        }
      }
      
      if (isDangerous) {
        // Check if new position is safer
        double safety = engine.tigerPositions.map((t) => (to - t).distance).reduce(min);
        escapes.add({...move, 'score': safety.toInt()});
      }
    }
    
    escapes.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return escapes;
  }

  List<Map<String, dynamic>> _findMovementBlockingMoves(GameEngine engine, List<Map<String, dynamic>> moves) {
    List<Map<String, dynamic>> blocking = [];
    
    for (var move in moves) {
      if (move['type'] != 'goat_move') continue;
      
      Offset to = move['toPosition'];
      int blockScore = 0;
      
      // Check if this move blocks tiger movement paths
      for (var tiger in engine.tigerPositions) {
        for (var neighbor in engine.adjacency[tiger] ?? []) {
          if (_arePositionsEqual(neighbor, to)) {
            blockScore += 5;
          }
        }
      }
      
      if (blockScore > 0) {
        blocking.add({...move, 'score': blockScore});
      }
    }
    
    return blocking;
  }

  List<Map<String, dynamic>> _findFormationImprovementMoves(GameEngine engine, List<Map<String, dynamic>> moves) {
    List<Map<String, dynamic>> improvements = [];
    
    for (var move in moves) {
      if (move['type'] != 'goat_move') continue;
      
      Offset to = move['toPosition'];
      int nearbyGoats = engine.goatPositions.where((g) => 
        g != move['fromPosition'] && (g - to).distance >= 1.0 && (g - to).distance <= 2.0
      ).length;
      
      double minTigerDist = engine.tigerPositions.isEmpty ? 100.0 :
        engine.tigerPositions.map((t) => (to - t).distance).reduce(min);
      
      if (nearbyGoats >= 1 && minTigerDist > 1.5) {
        improvements.add({...move, 'score': nearbyGoats * 3 + minTigerDist.toInt()});
      }
    }
    
    improvements.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return improvements;
  }

  // ============ MOVE HISTORY MANAGEMENT ============

  List<Map<String, dynamic>> _filterRecentMoves(List<Map<String, dynamic>> moves, List<Map<String, dynamic>> history) {
    if (history.isEmpty) return moves;
    
    return moves.where((move) {
      for (var pastMove in history) {
        if (_areMovesSimilar(move, pastMove)) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  bool _areMovesSimilar(Map<String, dynamic> move1, Map<String, dynamic> move2) {
    if (move1['type'] != move2['type']) return false;
    
    if (move1['type'] == 'goat_place') {
      return _arePositionsEqual(move1['toPosition'], move2['toPosition']);
    } else if (move1['type'] == 'goat_move') {
      return _arePositionsEqual(move1['fromPosition'], move2['fromPosition']) &&
             _arePositionsEqual(move1['toPosition'], move2['toPosition']);
    } else if (move1['type'] == 'tiger_move' || move1['type'] == 'tiger_kill') {
      return move1['tigerIndex'] == move2['tigerIndex'] &&
             _arePositionsEqual(move1['toPosition'], move2['toPosition']);
    }
    
    return false;
  }

  void _addToHistory(Map<String, dynamic> move, List<Map<String, dynamic>> history) {
    history.add(move);
    if (history.length > maxHistorySize) {
      history.removeAt(0);
    }
  }

  Map<String, dynamic> _getRandomMove(List<Map<String, dynamic>> moves) {
    return moves[random.nextInt(moves.length)];
  }

  // ============ EXISTING TIGER AI HELPERS (keep these) ============

  Map<String, dynamic> _chooseBestAggressiveKill(GameEngine engine, List<Map<String, dynamic>> killMoves) {
    List<Map<String, dynamic>> scoredKills = [];
    
    for (var move in killMoves) {
      Offset landingPos = move['toPosition'];
      int score = 0;
      
      int nearbyGoats = engine.goatPositions.where((g) => (g - landingPos).distance < 2.5).length;
      score += nearbyGoats * 10;
      
      double centerDist = (landingPos - Offset(engine.boardSize / 2, engine.boardSize / 2)).distance;
      score += (100 - centerDist).toInt();
      
      int veryCloseGoats = engine.goatPositions.where((g) => (g - landingPos).distance < 1.5).length;
      if (veryCloseGoats >= 4) score -= 50;
      
      scoredKills.add({...move, 'score': score});
    }
    
    scoredKills.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    final chosen = scoredKills.first;
    
    return {
      'type': 'tiger_kill',
      'tigerIndex': chosen['tigerIndex'],
      'fromPosition': chosen['fromPosition'],
      'toPosition': chosen['toPosition'],
      'isValid': true,
    };
  }

  Offset _findMiddleGoat(GameEngine engine, Offset from, Offset to) {
    Offset mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
    for (var g in engine.goatPositions) {
      if ((g - mid).distance < 1) return g;
    }
    return Offset.zero;
  }

  List<Map<String, dynamic>> _findKillSetupMoves(GameEngine engine, List<Map<String, dynamic>> moves) {
    List<Map<String, dynamic>> setupMoves = [];
    
    for (var move in moves) {
      Offset to = move['toPosition'];
      
      for (var goat in engine.goatPositions) {
        Offset? beyond = _calculateBeyond(to, goat, engine);
        if (beyond != null && !_isPositionOccupied(engine, beyond)) {
          setupMoves.add(move);
          break;
        }
      }
    }
    
    return setupMoves;
  }

  List<Map<String, dynamic>> _findHuntingMoves(GameEngine engine, List<Map<String, dynamic>> moves) {
    List<Map<String, dynamic>> scoredMoves = [];
    
    for (var move in moves) {
      Offset to = move['toPosition'];
      double minGoatDist = double.infinity;
      Offset? targetGoat;
      
      for (var goat in engine.goatPositions) {
        double dist = (to - goat).distance;
        if (dist < minGoatDist) {
          minGoatDist = dist;
          targetGoat = goat;
        }
      }
      
      if (targetGoat != null) {
        int goatSupport = engine.goatPositions.where((g) => 
          (g - targetGoat!).distance < 2.0 && g != targetGoat
        ).length;
        
        int score = 100 - minGoatDist.toInt() - (goatSupport * 15);
        scoredMoves.add({...move, 'score': score});
      }
    }
    
    scoredMoves.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
    return scoredMoves.take(3).toList();
  }

  List<Map<String, dynamic>> _findCenterMoves(GameEngine engine, List<Map<String, dynamic>> moves) {
    Offset center = Offset(engine.boardSize / 2, engine.boardSize / 2);
    
    moves.sort((a, b) {
      double distA = ((a['toPosition'] as Offset) - center).distance;
      double distB = ((b['toPosition'] as Offset) - center).distance;
      return distA.compareTo(distB);
    });
    
    return moves.take(3).toList();
  }

  // ============ UTILITY HELPERS ============

  bool _isPositionOccupied(GameEngine engine, Offset pos) {
    for (var t in engine.tigerPositions) {
      if ((t - pos).distance < 1) return true;
    }
    for (var g in engine.goatPositions) {
      if ((g - pos).distance < 1) return true;
    }
    return false;
  }

  bool _isAdjacent(GameEngine engine, Offset a, Offset b) {
    return engine.adjacency[a]?.contains(b) ?? false;
  }

  bool _arePositionsEqual(Offset a, Offset b) {
    return (a - b).distance < 1;
  }

  Offset? _calculateBeyond(Offset from, Offset middle, GameEngine engine) {
    double dx = middle.dx - from.dx;
    double dy = middle.dy - from.dy;
    Offset beyond = Offset(middle.dx + dx, middle.dy + dy);
    
    // Check if beyond is a valid grid point using exact comparison
    for (var point in engine.gridPoints) {
      if (_arePositionsEqual(point, beyond)) {
        return point;
      }
    }
    return null;
  }
}
