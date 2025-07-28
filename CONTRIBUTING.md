# Contributing to BerrryDebugger

Thank you for your interest in contributing to BerrryDebugger! We welcome contributions from the community.

## Getting Started

### Prerequisites
- iOS development experience with Swift and UIKit
- Xcode 15+ installed
- Basic understanding of WebKit and JavaScript
- Familiarity with network debugging concepts

### Development Setup
1. Fork the repository on GitHub
2. Clone your fork locally:
   ```bash
   git clone git@github.com:yourusername/berrry-debugger.git
   cd berrry-debugger
   ```
3. Install XcodeGen (if not already installed):
   ```bash
   brew install xcodegen
   ```
4. Generate the Xcode project:
   ```bash
   xcodegen generate
   ```
5. Open `BerrryDebugger.xcodeproj` in Xcode

## Project Structure

- **Sources/**: All Swift source files
- **project.yml**: XcodeGen configuration for project generation
- **CLAUDE.md**: Technical documentation for AI assistants
- **test_network.html**: Test page for network monitoring verification

## Development Guidelines

### Code Style
- Follow standard Swift conventions
- Use meaningful variable and function names
- Add comments for complex logic, especially in JavaScript injection code
- Maintain consistency with existing code patterns

### Architecture Principles
- Keep binary size minimal (target <4MB uncompressed)
- Use only iOS built-in frameworks (no external dependencies)
- Prefer UIKit over SwiftUI for size optimization
- Follow the established delegation and message passing patterns

### Network Monitoring
- All network interception should use the JavaScript injection approach
- Avoid any attempts to use WKURLSchemeHandler for HTTP/HTTPS
- Test network monitoring with the provided `test_network.html`
- Ensure bounded memory usage (arrays capped at 500/1000 items)

## Types of Contributions

### Bug Fixes
- Check existing issues before creating new ones
- Include steps to reproduce the bug
- Test your fix with various websites and network conditions

### New Features
- Discuss major features in GitHub Issues before implementing
- Consider binary size impact of new features
- Ensure features work across different iOS versions (15.0+)
- Update documentation and tests as needed

### Performance Improvements
- Profile changes to ensure they actually improve performance
- Consider both runtime performance and binary size impact
- Test with heavy network activity scenarios

### Documentation
- Fix typos and improve clarity
- Add examples for complex concepts
- Update technical documentation in CLAUDE.md for architectural changes

## Testing

### Manual Testing Checklist
- [ ] App builds and launches without crashes
- [ ] Basic browsing functionality works
- [ ] Network monitoring captures various request types
- [ ] DevTools panel displays correctly
- [ ] Memory usage stays bounded during extended use
- [ ] Performance is acceptable on older devices (iPhone 8)

### Test Sites
- Use `https://httpbin.org/` for HTTP testing
- Test with `test_network.html` for comprehensive coverage
- Try complex sites like news websites or web applications
- Test sites with strict CSP policies

## Submitting Changes

### Pull Request Process
1. Create a feature branch from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```
2. Make your changes with clear, focused commits
3. Test thoroughly on iOS Simulator and device if possible
4. Update documentation if needed
5. Push to your fork and create a pull request

### Pull Request Guidelines
- **Title**: Clear, descriptive title explaining what the PR does
- **Description**: Explain why the change is needed and how it works
- **Testing**: Describe how you tested the changes
- **Binary Size**: Note any impact on app binary size
- **Breaking Changes**: Clearly mark any breaking changes

### Commit Message Format
Use clear, descriptive commit messages:
```
Add support for WebRTC connection monitoring

- Extend JavaScript injection to capture RTCPeerConnection events
- Add WebRTC-specific request type and UI display
- Update NetworkMonitor to handle connection state changes
- Test with WebRTC sample sites

Fixes #123
```

## Debugging

### Network Monitoring Issues
- Check browser console for JavaScript injection success message
- Verify `webkit.messageHandlers.networkMonitor` is registered
- Test with active sites like httpbin.org rather than static pages
- Use Safari Web Inspector to debug injected JavaScript

### Build Issues
- Ensure XcodeGen project is up to date: `xcodegen generate`
- Clean Xcode build folder if needed
- Check that all source files are properly included

## Security Considerations

- Never commit API keys, tokens, or other secrets
- Be cautious with JavaScript injection code - ensure it's secure
- Consider CSP and XSS implications of any web-related changes
- Test that changes don't introduce privacy or security vulnerabilities

## Questions?

- **General Questions**: Open a GitHub Discussion
- **Bug Reports**: Create a GitHub Issue with reproduction steps
- **Feature Ideas**: Start with a GitHub Discussion to gauge interest

Thank you for contributing to BerrryDebugger! 🎉