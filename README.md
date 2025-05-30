# AirScrollBridge

**A macOS menu bar application that transforms AirPods head motion into WebSocket data streams for scroll gestures and motion control.**

![macOS](https://img.shields.io/badge/macOS-14.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Overview

AirScrollBridge reads motion data from AirPods (3rd generation or later) using Core Motion's CMHeadphoneMotionManager and serves it via WebSocket connections. This enables developers to create innovative head-gesture-based interfaces for web applications, games, and accessibility tools.

### Features

- 🎧 **AirPods Motion Tracking**: Real-time head rotation and acceleration data
- 🌐 **WebSocket Server**: Multi-client support with JSON data streaming  
- 📱 **Menu Bar Interface**: Lightweight, always-accessible controls
- ⚙️ **Configurable Settings**: Custom port, launch at login, energy saving
- 🔒 **Privacy-First**: All data stays local, no cloud connections
- 🔋 **Energy Efficient**: Smart motion detection with automatic sleep mode
- 🧪 **Well Tested**: Comprehensive unit tests and error handling

## Requirements

- **macOS 14.0 or later** (required for CMHeadphoneMotionManager)
- **AirPods (3rd generation)** or **AirPods Pro** with motion sensors
- **Xcode 15.0+** (for building from source)

## Installation

### Option 1: Download Release (Recommended)

1. Download the latest `AirScrollBridge-x.x.x.dmg` from [Releases](releases)
2. Mount the DMG and drag AirScrollBridge to Applications
3. Launch AirScrollBridge from Applications
4. Grant motion permissions when prompted

### Option 2: Build from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/air-scroll-bridge.git
cd air-scroll-bridge

# Build the application
swift build --configuration release

# Run directly (for development)
swift run

# Or create a signed app bundle
./scripts/sign_and_notarize.sh

# Create distributable DMG
./scripts/make_dmg.sh
```

## Quick Start

1. **Launch** AirScrollBridge from Applications or menu bar
2. **Grant Permissions** when prompted for Motion & Fitness access
3. **Connect AirPods** and ensure they're selected as audio output
4. **Check Connection** - the menu bar icon fills when clients connect
5. **Test WebSocket** connection at `ws://localhost:17604/`

### Example WebSocket Client

```javascript
// Connect to AirScrollBridge
const ws = new WebSocket('ws://localhost:17604/');

ws.onmessage = (event) => {
    const motionData = JSON.parse(event.data);
    
    // Use rotation for scrolling
    const { pitch, yaw, roll } = motionData.attitude;
    
    // Scroll based on head nod (pitch)
    if (Math.abs(pitch) > 0.1) {
        window.scrollBy(0, pitch * 100);
    }
    
    // Horizontal scroll based on head turn (yaw)  
    if (Math.abs(yaw) > 0.1) {
        window.scrollBy(yaw * 100, 0);
    }
};

ws.onerror = (error) => console.error('WebSocket error:', error);
```

## Motion Data Format

AirScrollBridge streams JSON data with the following structure:

```json
{
    "timestamp": 1640995200.123,
    "attitude": {
        "pitch": -0.05,
        "yaw": 0.12,
        "roll": 0.03
    },
    "rotationRate": {
        "x": 0.001,
        "y": -0.003,
        "z": 0.002
    },
    "userAcceleration": {
        "x": 0.01,
        "y": 0.02,
        "z": -0.01
    }
}
```

### Data Fields

- **`timestamp`**: Unix timestamp with millisecond precision
- **`attitude`**: Head orientation in radians
  - `pitch`: Forward/backward tilt (nodding)
  - `yaw`: Left/right turn 
  - `roll`: Side-to-side tilt
- **`rotationRate`**: Angular velocity in radians/second
- **`userAcceleration`**: Linear acceleration excluding gravity (m/s²)

## Configuration

### Menu Bar Controls

- **Motion Data Display**: Real-time pitch/yaw/roll values
- **Connection Count**: Number of active WebSocket clients
- **Server Port**: Configurable (default: 17604)
- **Launch at Login**: Auto-start with macOS
- **Energy Saving**: Reduce update frequency when idle

### Advanced Settings

Edit preferences via the menu bar popover:

- **Update Frequency**: 30-120 Hz (default: 60 Hz)
- **Motion Threshold**: Sensitivity for gesture detection  
- **Auto-Sleep**: Minutes of inactivity before sleep mode
- **WebSocket Timeout**: Client connection timeout

## Development

### Project Structure

```
air-scroll-bridge/
├── Sources/
│   ├── AppDelegate.swift          # Main app and menu bar
│   ├── MotionManager.swift        # Core Motion handling
│   ├── WebSocketServer.swift      # SwiftNIO WebSocket server
│   ├── PopoverViewController.swift # UI controls
│   ├── Preferences.swift          # Settings management
│   └── main.swift                 # Entry point
├── Tests/
│   └── AirScrollBridgeTests.swift # Unit tests
├── scripts/
│   ├── sign_and_notarize.sh       # Code signing
│   └── make_dmg.sh                # DMG creation
└── Package.swift                  # Dependencies
```

### Dependencies

- **SwiftNIO**: High-performance WebSocket server
- **NIOWebSocket**: WebSocket protocol implementation  
- **Combine**: Reactive programming for data streams

### Building & Testing

```bash
# Run unit tests
swift test

# Build for debugging
swift build

# Build optimized release
swift build --configuration release

# Run with verbose logging
swift run --configuration debug
```

### Code Signing Setup

For distribution, set these environment variables:

```bash
export DEVELOPER_ID="Developer ID Application: Your Name (TEAMID)"
export NOTARIZATION_APPLE_ID="your@apple.id"
export NOTARIZATION_PASSWORD="your-app-specific-password"
export TEAM_ID="YOUR_TEAM_ID"
```

## Troubleshooting

### Common Issues

**AirPods Not Detected**
- Ensure AirPods are connected and selected as audio output
- Check Bluetooth connection in System Preferences
- Try disconnecting and reconnecting AirPods

**Permission Denied**
- Go to System Preferences > Privacy & Security > Motion & Fitness
- Enable access for AirScrollBridge
- Restart the application after granting permissions

**WebSocket Connection Failed**
- Check if port 17604 is available (or change in preferences)
- Verify firewall settings allow local connections
- Try connecting to `ws://127.0.0.1:17604/` instead

**High CPU Usage**
- Enable Energy Saving mode in preferences
- Reduce update frequency to 30 Hz
- Close unused WebSocket connections

**Build Errors**
- Ensure Xcode 15.0+ and macOS 14.0+ SDK
- Run `swift package clean` and rebuild
- Check that all dependencies are properly resolved

### Getting Help

1. **Check Logs**: Use Console.app to view application logs
2. **Reset Preferences**: Delete `~/Library/Preferences/com.example.airscrollbridge.plist`
3. **Report Issues**: Open an issue on [GitHub](issues) with:
   - macOS version
   - AirPods model  
   - Console logs
   - Steps to reproduce

## Use Cases

### Web Development
- **Scroll Control**: Natural head gestures for web scrolling
- **3D Interfaces**: Head tracking for WebGL/Three.js applications
- **Accessibility**: Hands-free navigation for motor impairments

### Gaming
- **Head Tracking**: First-person view control in web games
- **Motion Controls**: Gesture-based gameplay mechanics
- **VR/AR**: Head tracking for web-based immersive experiences

### Productivity
- **Presentation Control**: Hands-free slide navigation
- **Music Control**: Head gestures for playback control
- **Accessibility Tools**: Alternative input methods

## Security & Privacy

- **Local Processing**: All data processing happens on your device
- **No Cloud**: No data is sent to external servers
- **Sandboxed**: Application runs with minimal system permissions
- **Open Source**: Full code transparency for security review

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Setup

1. Fork the repository
2. Create a feature branch: `git checkout -b feature/amazing-feature`
3. Make your changes and test thoroughly
4. Commit with clear messages: `git commit -m 'Add amazing feature'`
5. Push to your fork: `git push origin feature/amazing-feature`
6. Open a Pull Request

## Roadmap

- [ ] **Multiple Device Support**: Handle multiple AirPods simultaneously
- [ ] **Custom Gestures**: User-defined gesture recognition
- [ ] **Plugin System**: Extensible processing pipeline
- [ ] **Mobile App**: iOS companion for configuration
- [ ] **API Expansion**: REST API alongside WebSocket
- [ ] **Cloud Sync**: Optional cloud-based configuration backup

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- **Apple** for Core Motion and CMHeadphoneMotionManager APIs
- **SwiftNIO** team for excellent networking framework
- **Community** contributors and testers

---

**Made with ❤️ for the macOS community**

For support, feature requests, or just to say hello, find us on [GitHub](https://github.com/yourusername/air-scroll-bridge)!
