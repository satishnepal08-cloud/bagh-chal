const express = require("express");
const http = require("http");
const cors = require("cors");
const { Server } = require("socket.io");

const app = express();
app.use(cors());
app.use(express.json());

// Store game rooms in memory
const gameRooms = new Map();

// HTTP health check
app.get("/", (req, res) => {
  res.json({
    message: "🎮 Real-Time Bagh Chal Server Running",
    rooms: gameRooms.size,
    timestamp: new Date().toISOString(),
  });
});

// Create HTTP server (REQUIRED for WebSockets)
const server = http.createServer(app);

// Create Socket.IO instance
const io = new Server(server, {
  cors: {
    origin: "*",
  },
});

// SOCKET.IO LOGIC
io.on("connection", (socket) => {
  console.log("🟢 Player connected:", socket.id);

  // Player creates room
  socket.on("createRoom", ({ roomCode, playerName }) => {
    if (gameRooms.has(roomCode)) {
      socket.emit("roomError", "Room already exists");
      return;
    }

    gameRooms.set(roomCode, {
      players: [socket.id],
      names: { [socket.id]: playerName },
      gameState: null,
    });

    socket.join(roomCode);

    console.log(`🏠 Room ${roomCode} created by ${playerName}`);
    socket.emit("roomCreated", roomCode);
  });

  // Player joins an existing room
  socket.on("joinRoom", ({ roomCode, playerName }) => {
    const room = gameRooms.get(roomCode);

    if (!room) {
      socket.emit("roomError", "Room not found");
      return;
    }

    if (room.players.length >= 2) {
      socket.emit("roomError", "Room is full");
      return;
    }

    room.players.push(socket.id);
    room.names[socket.id] = playerName;

    socket.join(roomCode);

    console.log(`👥 Player ${playerName} joined room ${roomCode}`);

    // Notify both players that game can start
    io.to(roomCode).emit("playersReady", room.names);
  });

  // When a player makes a move
  socket.on("move", ({ roomCode, gameState }) => {
    const room = gameRooms.get(roomCode);
    if (!room) return;

    room.gameState = gameState;

    // Broadcast move to other player
    socket.to(roomCode).emit("opponentMove", gameState);
  });

  // Handle disconnect
  socket.on("disconnect", () => {
    console.log("🔴 Player disconnected:", socket.id);

    // Remove player from rooms
    for (const [roomCode, room] of gameRooms) {
      if (room.players.includes(socket.id)) {
        room.players = room.players.filter(p => p !== socket.id);
        delete room.names[socket.id];

        // If room empty → delete it
        if (room.players.length === 0) {
          gameRooms.delete(roomCode);
          console.log(`🗑️ Room ${roomCode} deleted (empty)`);
        } else {
          // Notify remaining player
          io.to(roomCode).emit("opponentLeft");
        }
      }
    }
  });
});

// Start server
const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`🚀 Real-time server running on ${PORT}`);
});
