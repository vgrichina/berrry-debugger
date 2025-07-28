# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**BerrryDebugger** is a native iOS app that provides a lightweight browser with mobile-optimized developer tools. The app prioritizes minimal binary size (<10 MB) while delivering web inspection capabilities and context copying for Large Language Models (LLMs).

## Build System & Commands

### Project Generation
This project uses **XcodeGen** to generate the Xcode project from `project.yml`:
```bash
# Generate Xcode project from project.yml
xcodegen generate

# Build the app for iOS Simulator
xcodebuild -scheme BerrryDebugger -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build

# Install and launch in simulator (after build)
xcrun simctl install booted /path/to/BerrryDebugger.app
xcrun simctl launch booted app.berrry.debugger
```

### Binary Size Optimization
The project is configured for minimal binary size in `project.yml`:
- `SWIFT_OPTIMIZATION_LEVEL: -Osize` - Size-optimized Swift compilation
- `DEAD_CODE_STRIPPING: YES` - Remove unused code
- `ARCHS: arm64` - Target only ARM64 architecture
- No external dependencies or frameworks beyond iOS built-ins

### Testing
No formal test framework is configured. Testing is done manually:
- Test on iPhone 8+ (iOS 15+) for compatibility
- Load complex websites (httpbin.org, w3.org) to verify network monitoring
- Use the provided test page at `test_network.html` for comprehensive network testing

## Architecture Overview

### Core Components

**BrowserViewController** (Main UI)
- Manages WKWebView, URL bar, navigation controls
- Coordinates between UI and network monitoring
- Implements WKNavigationDelegate and WKScriptMessageHandler
- Contains the floating action button (FAB) to open dev tools

**NetworkMonitor** (Network Interception Engine)
- Implements comprehensive network monitoring via injected JavaScript
- Monitors: fetch, XHR, WebSocket, EventSource, WebRTC, static resources
- Uses message passing between JavaScript and Swift via `webkit.messageHandlers`

**DevToolsViewController** (Developer Panel)
- Modal bottom sheet with tabs: Elements, Console, Network
- Displays captured network requests and console logs
- Provides context copying functionality

**NetworkRequestModels** (Data Models)
- `NetworkRequestModel`: Represents individual network requests
- `NetworkRequestType`: Enum for different request types (fetch, xhr, websocket, etc.)
- `NetworkResourceType`: Categorizes resources (CSS, JS, images, etc.)

### Network Monitoring Architecture

The app uses a **hybrid JavaScript injection approach**:

1. **JavaScript Injection**: Comprehensive script injected at document start
2. **API Interception**: Monkey-patches window.fetch, XMLHttpRequest, WebSocket, etc.
3. **Message Bridge**: Uses `webkit.messageHandlers.networkMonitor` for JS-to-Swift communication
4. **Navigation Capture**: WKNavigationDelegate captures main document loads

This JavaScript approach is App Store compliant, handles HTTPS seamlessly, and covers 90%+ of network traffic including WebSockets, WebRTC, and EventSource.

### Data Flow Sequence

The precise data flow from network interception to UI update:

1. **JavaScript Interception**: `NetworkMonitor`'s injected JS intercepts a network request (fetch, XHR, WebSocket, etc.)
2. **Message Posting**: JS posts structured data via `webkit.messageHandlers.networkMonitor.postMessage()`
3. **Swift Reception**: `BrowserViewController` (conforming to `WKScriptMessageHandler`) receives the message in `userContentController(_:didReceive:)`
4. **Data Processing**: `BrowserViewController` forwards the message to `NetworkMonitor.handleNetworkMessage()`
5. **Model Creation**: `NetworkMonitor` decodes the message and creates/updates a `NetworkRequestModel`
6. **Delegate Notification**: `NetworkMonitor` calls delegate method `networkMonitor(_:didCaptureRequest:)` or `networkMonitor(_:didUpdateRequest:)`
7. **State Update**: `BrowserViewController` appends/updates the model in its `networkRequests` array
8. **UI Refresh**: If `DevToolsViewController` is open, it receives updated data via `updateData()` and reloads its `UITableView`

### State Management

- **Network Requests**: Owned by `BrowserViewController` in `networkRequests: [NetworkRequestModel]` array
- **Console Logs**: Owned by `BrowserViewController` in `consoleLogs: [String]` array  
- **Active Connections**: Managed by `NetworkMonitor` in `activeConnections: [String: NetworkRequestModel]` dictionary
- **DevTools UI State**: `DevToolsViewController` receives data snapshots but doesn't own the source of truth

### Key Design Patterns

**Delegation**: NetworkMonitor → BrowserViewController communication
**Message Passing**: JavaScript → Swift via WKScriptMessageHandler
**Memory Management**: Bounded arrays prevent memory leaks (500 network requests max, 1000 console logs max)

## Development Guidelines

### Error Handling Conventions
- **JavaScript Errors**: All injected JS uses try-catch blocks and posts error messages via `console.error()`
- **Swift Message Handling**: Validate all incoming JS messages with type checking before processing
- **Network Failures**: Handle network request failures gracefully, updating request status to 0 for errors
- **UI Error Feedback**: Use print() statements for debugging; avoid throwing exceptions in delegate methods
- **Memory Bounds**: Arrays automatically cap at limits (500 requests, 1000 logs) to prevent crashes

### Threading and Concurrency Model
- **WKScriptMessageHandler Callbacks**: Arrive on main thread, safe for direct UI updates
- **NetworkMonitor Delegate Methods**: Called on main thread via `DispatchQueue.main.async`
- **UI Updates**: Always perform UI updates on main thread (already guaranteed by above patterns)
- **WebView Operations**: All WKWebView operations must be performed on main thread
- **Data Access**: NetworkRequestModel objects are thread-safe for read access but modifications should be on main thread

### Network Monitoring
- Always use `NetworkMonitor` for network interception
- Test network monitoring with varied request types using `test_network.html`
- Default test URL is `https://httpbin.org/` for active network testing

### UI Patterns
- Use UIKit exclusively (no SwiftUI for binary size)
- SF Symbols for all icons to avoid custom assets
- System colors and fonts for consistency
- Modal presentations for dev tools (covers 70% of screen)

### Memory Management
- Network requests array capped at 500 items
- Console logs array capped at 1000 items
- Use weak references for delegates to prevent retain cycles

### Security Considerations
- JavaScript injection is sandboxed within WKWebView context
- All network data captured post-TLS decryption by WebKit

## File Structure

```
Sources/
├── AppDelegate.swift                 # App entry point
├── BrowserViewController.swift       # Main browser UI and coordination
├── NetworkMonitor.swift             # Network interception engine
├── NetworkRequestModels.swift       # Data models for network requests
├── DevToolsViewController.swift     # Developer tools modal panel
├── ContextCopyController.swift      # Context extraction and copying
├── EnhancedContextViewController.swift # Advanced context UI
├── Models.swift                     # General app models
├── DOMTreeModels.swift             # DOM tree data structures
├── DOMTreeTableViewCell.swift      # DOM element display cells
├── NetworkRequestTableViewCell.swift # Network request display cells
└── Info.plist                      # App configuration
```

## App Entry Points

### URL Scheme Integration
The app supports two entry methods for external URL loading:

**Custom URL Schemes**: `berrry://` and `berrry-debugger://`
- Query parameter format: `berrry-debugger://open?url=https%3A//example.com` (URL encoded)
- Path-based format: `berrry://https://example.com`
- Handled in `AppDelegate.swift` via `application(_:open:options:)`
- URLComponents automatically handles URL decoding for query parameters

**Share Sheet Integration**
- Users can share URLs from Safari/other apps directly to BerrryDebugger
- Configured via `UTImportedTypeDeclarations` in `project.yml`
- Automatically opens shared URLs in the browser

**Implementation Details**:
- `AppDelegate.handleIncomingURL()` processes both entry methods
- `BrowserViewController.loadURL()` public method loads URLs programmatically
- URL text field updates automatically when URLs are loaded externally
- Supports both app launch and running app scenarios

## Critical Implementation Notes

### Network Monitoring Debugging
If network requests aren't appearing:
1. Check console for JavaScript injection success message: "🔍 BerrryDebugger network monitoring initialized"
2. Verify `webkit.messageHandlers.networkMonitor` is registered in WKWebView configuration
3. Test with active sites like httpbin.org instead of static pages like example.com
4. Use the comprehensive test page at `test_network.html`

### Binary Size Monitoring
The app targets <4 MB uncompressed binary. Key factors:
- No external dependencies
- Size-optimized compilation flags in project.yml
- ARM64-only builds
- No custom assets (SF Symbols only)

### JavaScript Injection Script
The comprehensive network monitoring script in `NetworkMonitor.swift` is 400+ lines of JavaScript. Consider externalizing to a separate .js file for better maintainability as suggested in code reviews.

## Known Limitations

### Network Traffic Not Captured
- **Web Workers**: Requests initiated from Web Worker contexts are not intercepted (requires patching `Worker` constructor)
- **Service Workers**: Service Worker network requests run in separate context and are not monitored  
- **Cross-Origin Iframes**: Security restrictions may prevent script injection or message passing from cross-origin iframes

### Website Compatibility Issues
- **Content Security Policy (CSP)**: Sites with strict CSP may block `webkit.messageHandlers` communication, causing silent monitoring failures
- **Script Conflicts**: Websites that heavily modify native APIs (fetch, XMLHttpRequest) may interfere with interception
- **Race Conditions**: Fast-loading pages may make requests before the injection script fully initializes
- **CORS Preflight**: Complex CORS requests may not be fully captured if preflight and actual requests are handled differently

### Technical Limitations
- **Request Bodies**: POST/PUT request bodies are captured but may be truncated for large payloads
- **Binary Data**: WebSocket binary messages and file uploads may not display correctly in UI
- **Streaming Responses**: Server-sent events and streaming responses show incremental updates, not final state
- **Performance Impact**: Heavy network activity (100+ simultaneous requests) may cause UI lag

## Common Issues

**Build Failures**: Usually due to missing Xcode project - run `xcodegen generate`
**Network Monitoring Not Working**: Verify JavaScript injection and message handler setup
**Binary Size Too Large**: Check for accidental dependencies or unoptimized build settings