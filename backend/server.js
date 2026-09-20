// server.js - Express + Socket.IO real-time backend
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const dotenv = require('dotenv');
const { verifyToken } = require('./auth');
const { handleMessage } = require('./messageController');

dotenv.config();

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST'] }
});

// Health check endpoint
app.get('/health', (req, res) => res.send('OK'));

// Socket.io authentication middleware
io.use((socket, next) => {
  const token = socket.handshake.auth?.token;
  if (!token) return next(new Error('Authentication token missing'));
  try {
    const payload = verifyToken(token);
    socket.user = payload; // attach user info
    next();
  } catch (err) {
    next(new Error('Invalid token'));
  }
});

io.on('connection', (socket) => {
  console.log(`User ${socket.user.username} connected`);

  socket.on('chatMessage', async (msg) => {
    // Expected msg shape: { to: string, content: string }
    await handleMessage(io, socket, msg);
  });

  socket.on('disconnect', () => {
    console.log(`User ${socket.user.username} disconnected`);
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => console.log(`Server listening on port ${PORT}`));
