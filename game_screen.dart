import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../widgets/board_painter.dart';
import '../widgets/tiger_token.dart';
import '../widgets/goat_token.dart';
import '../widgets/valid_move_indicator.dart';
import '../logic/game_engine.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late GameEngine engine;
  double boardSize = 300;
  final GlobalKey _boardKey = GlobalKey();

  final AudioPlayer _audioPlayer = AudioPlayer();
  bool isAudioPlaying = false; // block actions while sound is playing
  bool isAnimating = false; // block taps during smooth movement

  @override
  void initState() {
    super.initState();
    _initializeEngine();
  }

  void _initializeEngine() {
    engine = GameEngine(boardSize: boardSize);

    // Audio callbacks
    engine.onSelectToken = () => _playSound('select.mp3');
    engine.onGoatMove = () => _smoothMoveSound('goat_move.mp3');
    engine.onTigerMove = () => _smoothMoveSound('tiger_move.mp3');
    engine.onGoatKill = (int goatIndex, Offset tigerPos) =>
        _handleTigerKill(goatIndex, tigerPos);
  }

  Future<void> _playSound(String fileName) async {
    if (isAudioPlaying) return;
    try {
      setState(() => isAudioPlaying = true);
      await _audioPlayer.setSource(AssetSource('audio/$fileName'));
      await _audioPlayer.resume();
      _audioPlayer.onPlayerComplete.listen((event) {
        setState(() => isAudioPlaying = false);
      });
    } catch (e) {
      debugPrint('Error playing $fileName: $e');
      setState(() => isAudioPlaying = false);
    }
  }

  Future<void> _smoothMoveSound(String fileName) async {
    // used for goat/tiger smooth move
    setState(() => isAnimating = true);
    await _playSound(fileName);
    await Future.delayed(const Duration(seconds: 1));
    setState(() => isAnimating = false);
  }

  Future<void> _handleTigerKill(int goatIndex, Offset tigerPos) async {
    if (isAudioPlaying || isAnimating) return;

    setState(() => isAnimating = true);

    // Play tiger kill sound
    await _playSound('tiger_kill.mp3');

    // Highlight tiger and mark goat as killed by index
    setState(() {
      engine.killedGoats.add(goatIndex);
      engine.isTigerKilling = true;
    });

    // Wait 4 seconds for kill animation
    await Future.delayed(const Duration(seconds: 4));

    setState(() {
      engine.goatPositions.removeAt(goatIndex);
      engine.killedGoats.clear();
      engine.isTigerKilling = false;
      isAnimating = false;
    });
  }

  void _onBoardTap(TapUpDetails details) {
    if (isAudioPlaying || isAnimating || engine.isTigerKilling) return;

    final RenderBox box = _boardKey.currentContext!.findRenderObject() as RenderBox;
    final local = box.globalToLocal(details.globalPosition);
    final Offset tapped = engine.snapToGrid(local);

    setState(() {
      engine.handleTap(tapped);
    });

    if (engine.gameOver) {
      _showGameOverDialog(engine.winner);
    }
  }

  void _showGameOverDialog(String winner) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Game Over"),
        content: Text(winner),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _initializeEngine();
              });
            },
            child: const Text("Play Again"),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bagh Chal Game'),
        centerTitle: true,
        backgroundColor: Colors.brown[700],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTapUp: _onBoardTap,
                  child: SizedBox(
                    key: _boardKey,
                    width: boardSize,
                    height: boardSize,
                    child: Stack(
                      children: [
                        const BoardWidget(),

                        // Valid moves
                        if (engine.selectedTigerIndex != null)
                          ...engine.validTigerMoves(engine.selectedTigerIndex!).map(
                            (pos) => Positioned(
                              left: pos.dx - 12,
                              top: pos.dy - 12,
                              child: ValidMoveIndicator(position: pos),
                            ),
                          ),
                        if (engine.selectedGoat != null)
                          ...engine.validGoatMoves().map(
                            (pos) => Positioned(
                              left: pos.dx - 12,
                              top: pos.dy - 12,
                              child: ValidMoveIndicator(position: pos),
                            ),
                          ),

                        // Tigers
                        ...engine.tigerPositions.asMap().entries.map((e) {
                          int idx = e.key;
                          Offset pos = e.value;
                          return AnimatedPositioned(
                            duration: const Duration(seconds: 1),
                            curve: Curves.easeInOut,
                            left: pos.dx - 15,
                            top: pos.dy - 15,
                            width: 30,
                            height: 30,
                            child: TigerToken(
                              position: pos,
                              highlight: engine.selectedTigerIndex == idx,
                              isKillingMove: engine.isTigerKilling &&
                                  engine.selectedTigerIndex == idx,
                            ),
                          );
                        }),

                        // Goats
                        ...engine.goatPositions.asMap().entries.map((e) {
                          int idx = e.key;
                          Offset pos = e.value;
                          bool dead = engine.killedGoats.contains(idx);
                          return AnimatedPositioned(
                            duration: const Duration(seconds: 1),
                            curve: Curves.easeInOut,
                            left: pos.dx - 15,
                            top: pos.dy - 15,
                            width: 30,
                            height: 30,
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 500),
                              opacity: dead ? 0.0 : 1.0,
                              child: GoatToken(position: pos, isDead: dead),
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Text(
                        engine.tigerTurn ? '🐯 Tiger\'s Turn' : '🐐 Goat\'s Turn',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        'Goats placed: ${engine.totalGoatsPlaced}/${GameEngine.maxGoats} | Eaten: ${engine.goatsEaten}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
