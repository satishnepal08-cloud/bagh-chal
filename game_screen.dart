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

class _GameScreenState extends State<GameScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late GameEngine engine;
  late BotService botService;
  double boardSize = 300;
  final GlobalKey _boardKey = GlobalKey();

  final AudioPlayer _audioPlayer = AudioPlayer();
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
  Timer? _autoTransitionTimer;
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
    _cancelAllTimers();
    _audioPlayer.dispose();
    _animationController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _initializeEngine() {
    engine = GameEngine(boardSize: boardSize);
    engine.onSelectToken = () => _playSoundNonBlocking('select.mp3');

    engine.onGoatMove = () {
      _playSoundNonBlocking('goat_move.mp3');
      _onMoveCompleted();
    };
    
    engine.onTigerMove = () {
      _playSoundNonBlocking('tiger_move.mp3');
      if (!engine.isTigerKilling) {
        _onMoveCompleted();
      }
    };
    
    engine.onGoatKill = _handleTigerKill;

    engine.onRoundEnd = (round, goatsKilled) {
      print('🎯 GameScreen: onRoundEnd callback triggered - round: $round, goatsKilled: $goatsKilled');
      if (mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_isHandlingRoundEnd) {
            print('🎯 GameScreen: Executing _handleRoundEnd');
            _isHandlingRoundEnd = true;
            _handleRoundEnd(round, goatsKilled);
          } else {
            print('❌ GameScreen: _handleRoundEnd blocked - _isHandlingRoundEnd: $_isHandlingRoundEnd');
          }
        });
      }
    };

    engine.onBoardUpdate = () {
      if (mounted) setState(() {});
    };
  }

  void _onMoveCompleted() {
    if (!mounted || engine.gameOver || engine.roundCompleted) {
      _cancelAllTimers();
      return;
    }

    setState(() {
      engine.tigerTurn = !engine.tigerTurn;
    });

    _resetMoveTimer();

    if (widget.isBotGame && _isBotTurn()) {
      _scheduleBotMove(delayMs: 800);
    } else {
      _cancelBotDelayTimer();
    }
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

  void _handleTigerKill(int goatIndex, Offset tigerPos) {
    if (goatIndex < 0 || goatIndex >= engine.goatPositions.length) return;

    final Offset killedGoatPosition = engine.goatPositions[goatIndex];
    int? killedGoatId;
    for (final entry in _goatPositionsById.entries) {
      if ((entry.value - killedGoatPosition).distance < 1) {
        killedGoatId = entry.key;
        break;
      }
    }
    if (killedGoatId == null) return;

    final safeKilledGoatId = killedGoatId;

    if (currentPlayerSide == 'tiger') {
      _playerGoatsKilledAsTiger = engine.goatsKilledThisRound;
    } else {
      _botGoatsKilledAsTiger = engine.goatsKilledThisRound;
    }

    _cancelMoveTimer();

    final bool roundWasCompletedBeforeKill = engine.roundCompleted;
    print('🎯 Before kill animation - roundWasCompletedBeforeKill: $roundWasCompletedBeforeKill');

    setState(() {
      _killedGoatIds.add(safeKilledGoatId);
      engine.isTigerKilling = true;
    });

    _playSoundNonBlocking('tiger_kill.mp3');

    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        setState(() {
          _goatPositionsById.remove(safeKilledGoatId);
          _goatTargetPositions.remove(safeKilledGoatId);
          _killedGoatIds.remove(safeKilledGoatId);
          engine.selectedTigerIndex = null;
          engine.isTigerKilling = false;
        });
      
        final bool roundCompletedNow = engine.roundCompleted;
        print('🎯 After kill animation - roundWasCompletedBeforeKill: $roundWasCompletedBeforeKill, roundCompletedNow: $roundCompletedNow');
      
        if (roundCompletedNow && !roundWasCompletedBeforeKill) {
          print('🎯 Round completed DURING kill animation - dialog should appear via onRoundEnd callback');
        } else if (!engine.gameOver && !roundCompletedNow) {
          print('🎯 Round not completed - calling _onMoveCompleted()');
          _onMoveCompleted();
        } else {
          print('🎯 Game over or round already completed - no further action needed');
        }
      }
    });
  }

  void _onBoardTap(TapUpDetails details) {
    if (!mounted ||
        isBotThinking ||
        engine.isTigerKilling ||
        _showingEliminationWarning ||
        engine.gameOver ||
        _isHandlingRoundEnd) {
      return;
    }
    if (widget.isBotGame && _isBotTurn()) return;

    final RenderBox? box =
        _boardKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null) return;

    final local = box.globalToLocal(details.globalPosition);
    final Offset tapped = engine.snapToGrid(local);

    final previousGoatPositions = List<Offset>.from(engine.goatPositions);
    final previousGoatCount = engine.goatPositions.length;
    final previousTigerPositions = List<Offset>.from(engine.tigerPositions);

    engine.handleTap(tapped);

    setState(() {
      final goatCountChanged = engine.goatPositions.length != previousGoatCount;
      final tigerMoved =
          !_listsEqual(previousTigerPositions, engine.tigerPositions);
      final goatMoved = !_listsEqual(previousGoatPositions, engine.goatPositions) &&
          !goatCountChanged;

      if (goatCountChanged && engine.goatPositions.length > previousGoatCount) {
        final newPos = engine.goatPositions.last;
        final newId = _nextGoatId++;
        _goatPositionsById[newId] = newPos;
        _goatTargetPositions[newId] = newPos;
      } else if (goatMoved) {
        Offset? movedFromPos;
        for (final oldPos in previousGoatPositions) {
          if (!engine.goatPositions
              .any((newPos) => (newPos - oldPos).distance < 1)) {
            movedFromPos = oldPos;
            break;
          }
        }

        Offset? movedToPos;
        for (final newPos in engine.goatPositions) {
          if (!previousGoatPositions
              .any((oldPos) => (oldPos - newPos).distance < 1)) {
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
    if (!mounted ||
        isBotThinking ||
        engine.gameOver ||
        !_isBotTurn() ||
        _showingEliminationWarning ||
        engine.roundCompleted) {
      return;
    }

    _cancelBotDelayTimer();
    setState(() => isBotThinking = true);

    try {
      await Future.delayed(const Duration(milliseconds: 1000));

      if (!mounted || engine.gameOver || !_isBotTurn() || engine.roundCompleted) {
        if (mounted) setState(() => isBotThinking = false);
        return;
      }

      final botMove = await botService.getBotMoveWithDelay(engine);

      if (!mounted || engine.gameOver || engine.roundCompleted) {
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

            if (botMove['type'] == 'goat_place' &&
                engine.goatPositions.length > previousGoatCount) {
              final newPos = engine.goatPositions.last;
              final newId = _nextGoatId++;
              _goatPositionsById[newId] = newPos;
              _goatTargetPositions[newId] = newPos;
            } else if (botMove['type'] == 'goat_move') {
              Offset? movedFromPos;
              for (final oldPos in previousGoatPositions) {
                if (!engine.goatPositions
                    .any((newPos) => (newPos - oldPos).distance < 1)) {
                  movedFromPos = oldPos;
                  break;
                }
              }

              Offset? movedToPos;
              for (final newPos in engine.goatPositions) {
                if (!previousGoatPositions
                    .any((oldPos) => (oldPos - newPos).distance < 1)) {
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
        if (mounted && !engine.gameOver && !engine.roundCompleted) {
          _onMoveCompleted();
        }
      }
    } catch (e) {
      if (mounted && !engine.gameOver && !engine.roundCompleted) {
        _onMoveCompleted();
      }
    } finally {
      if (mounted) setState(() => isBotThinking = false);
    }
  }

  bool _isBotTurn() {
    if (!widget.isBotGame) return false;
    return botService.isBotTurn(engine, currentPlayerSide);
  }

  void _startMoveTimer() {
    _timeRemaining = engine.tigerTurn ? 60 : 20;

    _moveTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || engine.gameOver || engine.roundCompleted) {
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
    if (mounted && !engine.gameOver && !engine.roundCompleted) {
      _startMoveTimer();
    }
  }

  void _cancelMoveTimer() {
    _moveTimer?.cancel();
    _moveTimer = null;
  }

  void _startRoundTimer() {
    _roundTimeRemaining = 600;

    _roundTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || engine.gameOver || engine.roundCompleted) {
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
    _roundTimer?.cancel();
    _roundTimer = null;
  }

  void _scheduleBotMove({required int delayMs}) {
    _cancelBotDelayTimer();
    _botMoveDelayTimer = Timer(Duration(milliseconds: delayMs), () {
      if (mounted &&
          _isBotTurn() &&
          !engine.gameOver &&
          !isBotThinking &&
          !engine.roundCompleted) {
        _makeBotMove();
      }
    });
  }

  void _cancelBotDelayTimer() {
    _botMoveDelayTimer?.cancel();
    _botMoveDelayTimer = null;
  }

  void _cancelAutoTransitionTimer() {
    _autoTransitionTimer?.cancel();
    _autoTransitionTimer = null;
  }

  void _cancelAllTimers() {
    _cancelMoveTimer();
    _cancelRoundTimer();
    _cancelBotDelayTimer();
    _cancelAutoTransitionTimer();
  }

  void _handleMoveTimeOut() {
    if (!mounted ||
        engine.gameOver ||
        _showingEliminationWarning ||
        engine.roundCompleted) return;

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

    if (!engine.gameOver && !engine.roundCompleted) {
      _onMoveCompleted();
    } else {
      _cancelAllTimers();
    }

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
        }
      });
    } else {
      setState(() {
        engine.goatPositions.remove(goatToRemove);
      });
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
                'Time Violation! One $playerRole eliminated',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
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

    _cancelAllTimers();

    String winner;
    String reason;

    if (widget.isBotGame) {
      winner = 'Bot Wins!';
      reason = 'Player exceeded time limit multiple times';
    } else {
      winner = engine.tigerTurn ? 'Goat Wins!' : 'Tiger Wins!';
      reason =
          '${engine.tigerTurn ? 'Tiger' : 'Goat'} player exceeded time limit multiple times';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.timer_off, color: Colors.red, size: 20),
            SizedBox(width: 8),
            Text("Game Over - Time Violation",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.emoji_events, size: 40, color: Colors.amber),
            const SizedBox(height: 12),
            Text(winner,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text('Reason:',
                      style:
                          TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(reason,
                      style: const TextStyle(fontSize: 11, color: Colors.red)),
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
              child: const Text("Home", style: TextStyle(fontSize: 12))),
          ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _restartGame();
              },
              child: const Text("Play Again", style: TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  void _handleRoundTimeOut() {
    if (!mounted) return;
    _cancelAllTimers();
    _handleRoundEnd(currentRound, engine.goatsKilledThisRound);
  }

  void _handleRoundEnd(int round, int goatsKilled) {
    print('🎯 _handleRoundEnd executing - round: $round, goatsKilled: $goatsKilled');
    
    if (!mounted) {
      print('❌ _handleRoundEnd: Not mounted, returning');
      return;
    }

    _cancelAllTimers();

    if (round == 1) {
      if (currentPlayerSide == 'tiger') {
        _playerGoatsKilledAsTiger = goatsKilled;
      } else {
        _botGoatsKilledAsTiger = goatsKilled;
      }

      print('🎯 Showing Round 1 completion dialog');
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text("Round 1 Complete!",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.sports_score, size: 40, color: Colors.blue),
              const SizedBox(height: 12),
              Text('${engine.winner}',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(
                  'Goats killed by ${currentPlayerSide == 'tiger' ? 'You' : 'Bot'}: $goatsKilled',
                  style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 8),
              Text(
                  'In Round 2, you will play as: ${currentPlayerSide == 'tiger' ? 'Goat' : 'Tiger'}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Starting round 2 in 3 seconds...',
                  style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ),
      );

      _autoTransitionTimer = Timer(const Duration(seconds: 3), () {
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
          _isHandlingRoundEnd = false;
          _startRound2();
        }
      });
    } else {
      if (currentPlayerSide == 'tiger') {
        _playerGoatsKilledAsTiger = goatsKilled;
      } else {
        _botGoatsKilledAsTiger = goatsKilled;
      }
      _showFinalResults();
    }
  }

  void _showFinalResults() {
  _isHandlingRoundEnd = false; // ✅ CRITICAL MISSING LINE ADDED HERE
  if (!mounted) return;

  String winner;
  String winnerDescription;

  if (_playerGoatsKilledAsTiger > _botGoatsKilledAsTiger) {
    winner = 'You Win! 🎉';
    winnerDescription = 'You killed more goats as tiger';
  } else if (_botGoatsKilledAsTiger > _playerGoatsKilledAsTiger) {
    winner = 'Bot Wins! 🤖';
    winnerDescription = 'Bot killed more goats as tiger';
  } else {
    winner = 'Draw! 🤝';
    winnerDescription = 'Both killed equal goats as tiger';
  }

  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: const Text("Game Complete!",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            winner.contains('You Win')
                ? Icons.emoji_events
                : winner.contains('Bot Wins')
                    ? Icons.computer
                    : Icons.handshake,
            size: 50,
            color: winner.contains('Win') ? Colors.amber : Colors.blue,
          ),
          const SizedBox(height: 16),
          Text(winner,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(winnerDescription,
              style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                const Text('Final Score (Goats Killed as Tiger)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        const Text('You',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('$_playerGoatsKilledAsTiger',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    Column(
                      children: [
                        const Text('Bot',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.bold)),
                        Text('$_botGoatsKilledAsTiger',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
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
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text("Home", style: TextStyle(fontSize: 14))),
        ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _restartGame();
            },
            child: const Text("Play Again", style: TextStyle(fontSize: 14))),
      ],
    ),
  );
}

  void _startRound2() {
    if (!mounted) return;

    _cancelAllTimers();

    String newPlayerSide = currentPlayerSide == 'tiger' ? 'goat' : 'tiger';
    
    print('🔄 Starting Round 2 - Switching roles:');
    print('🔄 Previous role: $currentPlayerSide');
    print('🔄 New role: $newPlayerSide');

    setState(() {
      currentRound = 2;
      currentPlayerSide = newPlayerSide;
      _timeViolationCount = 0;
      _showingEliminationWarning = false;
      _isHandlingRoundEnd = false;

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

    _cancelAllTimers();

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

  void _playSoundNonBlocking(String fileName) {
    _audioPlayer
        .setSource(AssetSource('audio/$fileName'))
        .then((_) => _audioPlayer.resume());
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

  Widget _buildPlayerProfile({
    required String role,
    required bool isBot,
    required bool isActive,
  }) {
    final int goatsKilled = isBot ? _botGoatsKilledAsTiger : _playerGoatsKilledAsTiger;
    final String displayRole = role == 'tiger' ? 'Tiger' : 'Goat';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isActive ? Colors.brown.shade800 : Colors.brown.shade700.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isActive ? Colors.amber : Colors.transparent,
          width: isActive ? 1.5 : 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 12,
            backgroundColor: Colors.amber,
            child: Text(
              isBot ? 'Bot' : 'You',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 6),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isBot ? 'Bot' : 'You',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    displayRole,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '$goatsKilled',
                    style: TextStyle(
                      color: Colors.amber.shade200,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (isActive) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: _getTimerColor().withOpacity(0.2),
                borderRadius: BorderRadius.circular(5),
                border: Border.all(color: _getTimerColor(), width: 1),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.timer, color: _getTimerColor(), size: 12),
                  const SizedBox(width: 2),
                  Text(
                    '$_timeRemaining',
                    style: TextStyle(
                      color: _getTimerColor(),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isBotActive = widget.isBotGame && _isBotTurn();
    final bool isPlayerActive = !widget.isBotGame || !_isBotTurn();

    String botRole = '';
    String playerRole = '';

    if (widget.isBotGame) {
      if (currentPlayerSide == 'tiger') {
        playerRole = 'tiger';
        botRole = 'goat';
      } else {
        playerRole = 'goat';
        botRole = 'tiger';
      }
    }

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
        child: Column(
          children: [
            if (widget.isBotGame)
              _buildPlayerProfile(
                role: botRole,
                isBot: true,
                isActive: isBotActive,
              ),

            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(height: 10),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.access_time, color: Colors.amber, size: 14),
                            const SizedBox(width: 4),
                            Text(
                              _formatTime(_roundTimeRemaining),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: _roundTimeRemaining <= 60 ? Colors.red : Colors.white,
                              ),
                            ),
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
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 5),
                            )
                          ],
                        ),
                        child: GestureDetector(
                          onTapUp: _onBoardTap,
                          child: Container(
                            key: _boardKey,
                            width: boardSize,
                            height: boardSize,
                            decoration: BoxDecoration(
                              color: Colors.brown.shade300,
                              borderRadius: BorderRadius.circular(10),
                            ),
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
                                          _botMoveType == 'goat_place' ? 'Goat' : 'Tiger',
                                          style: const TextStyle(fontSize: 16),
                                        ),
                                      ),
                                    ),
                                  ),

                                if (engine.selectedTigerIndex != null)
                                  ...engine.validTigerMoves(engine.selectedTigerIndex!).map((pos) =>
                                      Positioned(
                                        left: pos.dx - 12,
                                        top: pos.dy - 12,
                                        child: ValidMoveIndicator(position: pos),
                                      )),
                                if (engine.selectedGoat != null)
                                  ...engine.validGoatMoves().map((pos) =>
                                      Positioned(
                                        left: pos.dx - 12,
                                        top: pos.dy - 12,
                                        child: ValidMoveIndicator(position: pos),
                                      )),

                                ..._currentTigerPositions.entries.map((e) =>
                                    Positioned(
                                      left: e.value.dx - 15,
                                      top: e.value.dy - 15,
                                      width: 30,
                                      height: 30,
                                      child: TigerToken(
                                        position: e.value,
                                        highlight: engine.selectedTigerIndex == e.key,
                                        isKillingMove: engine.isTigerKilling && engine.selectedTigerIndex == e.key,
                                      ),
                                    )),

                                ..._goatPositionsById.entries.map((e) {
                                  final id = e.key;
                                  final pos = e.value;
                                  final bool isDead = _killedGoatIds.contains(id) || _eliminatedGoatId == id;
                                  return Positioned(
                                    left: pos.dx - 15,
                                    top: pos.dy - 15,
                                    width: 30,
                                    height: 30,
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
                                          Text(
                                            'Bot thinking...',
                                            style: TextStyle(color: Colors.white, fontSize: 12),
                                          ),
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
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: Colors.brown.shade800,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            )
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                const Text('Placed',
                                    style: TextStyle(fontSize: 9, color: Colors.white70)),
                                Text(
                                  '${engine.totalGoatsPlaced}/${GameEngine.maxGoats}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber,
                                  ),
                                ),
                              ],
                            ),
                            Container(width: 1, height: 30, color: Colors.white30),
                            Column(
                              children: [
                                const Text('Eaten',
                                    style: TextStyle(fontSize: 9, color: Colors.white70)),
                                Text(
                                  '${engine.goatsEaten}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.redAccent,
                                  ),
                                ),
                              ],
                            ),
                            if (_timeViolationCount > 0) ...[
                              Container(width: 1, height: 30, color: Colors.white30),
                              Column(
                                children: [
                                  const Text('Warnings',
                                      style: TextStyle(fontSize: 9, color: Colors.white70)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '$_timeViolationCount',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
            ),

            if (widget.isBotGame)
              _buildPlayerProfile(
                role: playerRole,
                isBot: false,
                isActive: isPlayerActive,
              ),
          ],
        ),
      ),
    );
  }
}
