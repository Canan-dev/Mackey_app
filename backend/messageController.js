// messageController.js - basic message handling
module.exports.handleMessage = async (io, socket, msg) => {
  // Simple validation
  if (!msg || !msg.content) {
    socket.emit('error', { error: 'Message content missing' });
    return;
  }
  // Broadcast to all connected clients (or could emit to specific recipient)
  io.emit('chatMessage', {
    from: socket.user.username || socket.user.id,
    to: msg.to || 'broadcast',
    content: msg.content,
    timestamp: new Date().toISOString()
  });
};
