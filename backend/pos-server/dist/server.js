import { Bonjour } from 'bonjour-service';
import express from 'express';
import { createServer } from 'http';
import { Server } from 'socket.io';
const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
    cors: {
        origin: "*",
        methods: ["GET", "POST"]
    }
});
const PORT = 3000;
const bonjour = new Bonjour();
// Publish the service with correct service type
const service = bonjour.publish({
    name: 'pos-server',
    type: 'pos-server', // This becomes _pos-server._tcp.local
    port: PORT,
    protocol: 'tcp'
});
console.log(`✅ mDNS service published as: ${service.fqdn}`);
// Store active intervals to clean up properly
const activeIntervals = new Map();
// Socket.IO connection handling
io.on('connection', (socket) => {
    console.log('📱 Client connected:', socket.id);
    // Send test order updates
    const interval = setInterval(() => {
        socket.emit('order-update', {
            orderId: Math.floor(Math.random() * 1000),
            status: 'preparing',
            timestamp: new Date().toISOString()
        });
    }, 5000);
    // Store interval for cleanup
    activeIntervals.set(socket.id, interval);
    socket.on('disconnect', () => {
        console.log('📱 Client disconnected:', socket.id);
        // Clean up interval
        const interval = activeIntervals.get(socket.id);
        if (interval) {
            clearInterval(interval);
            activeIntervals.delete(socket.id);
        }
    });
});
httpServer.listen(PORT, '0.0.0.0', () => {
    console.log(`🚀 Server running on port ${PORT}`);
    console.log(`📡 Local network access: http://<your-ip>:${PORT}`);
});
// Graceful shutdown
const shutdown = () => {
    console.log('\n🛑 Shutting down gracefully...');
    // Clear all active intervals
    activeIntervals.forEach(interval => clearInterval(interval));
    activeIntervals.clear();
    // Stop mDNS service
    service.stop();
    bonjour.destroy();
    // Close server
    httpServer.close(() => {
        console.log('✅ Server closed');
        process.exit(0);
    });
};
process.on('SIGINT', shutdown);
process.on('SIGTERM', shutdown);
//# sourceMappingURL=server.js.map