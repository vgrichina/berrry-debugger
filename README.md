# BerrryDebugger

A lightweight iOS web browser with comprehensive developer tools for network monitoring and debugging.

![iOS](https://img.shields.io/badge/iOS-15.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)
![License](https://img.shields.io/badge/License-MIT-green.svg)

## Overview

BerrryDebugger is a native iOS app designed for web developers who need powerful network monitoring capabilities on mobile devices. It provides a clean, touch-friendly browser with advanced developer tools that capture comprehensive network activity including HTTP requests, WebSockets, Server-Sent Events, and WebRTC connections.

### Key Features

🌐 **Full-Featured Browser**
- WKWebView-based rendering with native iOS performance
- Standard navigation controls (back, forward, refresh, share)
- Security indicators and HTTPS support

🔍 **Comprehensive Network Monitoring**
- HTTP/HTTPS requests (fetch, XHR)
- WebSocket connections with message tracking
- Server-Sent Events (EventSource)
- WebRTC peer connections
- Static resource loading (CSS, JS, images)

📱 **Mobile-Optimized Dev Tools**
- Network tab with detailed request information
- Console tab for JavaScript logs
- Elements tab for DOM inspection
- Context copying for AI/LLM debugging assistance

⚡ **Performance Focused**
- Minimal binary size (<4MB)
- Efficient JavaScript injection for monitoring
- Memory-bounded data structures
- App Store compliant architecture

## Screenshots

*Screenshots coming soon*

## Installation

### Requirements
- iOS 15.0 or later
- iPhone 8 or newer recommended
- Xcode 15+ for building from source

### Building from Source

1. **Clone the repository:**
```bash
git clone https://github.com/yourusername/berrry-debugger.git
cd berrry-debugger
```

2. **Generate Xcode project:**
```bash
# Install XcodeGen if you haven't already
brew install xcodegen

# Generate the Xcode project
xcodegen generate
```

3. **Build and run:**
```bash
# Command line build
xcodebuild -scheme BerrryDebugger -destination 'platform=iOS Simulator,name=iPhone 15 Pro' build

# Or open in Xcode
open BerrryDebugger.xcodeproj
```

## Usage

### Basic Browsing
1. Enter a URL in the address bar or use the default test site
2. Navigate using the standard browser controls
3. Tap the developer tools button (⚙️) to open the monitoring panel

### Network Monitoring
1. Open any website in the browser
2. Tap the floating action button to open DevTools
3. Switch to the "Network" tab to see captured requests
4. Tap any request for detailed headers and response information

### Testing Network Monitoring
Use the included `test_network.html` file to verify all monitoring capabilities:
- HTTP requests (GET/POST)
- WebSocket connections
- Dynamic resource loading
- Various response types

## Architecture

BerrryDebugger uses a hybrid JavaScript injection approach for comprehensive network monitoring:

### Core Components
- **BrowserViewController**: Main UI and WebView management
- **NetworkMonitor**: JavaScript-based network interception engine
- **DevToolsViewController**: Developer tools panel with tabbed interface
- **NetworkRequestModels**: Data models for request tracking

### Network Monitoring Strategy
Instead of using proxy servers or certificate manipulation, BerrryDebugger injects JavaScript that monkey-patches native web APIs:

1. **JavaScript Injection**: Comprehensive script monitors all network APIs
2. **Message Bridge**: Uses `webkit.messageHandlers` for JS-to-Swift communication
3. **Native Processing**: Swift code processes and displays captured data
4. **Real-time Updates**: Live monitoring with bounded memory usage

This approach provides 90%+ network coverage while remaining App Store compliant and avoiding HTTPS complications.

## Technical Details

### Binary Size Optimization
- **Target**: <4MB uncompressed binary
- **Techniques**: Size-optimized compilation, dead code stripping, ARM64-only builds
- **Assets**: SF Symbols only (no custom images or fonts)
- **Dependencies**: Zero external dependencies

### Performance Characteristics
- **Memory**: Bounded arrays (500 requests, 1000 console logs)
- **CPU**: Lightweight JavaScript injection with minimal overhead
- **Storage**: UserDefaults for settings, no persistent databases

## Limitations

### Network Traffic Not Captured
- Web Worker requests (requires additional patching)
- Service Worker requests (separate execution context)
- Cross-origin iframe requests (security restrictions)

### Website Compatibility
- Sites with strict Content Security Policy may block monitoring
- Heavily modified native APIs may interfere with interception
- Race conditions possible on very fast-loading pages

## Contributing

We welcome contributions! Please see our [contributing guidelines](CONTRIBUTING.md) for details.

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

### Code Style
- Use standard Swift conventions
- Follow existing patterns for UI layout
- Maintain binary size optimization settings
- Add documentation for new features

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with ❤️ for the web development community
- Inspired by browser developer tools and mobile debugging needs
- Thanks to all contributors and testers

## Support

- 🐛 **Bug Reports**: [GitHub Issues](https://github.com/yourusername/berrry-debugger/issues)
- 💡 **Feature Requests**: [GitHub Discussions](https://github.com/yourusername/berrry-debugger/discussions)
- 📧 **Contact**: [your-email@example.com](mailto:your-email@example.com)

---

**BerrryDebugger** - *Comprehensive web debugging in your pocket*