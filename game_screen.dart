import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../widgets/board_painter.dart';
import '../widgets/tiger_token.dart';
import '../widgets/goat_token.dart';
import '../widgets/valid_move_indicator.dart';
import '../logic/game_engine.dart';
import '../services/bot_service.dart';

class GameScreen extends StatefulWidget {
  final String playerSide;
  final bool isBotGame;

  const GameScreen({
    super.key,
    required this.playerSide,
    required this.isBotGame,
  });

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late GameEngine engine;
  late BotService botService;
  double boardSize = 300;
  final GlobalKey _boardKey = GlobalKey();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isAudioPlaying = false;
  bool isAnimating = false;
  bool isBotThinking = false;

  int _playerGoatsKilledAsTiger = 0;
  int _botGoatsKilledAsTiger = 0;
  int currentRound = 1;
  String currentPlayerSide = '';

  int _timeRemaining = 60;
  int _roundTimeRemaining = 600;
  Timer? _moveTimer;
  Timer? _roundTimer;
  Timer? _botMoveDelayTimer;
  int _timeViolationCount = 0;
  int? _eliminatedGoatId;
  bool _showingEliminationWarning = false;
  bool _isHandlingRoundEnd = false;

  late AnimationController _animationController;

  Offset? _botMovePreview;
  String? _botMoveType;

  int _nextGoatId = 0;
  final Map<int, Offset> _goatPositionsById = {};
  final Map<int, Offset> _goatTargetPositions = {};
  final Set<int> _killedGoatIds = {};

  final Map<int, Offset> _currentTigerPositions = {};
  final Map<int, Offset> _targetTigerPositions = {};

  @override
  void initState() {
    super.initState();
    
    currentPlayerSide = widget.playerSide;
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..addListener(() {
        if (mounted) {
          setState(() {
            _updateAnimatedPositions();
          });
        }
      });
    
    WidgetsBinding.instance.addObserver(this);
    
    botService = BotService();
    _initializeEngine();
    
    _addInitialGoats();
    _updateTigerPositions();
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startMoveTimer();
        _startRoundTimer();
        
        if (widget.isBotGame && _isBotTurn()) {
          _scheduleBotMove(delayMs: 500);
        }
      }
    });
  }

  @override
  void dispose() {
    _cancelMoveTimer();
    _cancelRoundTimer();
    _cancelBotDelayTimer();
    _audioPlayer.dispose();
    _animationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _initializeEngine() {
    engine = GameEngine(boardSize: boardSize);
    engine.onSelectToken = () {
      if (mounted) _playSound('select.mp3');
    };
    
    engine.onGoatMove = _handleGoatMoveCompleted;
    engine.onTigerMove = _handleTigerMoveCompleted;
    engine.onGoatKill = _handleTigerKill;
    
    engine.onRoundEnd = (round, goatsKilled) {
      if (mounted && !_isHandlingRoundEnd) {
        _isHandlingRoundEnd = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _handleRoundEnd(round, goatsKilled);
          }
        });
      }
    };
    
    engine.onBoardUpdate = () {
      if (mounted) {
        setState(() {});
      }
    };
  }

  void _onMoveCompleted() {
    if (!mounted) return;
    
    debugPrint('=== MOVE COMPLETED ===');
    debugPrint('Game Over: ${engine.gameOver}');
    debugPrint('Current Turn: ${engine.tigerTurn ? "Tiger" : "Goat"}');
    
    if (engine.gameOver) {
      debugPrint('Game over detected - waiting for round end handler');
      _cancelMoveTimer();
      _cancelRoundTimer();
      _cancelBotDelayTimer();
      return;
    }

    setState(() {
      engine.tigerTurn = !engine.tigerTurn;
      debugPrint('Turn switched to: ${engine.tigerTurn ? "Tiger" : "Goat"}');
    });

    _resetMoveTimer();

    if (widget.isBotGame && _isBotTurn()) {
      debugPrint('Scheduling bot move');
      _scheduleBotMove(delayMs: 800);
    } else {
      _cancelBotDelayTimer();
      debugPrint("Player's turn started");
    }
  }

  void _handleGoatMoveCompleted() {
    debugPrint('Goat move completed');
    _smoothMoveSound('goat_move.mp3').then((_) {
      if (mounted) {
        _onMoveCompleted();
      }
    });
  }

  void _handleTigerMoveCompleted() {
    debugPrint('Tiger move completed');
    _smoothMoveSound('tiger_move.mp3').then((_) {
      if (mounted) {
        _onMoveCompleted();
      }
    });
  }

  void _addInitialGoats() {
    for (final pos in engine.goatPositions) {
      final id = _nextGoatId++;
      _goatPositionsById[id] = pos;
      _goatTargetPositions[id] = pos;
    }
  }

  void _updateTigerPositions() {
    _currentTigerPositions.clear();
    _targetTigerPositions.clear();
    for (int i = 0; i < engine.tigerPositions.length; i++) {
      _currentTigerPositions[i] = engine.tigerPositions[i];
      _targetTigerPositions[i] = engine.tigerPositions[i];
    }
  }

  void _updateAnimatedPositions() {
    final double t = _animationController.value;
    
    for (final entry in _targetTigerPositions.entries) {
      final idx = entry.key;
      final target = entry.value;
      final current = _currentTigerPositions[idx];
      if (current != null && (current - target).distance > 0.1) {
        _currentTigerPositions[idx] = Offset(
          current.dx + (target.dx - current.dx) * t,
          current.dy + (target.dy - current.dy) * t,
        );
      }
    }
    
    for (final entry in _goatTargetPositions.entries) {
      final id = entry.key;
      final target = entry.value;
      final current = _goatPositionsById[id];
      if (current != null && (current - target).distance > 0.1) {
        _goatPositionsById[id] = Offset(
          current.dx + (target.dx - current.dx) * t,
          current.dy + (target.dy - current.dy) * t,
        );
      }
    }
  }

  void _startAnimation() {
    for (int i = 0; i < engine.tigerPositions.length; i++) {
      _targetTigerPositions[i] = engine.tigerPositions[i];
    }
    
    _animationController.forward(from: 0.0);
  }

  Future<void> _handleTigerKill(int goatIndex, Offset tigerPos) async {
    if (isAudioPlaying || isAnimating || goatIndex < 0 || goatIndex >= engine.goatPositions.length) {
      return;
    }

    final Offset killedGoatPosition = engine.goatPositions[goatIndex];
    
    int? killedGoatId;
    for (final entry in _goatPositionsById.entries) {
      if ((entry.value - killedGoatPosition).distance < 1) {
        killedGoatId = entry.key;
        break;
      }
    }
    
    if (killedGoatId == null) {
      debugPrint('ERROR: Could not find goat at position $killedGoatPosition');
      return;
    }

    final safeKilledGoatId = killedGoatId;

    debugPrint('Tiger killing goat ID:$safeKilledGoatId at position $killedGoatPosition');

    if (currentPlayerSide == 'tiger') {
      _playerGoatsKilledAsTiger++;
      debugPrint('Player killed goat. Total: $_playerGoatsKilledAsTiger');
    } else {
      _botGoatsKilledAsTiger++;
      debugPrint('Bot killed goat. Total: $_botGoatsKilledAsTiger');
    }

    if (mounted) {
      setState(() => isAnimating = true);
      await _playSound('tiger_kill.mp3');
    }

    if (mounted) {
      setState(() {
        _killedGoatIds.add(safeKilledGoatId);
        engine.isTigerKilling = true;
      });
    }

    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      setState(() {
        _goatPositionsById.remove(safeKilledGoatId);
        _goatTargetPositions.remove(safeKilledGoatId);
        _killedGoatIds.remove(safeKilledGoatId);
        
        engine.selectedTigerIndex = null;
        engine.isTigerKilling = false;
        isAnimating = false;
      });
    }
  }

  void _onBoardTap(TapUpDetails details) {
    if (!mounted || isAudioPlaying || isAnimating || engine.isTigerKilling || isBotThinking || _showingEliminationWarning) {
      debugPrint('Board tap blocked');
      return;
    }
    if (widget.isBotGame && _isBotTurn()) {
      debugPrint("Not player's turn");
      return;
    }

    final RenderBox? box = _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final local = box.globalToLocal(details.globalPosition);
    final Offset tapped = engine.snapToGrid(local);

    final previousGoatPositions = List<Offset>.from(engine.goatPositions);
    final previousGoatCount = engine.goatPositions.length;
    final previousTigerPositions = List<Offset>.from(engine.tigerPositions);
    
    debugPrint('Player tapped at: $tapped, Tiger turn: ${engine.tigerTurn}');
    
    setState(() {
      engine.handleTap(tapped);
      
      final goatCountChanged = engine.goatPositions.length != previousGoatCount;
      final tigerMoved = !_listsEqual(previousTigerPositions, engine.tigerPositions);
      final goatMoved = !_listsEqual(previousGoatPositions, engine.goatPositions) && !goatCountChanged;
      
      if (goatCountChanged && engine.goatPositions.length > previousGoatCount) {
        final newPos = engine.goatPositions.last;
        final newId = _nextGoatId++;
        _goatPositionsById[newId] = newPos;
        _goatTargetPositions[newId] = newPos;
        debugPrint('Player placed goat ID:$newId at $newPos');
      } else if (goatMoved) {
        Offset? movedFromPos;
        for (final oldPos in previousGoatPositions) {
          if (!engine.goatPositions.any((newPos) => (newPos - oldPos).distance < 1)) {
            movedFromPos = oldPos;
            break;
          }
        }
        
        Offset? movedToPos;
        for (final newPos in engine.goatPositions) {
          if (!previousGoatPositions.any((oldPos) => (oldPos - newPos).distance < 1)) {
            movedToPos = newPos;
            break;
          }
        }
        
        if (movedFromPos != null && movedToPos != null) {
          for (final entry in _goatPositionsById.entries) {
            if ((entry.value - movedFromPos).distance < 1) {
              debugPrint('Goat ID:${entry.key} moved from $movedFromPos to $movedToPos');
              _goatTargetPositions[entry.key] = movedToPos;
              _startAnimation();
              break;
            }
          }
        }
      } else if (tigerMoved) {
        _updateTigerPositions();
        _startAnimation();
      }
      
      _timeViolationCount = 0;
    });
  }

  bool _listsEqual(List<Offset> list1, List<Offset> list2) {
    if (list1.length != list2.length) return false;
    for (int i = 0; i < list1.length; i++) {
      if ((list1[i] - list2[i]).distance > 0.1) return false;
    }
    return true;
  }

  Future<void> _makeBotMove() async {
    if (!mounted || isBotThinking || engine.gameOver || !_isBotTurn() || _showingEliminationWarning) {
      debugPrint('Bot move blocked');
      return;
    }
    
    _cancelBotDelayTimer();
    setState(() => isBotThinking = true);

    try {
      await Future.delayed(const Duration(milliseconds: 1000));
      
      if (!mounted || engine.gameOver || !_isBotTurn()) {
        if (mounted) setState(() => isBotThinking = false);
        return;
      }
      
      final botMove = await botService.getBotMove(engine);
      
      if (!mounted || engine.gameOver) {
        if (mounted) setState(() => isBotThinking = false);
        return;
      }

      if (botMove['isValid'] == true) {
        setState(() {
          _botMovePreview = botMove['toPosition'];
          _botMoveType = botMove['type'];
        });

        await Future.delayed(const Duration(milliseconds: 800));

        if (!mounted) return;

        final previousGoatCount = engine.goatPositions.length;
        final previousGoatPositions = List<Offset>.from(engine.goatPositions);
        
        engine.executeBotMove(botMove);
        
        if (mounted) {
          setState(() {
            _botMovePreview = null;
            _botMoveType = null;

            if (botMove['type'] == 'goat_place' && engine.goatPositions.length > previousGoatCount) {
              final newPos = engine.goatPositions.last;
              final newId = _nextGoatId++;
              _goatPositionsById[newId] = newPos;
              _goatTargetPositions[newId] = newPos;
              debugPrint('Bot placed goat ID:$newId at $newPos');
            } else if (botMove['type'] == 'goat_move') {
              Offset? movedFromPos;
              for (final oldPos in previousGoatPositions) {
                if (!engine.goatPositions.any((newPos) => (newPos - oldPos).distance < 1)) {
                  movedFromPos = oldPos;
                  break;
                }
              }
              
              Offset? movedToPos;
              for (final newPos in engine.goatPositions) {
                if (!previousGoatPositions.any((oldPos) => (oldPos - newPos).distance < 1)) {
                  movedToPos = newPos;
                  break;
                }
              }
              
              if (movedFromPos != null && movedToPos != null) {
                for (final entry in _goatPositionsById.entries) {
                  if ((entry.value - movedFromPos).distance < 1) {
                    _goatTargetPositions[entry.key] = movedToPos;
                    _startAnimation();
                    break;
                  }
                }
              }
            } else {
              _updateTigerPositions();
              _startAnimation();
            }
          });
        }
      } else {
        debugPrint('Bot returned invalid move, advancing turn');
        if (mounted) _onMoveCompleted();
      }
    } catch (e) {
      debugPrint('Bot error: $e');
      if (mounted) _onMoveCompleted();
    } finally {
      if (mounted) {
        setState(() => isBotThinking = false);
      }
    }
  }

  bool _isBotTurn() {
    if (!widget.isBotGame) return false;
    return botService.isBotTurn(engine, currentPlayerSide);
  }

  void _startMoveTimer() {
    _cancelMoveTimer();
    _timeRemaining = engine.tigerTurn ? 60 : 20;

    debugPrint('Starting move timer: ${_timeRemaining}s for ${engine.tigerTurn ? "tiger" : "goat"}');

    _moveTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _timeRemaining--);
      if (_timeRemaining <= 0) {
        timer.cancel();
        _handleMoveTimeOut();
      }
    });
  }

  void _resetMoveTimer() {
    _cancelMoveTimer();
    if (mounted) _startMoveTimer();
  }

  void _cancelMoveTimer() {
    try {
      if (_moveTimer?.isActive ?? false) {
        _moveTimer!.cancel();
      }
    } catch (_) {}
    _moveTimer = null;
  }

  void _startRoundTimer() {
    _cancelRoundTimer();
    _roundTimeRemaining = 600;
    debugPrint('Starting round timer ($_roundTimeRemaining seconds)');

    _roundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() => _roundTimeRemaining--);
      if (_roundTimeRemaining <= 0) {
        timer.cancel();
        _handleRoundTimeOut();
      }
    });
  }

  void _cancelRoundTimer() {
    try {
      if (_roundTimer?.isActive ?? false) {
        _roundTimer!.cancel();
      }
    } catch (_) {}
    _roundTimer = null;
  }

  void _scheduleBotMove({required int delayMs}) {
    _cancelBotDelayTimer();
    _botMoveDelayTimer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted && _isBotTurn() && !engine.gameOver && !isBotThinking) {
        _makeBotMove();
      }
    });
  }

  void _cancelBotDelayTimer() {
    try {
      if (_botMoveDelayTimer?.isActive ?? false) {
        _botMoveDelayTimer!.cancel();
      }
    } catch (_) {}
    _botMoveDelayTimer = null;
  }

  void _handleMoveTimeOut() {
    if (!mounted || engine.gameOver || _showingEliminationWarning) return;
    
    setState(() => _showingEliminationWarning = true);
    _showTimeViolationDialog();
  }

  void _showTimeViolationDialog() {
    if (!widget.isBotGame) {
      _handlePlayerTimeViolation();
    } else {
      if (!_isBotTurn()) {
        _handlePlayerTimeViolation();
      }
    }
  }

  void _handlePlayerTimeViolation() {
    _timeViolationCount++;
    
    if (_timeViolationCount >= 2) {
      _handleGameOverDueToTimeViolation();
    } else {
      _eliminatePlayerToken();
    }
  }

  void _eliminatePlayerToken() {
    if (!mounted) return;

    String playerRole = currentPlayerSide == 'tiger' ? 'Tiger' : 'Goat';
    
    if (currentPlayerSide == 'tiger' && engine.tigerPositions.isNotEmpty) {
      int eliminatedIndex = 0;
      _eliminateTiger(eliminatedIndex, playerRole);
    } else if (currentPlayerSide == 'goat' && engine.goatPositions.isNotEmpty) {
      _eliminateGoat(playerRole);
    } else {
      _handleGameOverDueToTimeViolation();
      return;
    }
    
    _showEliminationNotification(playerRole);
    
    _onMoveCompleted();
    setState(() => _showingEliminationWarning = false);
  }

  void _eliminateTiger(int index, String playerRole) {
    if (index < engine.tigerPositions.length) {
      setState(() {
        engine.tigerPositions.removeAt(index);
        _updateTigerPositions();
      });
      
      if (engine.tigerPositions.length < 2) {
        _handleGameOverDueToTimeViolation();
      }
    }
  }

  void _eliminateGoat(String playerRole) {
    if (engine.goatPositions.isEmpty) {
      _handleGameOverDueToTimeViolation();
      return;
    }

    Offset goatToRemove = engine.goatPositions.first;
    int? goatIdToRemove;
    
    for (final entry in _goatPositionsById.entries) {
      if ((entry.value - goatToRemove).distance < 1) {
        goatIdToRemove = entry.key;
        break;
      }
    }
    
    if (goatIdToRemove != null) {
      final safeGoatId = goatIdToRemove;
      setState(() {
        _eliminatedGoatId = safeGoatId;
        _killedGoatIds.add(safeGoatId);
      });
      
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            engine.goatPositions.remove(goatToRemove);
            _goatPositionsById.remove(safeGoatId);
            _goatTargetPositions.remove(safeGoatId);
            _killedGoatIds.remove(safeGoatId);
            _eliminatedGoatId = null;
          });
          
          if (engine.goatPositions.length < 5) {
            _handleGameOverDueToTimeViolation();
          }
        }
      });
    } else {
      setState(() {
        engine.goatPositions.remove(goatToRemove);
      });
      
      if (engine.goatPositions.length < 5) {
        _handleGameOverDueToTimeViolation();
      }
    }
  }

  void _showEliminationNotification(String playerRole) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber, color: Colors.amber, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '⏰ Time Violation! One $playerRole eliminated',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade700,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleGameOverDueToTimeViolation() {
    if (!mounted) return;

    _cancelMoveTimer();
    _cancelRoundTimer();
    _cancelBotDelayTimer();
    
    String winner;
    String reason;
    
    if (widget.isBotGame) {
      winner = '🤖 Bot Wins!';
      reason = 'Player exceeded time limit multiple times';
    } else {
      winner = engine.tigerTurn ? '🐐 Goat Wins!' : '🐅 Tiger Wins!';
      reason = '${engine.tigerTurn ? 'Tiger' : 'Goat'} player exceeded time limit multiple times';
    }
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.timer_off, color: Colors.red, size: 20),
            SizedBox(width: 8),
            Text("Game Over - Time Violation", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 40, color: Colors.amber),
            const SizedBox(height: 12),
            Text(winner, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text('Reason:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(reason, style: const TextStyle(fontSize: 11, color: Colors.red)),
                  const SizedBox(height: 6),
                  Text('Consecutive violations: $_timeViolationCount', 
                       style: const TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { 
              Navigator.pop(context); 
              Navigator.pop(context); 
            }, 
            child: const Text("Home", style: TextStyle(fontSize: 12))
          ),
          ElevatedButton(
            onPressed: () { 
              Navigator.pop(context); 
              _restartGame(); 
            }, 
            child: const Text("Play Again", style: TextStyle(fontSize: 12))
          ),
        ],
      ),
    );
  }

  void _handleRoundTimeOut() {
    if (!mounted) return;
    _cancelMoveTimer();
    _handleRoundEnd(currentRound, engine.goatsKilledThisRound);
  }

  void _handleRoundEnd(int round, int goatsKilled) {
    if (!mounted || _isHandlingRoundEnd) return;
    
    _isHandlingRoundEnd = true;
    _cancelMoveTimer();
    _cancelRoundTimer();
    _cancelBotDelayTimer();

    debugPrint('Handling round end: Round $round, Goats killed: $goatsKilled');

    if (round == 1) {
      // Store the goats killed in round 1
      if (currentPlayerSide == 'tiger') {
        _playerGoatsKilledAsTiger = goatsKilled;
      } else {
        _botGoatsKilledAsTiger = goatsKilled;
      }

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text("Round 1 Complete!", style: TextStyle(fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_score, size: 40, color: Colors.blue),
              const SizedBox(height: 12),
              Text('${engine.winner}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Goats killed: $goatsKilled', style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              const Text('Switching sides for Round 2...', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () { 
                Navigator.pop(context); 
                _startRound2(); 
              }, 
              child: const Text("Start Round 2", style: TextStyle(fontSize: 12))
            ),
          ],
        ),
      );
    } else {
      // Round 2 completed - show final results
      if (currentPlayerSide == 'goat') {
        _playerGoatsKilledAsTiger = goatsKilled;
      } else {
        _botGoatsKilledAsTiger = goatsKilled;
      }
      _showFinalResults();
    }
  }

  void _showFinalResults() {
    if (!mounted) return;

    String winner;
    if (_playerGoatsKilledAsTiger > _botGoatsKilledAsTiger) {
      winner = '🎉 You Win!';
    } else if (_botGoatsKilledAsTiger > _playerGoatsKilledAsTiger) {
      winner = '🤖 Bot Wins!';
    } else {
      winner = '🤝 Draw!';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("Game Complete!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              winner.contains('You Win') ? Icons.emoji_events : 
              winner.contains('Bot Wins') ? Icons.computer : Icons.handshake,
              size: 40,
              color: winner.contains('Win') ? Colors.amber : Colors.blue,
            ),
            const SizedBox(height: 12),
            Text(winner, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text('Final Score', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          const Text('You', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          Text('$_playerGoatsKilledAsTiger', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Column(
                        children: [
                          const Text('Bot', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                          Text('$_botGoatsKilledAsTiger', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { Navigator.pop(context); Navigator.pop(context); }, 
            child: const Text("Home", style: TextStyle(fontSize: 12))
          ),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _restartGame(); }, 
            child: const Text("Play Again", style: TextStyle(fontSize: 12))
          ),
        ],
      ),
    );
  }

  void _startRound2() {
    if (!mounted) return;

    _cancelMoveTimer();
    _cancelRoundTimer();
    _cancelBotDelayTimer();

    setState(() {
      currentRound = 2;
      currentPlayerSide = currentPlayerSide == 'tiger' ? 'goat' : 'tiger';
      _timeViolationCount = 0;
      _showingEliminationWarning = false;
      _isHandlingRoundEnd = false;
      
      // Start new round with switched sides
      engine.startNewRound(2, currentPlayerSide == 'tiger');
      
      _nextGoatId = 0;
      _goatPositionsById.clear();
      _goatTargetPositions.clear();
      _killedGoatIds.clear();
      _addInitialGoats();
      _updateTigerPositions();
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startMoveTimer();
        _startRoundTimer();
        
        if (widget.isBotGame && _isBotTurn() && !engine.gameOver) {
          _scheduleBotMove(delayMs: 500);
        }
      }
    });
  }

  void _restartGame() {
    if (!mounted) return;

    _cancelMoveTimer();
    _cancelRoundTimer();
    _cancelBotDelayTimer();

    setState(() {
      currentRound = 1;
      _playerGoatsKilledAsTiger = 0;
      _botGoatsKilledAsTiger = 0;
      currentPlayerSide = widget.playerSide;
      _timeViolationCount = 0;
      _showingEliminationWarning = false;
      _isHandlingRoundEnd = false;
      
      engine.reset();
      
      _nextGoatId = 0;
      _goatPositionsById.clear();
      _goatTargetPositions.clear();
      _killedGoatIds.clear();
      _addInitialGoats();
      _updateTigerPositions();
    });
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startMoveTimer();
        _startRoundTimer();
        
        if (widget.isBotGame && _isBotTurn() && !engine.gameOver) {
          _scheduleBotMove(delayMs: 500);
        }
      }
    });
  }

  Future<void> _playSound(String fileName) async {
    if (isAudioPlaying || !mounted) return;
    try {
      setState(() => isAudioPlaying = true);
      await _audioPlayer.setSource(AssetSource('audio/$fileName'));
      await _audioPlayer.resume();
      _audioPlayer.onPlayerComplete.listen((event) {
        if (mounted) setState(() => isAudioPlaying = false);
      });
    } catch (e) {
      debugPrint('Error playing $fileName: $e');
      if (mounted) setState(() => isAudioPlaying = false);
    }
  }

  Future<void> _smoothMoveSound(String fileName) async {
    if (!mounted) return;
    setState(() => isAnimating = true);
    await _playSound(fileName);
    await Future.delayed(const Duration(milliseconds: 1800));
    if (mounted) setState(() => isAnimating = false);
  }

  String _getCurrentTurnText() {
    if (!widget.isBotGame) return engine.tigerTurn ? '🐅 Tiger' : '🐐 Goat';
    if (currentPlayerSide == 'tiger') {
      return engine.tigerTurn ? '🐅 Your turn' : '🐐 Bot turn';
    } else {
      return engine.tigerTurn ? '🐅 Bot turn' : '🐐 Your turn';
    }
  }

  String _formatTime(int seconds) {
    int minutes = seconds ~/ 60;
    int secs = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Color _getTimerColor() {
    if (_timeRemaining <= 10) return Colors.red;
    if (_timeRemaining <= 20) return Colors.orange;
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Round $currentRound', style: const TextStyle(fontSize: 16)),
        centerTitle: true,
        backgroundColor: Colors.brown[700],
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.green.shade700, Colors.green.shade900],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 10),
                
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(color: Colors.black.withOpacity(0.4), borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.access_time, color: Colors.amber, size: 14),
                      const SizedBox(width: 4),
                      Text(_formatTime(_roundTimeRemaining), 
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, 
                          color: _roundTimeRemaining <= 60 ? Colors.red : Colors.white)),
                    ],
                  ),
                ),
                
                const SizedBox(height: 10),
                
                Container(
                  width: boardSize + 40,
                  height: boardSize + 40,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.brown.shade700,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
                  ),
                  child: GestureDetector(
                    onTapUp: _onBoardTap,
                    child: Container(
                      key: _boardKey,
                      width: boardSize,
                      height: boardSize,
                      decoration: BoxDecoration(color: Colors.brown.shade300, borderRadius: BorderRadius.circular(10)),
                      child: Stack(
                        children: [
                          const BoardWidget(),
                          
                          if (_botMovePreview != null)
                            Positioned(
                              left: _botMovePreview!.dx - 20,
                              top: _botMovePreview!.dy - 20,
                              width: 40,
                              height: 40,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.yellow.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.yellow, width: 3),
                                ),
                                child: Center(
                                  child: Text(
                                    _botMoveType == 'goat_place' ? '🐐' : '🐅',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ),
                              ),
                            ),
                          
                          if (engine.selectedTigerIndex != null)
                            ...engine.validTigerMoves(engine.selectedTigerIndex!).map((pos) => 
                              Positioned(left: pos.dx - 12, top: pos.dy - 12, child: ValidMoveIndicator(position: pos))),
                          if (engine.selectedGoat != null)
                            ...engine.validGoatMoves().map((pos) => 
                              Positioned(left: pos.dx - 12, top: pos.dy - 12, child: ValidMoveIndicator(position: pos))),
                          ..._currentTigerPositions.entries.map((e) => 
                            Positioned(
                              left: e.value.dx - 15, top: e.value.dy - 15, width: 30, height: 30,
                              child: TigerToken(position: e.value, highlight: engine.selectedTigerIndex == e.key, 
                                isKillingMove: engine.isTigerKilling && engine.selectedTigerIndex == e.key))),
                          ..._goatPositionsById.entries.map((e) {
                            final id = e.key;
                            final pos = e.value;
                            final bool isDead = _killedGoatIds.contains(id) || _eliminatedGoatId == id;
                            return Positioned(
                              left: pos.dx - 15, top: pos.dy - 15, width: 30, height: 30,
                              child: AnimatedOpacity(
                                duration: const Duration(milliseconds: 800),
                                opacity: isDead ? 0.0 : 1.0,
                                child: GoatToken(position: pos, isDead: isDead),
                              ),
                            );
                          }),
                          
                          if (isBotThinking)
                            Container(
                              color: Colors.black.withOpacity(0.3),
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    CircularProgressIndicator(color: Colors.white),
                                    SizedBox(height: 8),
                                    Text('Bot thinking...', style: TextStyle(color: Colors.white, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                
                Container(
                  padding: const EdgeInsets.all(10),
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: BoxDecoration(
                    color: Colors.brown.shade800,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Column(
                    children: [
                      Text(_getCurrentTurnText(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amber)),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.timer, color: _getTimerColor(), size: 14),
                          const SizedBox(width: 4),
                          Text('$_timeRemaining', style: TextStyle(
                            fontSize: 14, 
                            fontWeight: FontWeight.bold, 
                            color: _getTimerColor()
                          )),
                          const SizedBox(width: 2),
                          Text('sec', style: TextStyle(
                            color: _getTimerColor().withOpacity(0.7), 
                            fontSize: 10
                          )),
                          if (_timeViolationCount > 0) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.red,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                '$_timeViolationCount',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text('Placed: ${engine.totalGoatsPlaced}/${GameEngine.maxGoats} | Eaten: ${engine.goatsEaten}', 
                        style: const TextStyle(fontSize: 10, color: Colors.white)),
                      if (engine.tigerTurn) 
                        const Text('Tiger Time: 60 sec', style: TextStyle(fontSize: 8, color: Colors.white70)),
                      if (!engine.tigerTurn)
                        const Text('Goat Time: 20 sec', style: TextStyle(fontSize: 8, color: Colors.white70)),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
