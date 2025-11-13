import 'dart:math';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'matchmaking_screen.dart';
import 'bot_selection_screen.dart';
import 'store_screen.dart';
import 'friend_game_screen.dart'; // Add this import

class HomeScreen extends StatefulWidget {
  final User user;
  
  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _equippedAvatarPath;
  bool _showSidebar = false;

  @override
  void initState() {
    super.initState();
    _loadEquippedAvatar();
  }

  Future<void> _loadEquippedAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    
    final goatAvatars = {
      'goat_1': 'assets/images/classic_goat.png',
      'goat_2': 'assets/images/angry_goat.png',
      'goat_3': 'assets/images/guot_goat.png',
    };
    
    for (final entry in goatAvatars.entries) {
      final isEquipped = prefs.getBool('equipped_${entry.key}') ?? (entry.key == 'goat_1');
      if (isEquipped) {
        setState(() {
          _equippedAvatarPath = entry.value;
        });
        return;
      }
    }
    
    setState(() {
      _equippedAvatarPath = 'assets/images/classic_goat.png';
    });
  }

  ImageProvider _getProfileImage() {
    if (_equippedAvatarPath != null) {
      return AssetImage(_equippedAvatarPath!);
    } else if (widget.user.photoURL != null) {
      return NetworkImage(widget.user.photoURL!);
    } else {
      return const AssetImage('assets/images/classic_goat.png');
    }
  }

  bool _shouldShowPlaceholder() {
    return _equippedAvatarPath == null && 
           widget.user.photoURL == null;
  }

  Future<void> _signOut() async {
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: widget.user.uid));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('User ID copied!')),
    );
  }

  void _startOnlineMatchmaking(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => MatchmakingScreen(user: widget.user),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;
          
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);
          
          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  void _startBotGameSelection(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BotSelectionScreen(user: widget.user),
      ),
    );
  }

  // NEW METHOD: Handle friend game with mic
  void _startFriendGame(BuildContext context) {
    _showCreateJoinDialog(context);
  }

  void _showCreateJoinDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.people, color: Colors.purple),
            SizedBox(width: 8),
            Text('Play with Friend', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Choose an option to play with your friend:'),
            SizedBox(height: 16),
          ],
        ),
        actions: [
          // Create Room Button
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _createRoom(context);
            },
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Create Room'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
          
          // Join Room Button
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _joinRoom(context);
            },
            icon: const Icon(Icons.login, size: 18),
            label: const Text('Join Room'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _createRoom(BuildContext context) {
    // Generate a unique room code
    String roomCode = _generateRoomCode();
    
    // Navigate to waiting room
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FriendGameScreen(
          user: widget.user,
          roomCode: roomCode,
          isHost: true,
        ),
      ),
    );
  }

  void _joinRoom(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => JoinRoomDialog(
        onJoin: (roomCode) {
          Navigator.pop(context);
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FriendGameScreen(
                user: widget.user,
                roomCode: roomCode,
                isHost: false,
              ),
            ),
          );
        },
      ),
    );
  }

  String _generateRoomCode() {
    // Generate a 6-character alphanumeric code
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random();
    return String.fromCharCodes(
      Iterable.generate(6, (_) => chars.codeUnitAt(random.nextInt(chars.length)))
    );
  }

  void _showStore(BuildContext context) {
    setState(() {
      _showSidebar = false;
    });
    
    Future.delayed(const Duration(milliseconds: 300), () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => StoreScreen(user: widget.user),
        ),
      ).then((_) {
        _loadEquippedAvatar();
      });
    });
  }

  void _showPlayerVault() {
    setState(() {
      _showSidebar = false;
    });
    
    Future.delayed(const Duration(milliseconds: 300), () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Player Vault - Coming Soon!')),
      );
    });
  }

  void _showDeposit() {
    setState(() {
      _showSidebar = false;
    });
    
    Future.delayed(const Duration(milliseconds: 300), () {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deposit - Coming Soon!')),
      );
    });
  }

  void _showNameChangeDialog() {
    setState(() {
      _showSidebar = false;
    });
    
    Future.delayed(const Duration(milliseconds: 300), () {
      showDialog(
        context: context,
        builder: (context) => NameChangeDialog(
          user: widget.user,
          onNameUpdated: () {
            setState(() {});
          },
        ),
      );
    });
  }

  void _toggleSidebar() {
    setState(() {
      _showSidebar = !_showSidebar;
    });
  }

  void _closeSidebar() {
    if (_showSidebar) {
      setState(() {
        _showSidebar = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bagh Chal'),
        backgroundColor: Colors.green.withOpacity(0.9),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          onPressed: _toggleSidebar,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, size: 20),
            onPressed: _signOut,
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Stack(
        children: [
          // Full Screen Image Background
          Positioned.fill(
            child: Image.asset(
              'assets/images/bg.jpeg',
              fit: BoxFit.cover,
            ),
          ),

          // Dark overlay to make content more readable
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
            ),
          ),

          // Main Content - Game Buttons (Clean without white box)
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Game Mode Buttons - Clean design
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Online Play Button
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        child: ElevatedButton.icon(
                          onPressed: () => _startOnlineMatchmaking(context),
                          icon: const Icon(Icons.online_prediction, size: 24),
                          label: const Text(
                            'Play Online',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue.withOpacity(0.9),
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: Colors.blue.withOpacity(0.5),
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                      ),
                      
                      // NEW: Play with Friend Button
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        child: ElevatedButton.icon(
                          onPressed: () => _startFriendGame(context),
                          icon: const Icon(Icons.people_alt, size: 24),
                          label: const Text(
                            'Play with Friend',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.purple.withOpacity(0.9),
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: Colors.purple.withOpacity(0.5),
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                      ),
                      
                      // Practice with Bot Button
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 10),
                        child: ElevatedButton.icon(
                          onPressed: () => _startBotGameSelection(context),
                          icon: const Icon(Icons.smart_toy, size: 24),
                          label: const Text(
                            'Practice with Bot',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange.withOpacity(0.9),
                            foregroundColor: Colors.white,
                            elevation: 8,
                            shadowColor: Colors.orange.withOpacity(0.5),
                            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Overlay when sidebar is open - closes sidebar when tapped
          if (_showSidebar)
            Positioned.fill(
              child: GestureDetector(
                onTap: _closeSidebar,
                child: Container(
                  color: Colors.black.withOpacity(0.3),
                ),
              ),
            ),

          // Sidebar that slides in/out
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            left: _showSidebar ? 0 : -200,
            top: 0,
            bottom: 0,
            width: 200,
            child: GestureDetector(
              onTap: () {}, // Prevents tap from closing sidebar when tapping inside
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  border: const Border(right: BorderSide(color: Colors.green)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(2, 0),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Picture with equipped avatar
                      GestureDetector(
                        onTap: () => _showStore(context),
                        child: CircleAvatar(
                          radius: 30,
                          backgroundImage: _getProfileImage(),
                          child: _shouldShowPlaceholder()
                              ? const Icon(Icons.person, size: 25, color: Colors.white)
                              : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // User Name
                      GestureDetector(
                        onTap: _showNameChangeDialog,
                        child: Text(
                          widget.user.displayName ?? 'Player',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(height: 4),
                      
                      // Email
                      Text(
                        widget.user.email ?? '',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      
                      // Avatar Status
                      if (_equippedAvatarPath != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _getAvatarName(_equippedAvatarPath!),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                      
                      const SizedBox(height: 16),
                      const Divider(color: Colors.green),
                      const SizedBox(height: 8),
                      
                      // Player ID Section
                      const Text(
                        'Player ID:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      
                      GestureDetector(
                        onTap: () => _copyToClipboard(context),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                widget.user.uid.substring(0, 8) + '...',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.green,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(
                              Icons.copy,
                              size: 14,
                              color: Colors.green,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Menu Items as bullet points
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildBulletMenuItem(
                            text: 'Store',
                            icon: Icons.store,
                            onTap: () => _showStore(context),
                          ),
                          const SizedBox(height: 8),
                          _buildBulletMenuItem(
                            text: 'Player Vault',
                            icon: Icons.security,
                            onTap: _showPlayerVault,
                          ),
                          const SizedBox(height: 8),
                          _buildBulletMenuItem(
                            text: 'Deposit',
                            icon: Icons.credit_card,
                            onTap: _showDeposit,
                          ),
                        ],
                      ),
                      
                      const Spacer(),
                      
                      // Stats Section
                      Container(
                        padding: const EdgeInsets.all(8),
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Stats',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                            SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Games: 0',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  'Wins: 0',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.green,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
                      // Edit Profile Button
                      SizedBox(
                        width: double.infinity,
                        height: 32,
                        child: OutlinedButton.icon(
                          onPressed: _showNameChangeDialog,
                          icon: const Icon(Icons.edit, size: 14),
                          label: const Text('Change Name', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            side: const BorderSide(color: Colors.green),
                            backgroundColor: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getAvatarName(String path) {
    switch (path) {
      case 'assets/images/classic_goat.png':
        return 'Classic Goat';
      case 'assets/images/angry_goat.png':
        return 'Angry Goat';
      case 'assets/images/guot_goat.png':
        return 'Guot Goat';
      default:
        return 'Classic Goat';
    }
  }

  Widget _buildBulletMenuItem({
    required String text,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: 14,
                  color: Colors.green,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                size: 12,
                color: Colors.green,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// NEW: Join Room Dialog
class JoinRoomDialog extends StatefulWidget {
  final Function(String) onJoin;

  const JoinRoomDialog({super.key, required this.onJoin});

  @override
  State<JoinRoomDialog> createState() => _JoinRoomDialogState();
}

class _JoinRoomDialogState extends State<JoinRoomDialog> {
  final TextEditingController _roomCodeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Row(
              children: [
                Icon(Icons.login, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  'Join Room',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _roomCodeController,
              decoration: const InputDecoration(
                labelText: 'Room Code',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.code),
                hintText: 'Enter 6-digit code',
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      final roomCode = _roomCodeController.text.trim().toUpperCase();
                      if (roomCode.length == 6) {
                        widget.onJoin(roomCode);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a valid 6-digit room code'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Join'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class NameChangeDialog extends StatefulWidget {
  final User user;
  final VoidCallback onNameUpdated;

  const NameChangeDialog({
    super.key,
    required this.user,
    required this.onNameUpdated,
  });

  @override
  State<NameChangeDialog> createState() => _NameChangeDialogState();
}

class _NameChangeDialogState extends State<NameChangeDialog> {
  final TextEditingController _nameController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user.displayName ?? '';
  }

  Future<void> _updateName() async {
    final String newName = _nameController.text.trim();

    if (newName.isEmpty) {
      _showError('Please enter your name');
      return;
    }

    if (newName == widget.user.displayName) {
      _showError('Name is the same as current');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      await widget.user.updateDisplayName(newName);
      await widget.user.reload();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Name updated successfully!'),
            duration: Duration(seconds: 2),
          ),
        );
        widget.onNameUpdated();
        Navigator.pop(context);
      }
    } catch (e) {
      _showError('Failed to update name: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        width: 300,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Change Name',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Google Sign-in user',
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'New Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              maxLength: 30,
            ),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 35,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: SizedBox(
                    height: 35,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _updateName,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Update', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
