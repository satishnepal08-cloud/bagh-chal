import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'game_screen.dart';

class BotSelectionScreen extends StatefulWidget {
  const BotSelectionScreen({super.key});

  @override
  State<BotSelectionScreen> createState() => _BotSelectionScreenState();
}

class _BotSelectionScreenState extends State<BotSelectionScreen> {
  bool _hasSavedGame = false;
  Map<String, dynamic>? _savedGameState;

  @override
  void initState() {
    super.initState();
    _checkForSavedGame();
  }

  Future<void> _checkForSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSavedGame = prefs.getBool('hasSavedGame') ?? false;
    
    if (hasSavedGame) {
      // Try to load saved game state
      final savedState = prefs.getString('savedGameState');
      if (savedState != null) {
        setState(() {
          _hasSavedGame = true;
          // In a real implementation, you'd parse this JSON
        });
      } else {
        // Clear invalid saved game
        await prefs.remove('hasSavedGame');
      }
    }
  }

  void _startBotGame(String playerSide) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GameScreen(
          isBotGame: true,
          playerSide: playerSide,
        ),
      ),
    );
  }

  void _resumeGame() {
    if (_savedGameState != null) {
      // Navigate with saved state
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GameScreen(
            isBotGame: true,
            playerSide: _savedGameState!['playerSide'] ?? 'tiger',
            // Pass saved state to game screen
          ),
        ),
      );
    } else {
      // Fallback to new game
      _startBotGame('tiger');
    }
  }

  void _deleteSavedGame() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('hasSavedGame');
    await prefs.remove('savedGameState');
    
    setState(() {
      _hasSavedGame = false;
      _savedGameState = null;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Saved game deleted')),
    );
  }

  void _goBack(BuildContext context) {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Practice with Bot'),
        centerTitle: true,
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _goBack(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              
              const Icon(
                Icons.smart_toy,
                size: 50,
                color: Colors.orange,
              ),
              const SizedBox(height: 10),
              
              const Text(
                'Practice with Bot',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(height: 5),
              
              const Text(
                'Choose your side to start playing',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 30),
              
              if (_hasSavedGame) ...[
                Card(
                  elevation: 3,
                  color: Colors.orange.shade50,
                  child: SizedBox(
                    width: 200,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: [
                          const Text(
                            'Continue Your Game',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.orange,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              SizedBox(
                                width: 80,
                                height: 35,
                                child: ElevatedButton(
                                  onPressed: _resumeGame,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  child: const Text(
                                    'Resume',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 80,
                                height: 35,
                                child: OutlinedButton(
                                  onPressed: _deleteSavedGame,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                    padding: const EdgeInsets.symmetric(horizontal: 8),
                                  ),
                                  child: const Text(
                                    'Delete',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),
                const Text(
                  'Start New Game',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const SizedBox(height: 20),
              ],
              
              SizedBox(
                width: 180,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _startBotGame('tiger'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🐯'),
                      SizedBox(width: 8),
                      Text(
                        'Play as Tiger',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 15),
              
              SizedBox(
                width: 180,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => _startBotGame('goat'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🐐'),
                      SizedBox(width: 8),
                      Text(
                        'Play as Goat',
                        style: TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 30),
              
              Container(
                width: 250,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  children: [
                    Text(
                      'Game Features',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      '• Smart AI opponent\n• 60-second timer per move\n• Smooth animations\n• Save and resume games',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
