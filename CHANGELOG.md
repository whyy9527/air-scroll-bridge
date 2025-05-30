# Changelog

All notable changes to AirScrollBridge will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Multiple device support for simultaneous AirPods connections
- Custom gesture recognition and configuration
- Plugin system for extensible data processing
- REST API endpoints alongside WebSocket server
- iOS companion app for remote configuration
- Cloud configuration backup (optional)

### Changed
- Improved energy efficiency with adaptive update rates
- Enhanced error handling and recovery mechanisms
- Better WebSocket connection management

### Fixed
- Memory leaks in long-running WebSocket connections
- Race conditions in motion data processing
- UI responsiveness during heavy WebSocket traffic

## [1.0.0] - 2025-05-30

### Added
- Initial release of AirScrollBridge
- Core Motion integration with CMHeadphoneMotionManager
- SwiftNIO-based WebSocket server with multi-client support
- Menu bar application with system tray interface
- Real-time motion data streaming (attitude, rotation rate, acceleration)
- Configurable server port and launch-at-login preferences
- Energy-saving mode with automatic sleep detection
- Comprehensive unit test suite
- Code signing and notarization scripts
- DMG creation for easy distribution
- Privacy-first design with local-only data processing

### Features
- **Motion Tracking**: Real-time AirPods head motion detection
- **WebSocket Server**: JSON data streaming to multiple clients
- **Menu Bar UI**: Lightweight interface with real-time data display
- **Preferences**: Customizable port, auto-launch, and energy settings
- **Security**: Sandboxed execution with minimal permissions
- **Compatibility**: macOS 14.0+ with AirPods 3rd gen or Pro

### Technical Details
- Built with Swift 5.9+ and SwiftNIO
- Requires macOS 14.0 or later for CMHeadphoneMotionManager
- WebSocket server on configurable port (default: 17604)
- JSON motion data format with timestamp precision
- Thread-safe client connection management
- Automatic permission handling for Motion & Fitness access

### Documentation
- Comprehensive README with setup and usage instructions
- WebSocket API documentation with example code
- Troubleshooting guide for common issues
- Build and development instructions
- Code signing and distribution guide

### Build System
- Swift Package Manager configuration
- Automated code signing with Developer ID
- Notarization support for macOS Gatekeeper
- DMG creation with custom appearance
- Unit test integration with CI/CD ready setup

### Known Issues
- Requires specific AirPods models (3rd gen or Pro) with motion sensors
- Motion permission must be granted manually on first launch
- WebSocket connections may timeout if client doesn't send ping frames
- High update frequencies (>60Hz) may impact battery life on AirPods

### Breaking Changes
- N/A (initial release)

### Migration Guide
- N/A (initial release)

---

## Release Notes Format

Each release includes:
- **Added**: New features and capabilities
- **Changed**: Modifications to existing functionality  
- **Deprecated**: Features marked for removal in future versions
- **Removed**: Features removed in this version
- **Fixed**: Bug fixes and issue resolutions
- **Security**: Security-related changes and improvements

## Version Numbering

This project follows [Semantic Versioning](https://semver.org/):
- **MAJOR**: Incompatible API changes
- **MINOR**: Backwards-compatible functionality additions
- **PATCH**: Backwards-compatible bug fixes

## Support

For questions about releases or upgrade issues:
- Check the [GitHub Issues](https://github.com/yourusername/air-scroll-bridge/issues)
- Review the [README.md](README.md) troubleshooting section
- Contact the development team
