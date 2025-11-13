const express = require('express');
const cors = require('cors');
const app = express();

// ✅ ADD THIS - Store game rooms in memory
const gameRooms = new Map();

app.use(cors());
app.use(express.json());

// Health check
app.get('/', (req, res) => {
  res.json({ 
    message: '🎮 Bagh Chal Multiplayer Server is RUNNING!',
    status: 'OK ✅',
    timestamp: new Date().toISOString(),
    activeGames: gameRooms.size
  });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

// Create room
app.post('/create-room', (req, res) => {
  try {
    const { roomCode, playerName } = req.body;
    
    if (!roomCode || !playerName) {
      return res.status(400).json({ error: 'Room code and player name required' });
    }
    
    if (gameRooms.has(roomCode)) {
      return res.status(400).json({ error: 'Room already exists' });
    }
    
    gameRooms.set(roomCode, {
      players: [playerName],
      gameState: {
        tigerPositions: [
          {dx: 16, dy: 16},
          {dx: 284, dy: 16},
          {dx: 16, dy: 284},
          {dx: 284, dy: 284}
        ],
        goatPositions: [],
        totalGoatsPlaced: 0,
        goatsCaptured: 0,
        tigerTurn: true
      },
      createdAt: new Date()
    });
    
    console.log(`✅ Room created: ${roomCode} by ${playerName}`);
    res.json({ success: true, roomCode });
    
  } catch (error) {
    console.error('❌ Create room error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Check if room exists
app.get('/room-exists/:roomCode', (req, res) => {
  const { roomCode } = req.params;
  const exists = gameRooms.has(roomCode);
  res.json({ exists, roomCode });
});

// Join room
app.post('/join-room', (req, res) => {
  try {
    const { roomCode, playerName } = req.body;
    
    if (!roomCode || !playerName) {
      return res.status(400).json({ error: 'Room code and player name required' });
    }
    
    const room = gameRooms.get(roomCode);
    if (!room) {
      return res.status(404).json({ error: 'Room not found' });
    }
    
    if (room.players.length >= 2) {
      return res.status(400).json({ error: 'Room is full' });
    }
    
    room.players.push(playerName);
    console.log(`✅ Player ${playerName} joined room: ${roomCode}`);
    
    res.json({ success: true, roomCode });
    
  } catch (error) {
    console.error('❌ Join room error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Get game state
app.get('/game-state/:roomCode', (req, res) => {
  const { roomCode } = req.params;
  const room = gameRooms.get(roomCode);
  
  if (!room) {
    return res.status(404).json({ error: 'Room not found' });
  }
  
  res.json({ 
    success: true, 
    gameState: room.gameState,
    players: room.players
  });
});

// Make move
app.post('/make-move', (req, res) => {
  try {
    const { roomCode, gameState } = req.body;
    
    if (!roomCode || !gameState) {
      return res.status(400).json({ error: 'Room code and game state required' });
    }
    
    const room = gameRooms.get(roomCode);
    if (!room) {
      return res.status(404).json({ error: 'Room not found' });
    }
    
    // Update game state
    room.gameState = gameState;
    console.log(`✅ Game state updated for room: ${roomCode}`);
    
    res.json({ success: true });
    
  } catch (error) {
    console.error('❌ Make move error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🎮 Bagh Chal Server running on port ${PORT}`);
});
