// server.js
const express = require('express');
const http = require('http');
const socketIo = require('socket.io');
const cors = require('cors');

const app = express();
const server = http.createServer(app);
const io = socketIo(server, {
  cors: {
    origin: "*",
    methods: ["GET", "POST"]
  }
});

// Middleware
app.use(cors());
app.use(express.json());

// Store game rooms
const gameRooms = new Map();

// Health check endpoint
app.get('/', (req, res) => {
  res.json({ 
    status: 'Server is running', 
    message: 'Bagh Chal Game Server',
    timestamp: new Date().toISOString()
  });
});

// Health check endpoint for your Flutter app
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', server: 'Bagh Chal Game Server' });
});

// Create room endpoint
app.post('/create-room', (req, res) => {
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
      tigerPositions: [],
      goatPositions: [],
      totalGoatsPlaced: 0,
      goatsCaptured: 0,
      tigerTurn: true
    },
    createdAt: new Date()
  });
  
  console.log(`Room created: ${roomCode} by ${playerName}`);
  res.json({ success: true, roomCode });
});

// Check if room exists
app.get('/room-exists/:roomCode', (req, res) => {
  const { roomCode } = req.params;
  const exists = gameRooms.has(roomCode);
  res.json({ exists, roomCode });
});

// Join room endpoint
app.post('/join-room', (req, res) => {
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
  console.log(`Player ${playerName} joined room: ${roomCode}`);
  
  res.json({ success: true, roomCode });
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

// Make move endpoint
app.post('/make-move', (req, res) => {
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
  console.log(`Game state updated for room: ${roomCode}`);
  
  res.json({ success: true });
});

// Clean up old rooms (optional)
setInterval(() => {
  const now = new Date();
  let cleanedCount = 0;
  
  for (const [roomCode, room] of gameRooms.entries()) {
    const roomAge = now - room.createdAt;
    // Remove rooms older than 2 hours
    if (roomAge > 2 * 60 * 60 * 1000) {
      gameRooms.delete(roomCode);
      cleanedCount++;
    }
  }
  
  if (cleanedCount > 0) {
    console.log(`Cleaned up ${cleanedCount} old rooms`);
  }
}, 30 * 60 * 1000); // Run every 30 minutes

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`🎮 Bagh Chal Game Server running on port ${PORT}`);
  console.log(`📍 Health check: http://localhost:${PORT}/health`);
});
