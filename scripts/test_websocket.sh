#!/bin/bash

# Simple WebSocket test script
# Tests the AirScrollBridge WebSocket server

echo "🧪 Testing AirScrollBridge WebSocket Server..."

# Check if server is running
if ! curl -s http://localhost:17604 >/dev/null 2>&1; then
    echo "❌ Server not responding on port 17604"
    echo "   Please make sure AirScrollBridge is running"
    exit 1
fi

echo "✅ Server is responding on port 17604"

# Test WebSocket connection using Node.js (if available)
if command -v node >/dev/null 2>&1; then
    echo "🌐 Testing WebSocket connection..."
    
    cat > test_websocket.js << 'EOF'
const WebSocket = require('ws');

const ws = new WebSocket('ws://localhost:17604/');

ws.on('open', function open() {
    console.log('✅ WebSocket connection established');
});

ws.on('message', function message(data) {
    try {
        const motionData = JSON.parse(data);
        console.log('📱 Received motion data:', {
            timestamp: motionData.timestamp,
            pitch: motionData.attitude?.pitch,
            yaw: motionData.attitude?.yaw,
            roll: motionData.attitude?.roll
        });
    } catch (e) {
        console.log('📨 Received:', data.toString());
    }
});

ws.on('error', function error(err) {
    console.error('❌ WebSocket error:', err.message);
});

ws.on('close', function close() {
    console.log('🔌 WebSocket connection closed');
    process.exit(0);
});

// Close after 5 seconds
setTimeout(() => {
    ws.close();
}, 5000);
EOF

    node test_websocket.js
    rm test_websocket.js
else
    echo "⚠️  Node.js not available, skipping WebSocket test"
    echo "   You can test manually with a WebSocket client at ws://localhost:17604/"
fi

echo "🎉 WebSocket server test completed!"
