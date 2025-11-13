const express = require('express');
const cors = require('cors');
const app = express();

app.use(cors());
app.use(express.json());

let games = {};

app.get('/', (req, res) => {
  res.json({ 
    message: '🎮 Bagh Chal Multiplayer Server is RUNNING!',
    status: 'OK ✅',
    timestamp: new Date().toISOString(),
    activeGames: Object.keys(games).length
  });
});

// In create-room endpoint
app.post('/create-room', (req, res) => {
  const { roomCode, playerName } = req.body;
  
  if (!roomCode || !playerName) {
    return res.status(400).json({ error: 'Room code and player name required' });
  }
  
  if (gameRooms.has(roomCode)) {
    return res.status(400).json({ error: 'Room already exists' });
  }
  
  // ✅ Set initial tiger positions and tigerTurn: true
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
      tigerTurn: true  // ✅ Host (Tiger) starts first
    },
    createdAt: new Date()
  });
  
  console.log(`Room created: ${roomCode} by ${playerName}`);
  res.json({ success: true, roomCode });
});

app.post('/join-room', (req, res) => {
  const { roomCode, playerName } = req.body;
  
  if (!games[roomCode]) {
    return res.status(404).json({ error: 'Room not found' });
  }

  if (games[roomCode].guest) {
    return res.status(400).json({ error: 'Room is full' });
  }

  games[roomCode].guest = playerName;
  console.log(`🎮 Player JOINED: ${roomCode} - ${playerName}`);
  res.json({ success: true, roomCode });
});

app.post('/make-move', (req, res) => {
  const { roomCode, gameState } = req.body;
  
  if (!games[roomCode]) {
    return res.status(404).json({ error: 'Room not found' });
  }

  games[roomCode].gameState = gameState;
  games[roomCode].lastMove = Date.now();
  
  console.log(`🎯 Move in room: ${roomCode}`);
  res.json({ success: true });
});

app.get('/game-state/:roomCode', (req, res) => {
  const roomCode = req.params.roomCode;
  
  if (!games[roomCode]) {
    return res.status(404).json({ error: 'Room not found' });
  }

  res.json({
    success: true,
    gameState: games[roomCode].gameState,
    host: games[roomCode].host,
    guest: games[roomCode].guest
  });
});

app.get('/room-exists/:roomCode', (req, res) => {
  const roomCode = req.params.roomCode;
  res.json({ exists: !!games[roomCode] });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Bagh Chal Server running on port ${PORT}`);
  console.log(`⭐ Permanent multiplayer server ready!`);
});
