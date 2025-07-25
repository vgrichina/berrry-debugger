# BerrryDebugger Specification

## 1. Overview

**BerrryDebugger** is a native iOS app designed for web developers, providing a lightweight browser with mobile-optimized developer tools and context copying for Large Language Models (LLMs). The app prioritizes a small binary size (<10 MB uncompressed) while delivering essential functionality for inspecting web pages and sharing context (DOM, CSS, network logs) with LLMs like Grok or ChatGPT for debugging or code analysis.

### Objectives
- Deliver a functional browser with developer tools under 10 MB (uncompressed .ipa).
- Enable inspection of web pages and copying of context for LLMs.
- Provide a clean, touch-friendly UI using UIKit and SF Symbols.
- Ensure compatibility with iOS 15+ and devices like iPhone 8 and newer.

### Core Features
1. **Browser**:
   - WKWebView-based web rendering.
   - Basic navigation (URL bar, back, forward, refresh).
   - Tab management (up to 5 tabs to minimize memory).
2. **Developer Tools**:
   - **Elements**: Read-only DOM inspection with element selection.
   - **Console**: View JavaScript logs.
   - **Network**: List HTTP requests (URL, status, headers).
3. **Context Copying**:
   - Copy DOM, CSS, or network data as JSON or plain text.
   - Customizable prompt template for LLM compatibility.
4. **Offline Support**:
   - Cache pages and dev tools data (limit: 10 MB).

### Non-Goals (to Minimize Binary Size)
- No direct LLM API integration (use clipboard for manual pasting).
- No SwiftUI (adds ~2-3 MB).
- No advanced dev tools (e.g., performance profiling, responsive design testing).
- No localization (English only for MVP).

## 2. Technical Architecture

### Tech Stack
- **Language**: Swift 5.9+ (no Objective-C to avoid ~450-600 KB runtime overhead).
- **UI Framework**: UIKit (smaller than SwiftUI, ~1 MB less).
- **Browser Engine**: WKWebView (built into iOS, 0 MB impact).
- **Storage**: UserDefaults for settings, FileManager for caching (no Core Data/SQLite).
- **Networking**: URLSession (built-in, no external libraries).
- **No Dependencies**: Avoid third-party libraries to keep binary size low.

### Architecture Diagram (ASCII)

```
+-------------------+
|   App Entry       |
| (AppDelegate)     |
| - Initialize WKWebView |
| - Setup UIKit UI   |
+-------------------+
          |
          v
+-------------------+       +-------------------+
| BrowserViewController |<---->| WKWebView         |
| - URL Bar         |       | - Render Webpage  |
| - Navigation Btns |       | - JS Injection    |
| - FAB (Dev Tools) |       +-------------------+
+-------------------+                 |
          |                          v
          v                    +-------------------+
+-------------------+         | WKScriptMessageHandler |
| DevToolsViewController |<---->| - Console Logs    |
| - Elements Tab    |         | - DOM Extraction  |
| - Console Tab     |         +-------------------+
| - Network Tab     |                 |
+-------------------+                 |
          |                          v
          v                    +-------------------+
+-------------------+         | UIPasteboard      |
| ContextCopyController |<---->| - Copy JSON/Text  |
| - Copy DOM/CSS    |         +-------------------+
| - Copy Network    |
| - Prompt Template |
+-------------------+
```

- **App Entry**: `AppDelegate` initializes the app and sets up `BrowserViewController`.
- **BrowserViewController**: Manages WKWebView, URL bar, navigation buttons, and FAB.
- **DevToolsViewController**: Modal panel with tabs for Elements, Console, and Network.
- **WKWebView**: Renders pages and runs injected JavaScript for DOM/console/network data.
- **WKScriptMessageHandler**: Captures console logs and DOM data via JavaScript.
- **ContextCopyController**: Handles context extraction and clipboard copying.
- **UIPasteboard**: Copies context for manual pasting into LLMs (e.g., `https://x.ai/grok`).

### Binary Size Estimate
| Component                | Size (Uncompressed) | Notes                              |
|--------------------------|---------------------|------------------------------------|
| Swift Code (UI, Logic)   | ~2 MB               | UIKit, minimal controllers        |
| WKWebView               | 0 MB                | Built into iOS                    |
| Injected JavaScript      | ~10 KB              | Minified DOM/console scripts      |
| SF Symbols               | ~50 KB              | Minimal icon set                  |
| UserDefaults/FileManager | ~100 KB             | Settings and caching logic        |
| Build Overhead           | ~1 MB               | Linker, metadata, entitlements    |
| **Total**                | **~3-4 MB**         | Before App Thinning/compression   |

- **App Thinning**: Bitcode and slicing reduce per-device size to ~2 MB.
- **Compressed .ipa**: ~1-2 MB after App Store compression.

## 3. User Interface (UI) Design

### UI Principles
- **Minimalism**: Use UIKit for lightweight, native components.
- **Touch-Friendly**: Tap targets ≥44x44pt (per Apple HIG).
- **Icons**: SF Symbols (e.g., `arrow.left`, `arrow.right`, `gear`) to avoid custom assets.
- **Accessibility**: Support VoiceOver with `accessibilityLabel` and high-contrast colors.

### Main Screen (Browser)

**ASCII Diagram**:

```
+------------------------------------+
| [ https://example.com    ] [ Go ]  |
|------------------------------------|
| |<-| |->| | R |                   |
|------------------------------------|
|                                    |
|       [Web Content (WKWebView)]    |
|                                    |
|                                    |
|                                    |
|                [ + ] (FAB)         |
+------------------------------------+
```

- **Components**:
  - **URL Bar**: `UITextField` for URLs, with “Go” button (`UIButton`).
  - **Navigation Buttons**: Back (`arrow.left`), Forward (`arrow.right`), Refresh (`arrow.clockwise`) as `UIButton` with SF Symbols.
  - **Web Content**: `WKWebView` fills remaining space.
  - **FAB**: Floating `UIButton` with `plus.circle` to open dev tools.
- **Layout**:
  - Top bar: 44pt height (HIG-compliant).
  - FAB: Bottom-right, 50x50pt, 10pt padding from edges.
  - Colors: System background (`UIColor.systemBackground`), blue accents (`UIColor.systemBlue`).

### Dev Tools Panel

**ASCII Diagram**:

```
+------------------------------------+
| [Elements] [Console] [Network]     |
|------------------------------------|
| [Copy for LLM]                     |
|------------------------------------|
| <div class="example">Hello</div>   |
| <p>World</p>                       |
| ...                                |
|------------------------------------|
| [Close]                            |
+------------------------------------+
```

- **Components**:
  - **Tabs**: `UITabBar` with three items: Elements, Console, Network.
  - **Content Area**:
    - **Elements**: `UITextView` (read-only) for DOM, with tap-to-select (`UIGestureRecognizer`).
    - **Console**: `UITableView` for logs (cells with log text).
    - **Network**: `UITableView` for requests (cells with URL, status, headers).
  - **Copy Button**: `UIButton` labeled “Copy for LLM” to trigger context copying.
  - **Close Button**: `UIButton` with `xmark.circle` to dismiss panel.
- **Layout**:
  - Modal panel: Covers bottom 70% of screen, slide-up animation.
  - Tab bar: 44pt height, system gray background.
  - Content: `UITextView`/`UITableView` with system font (San Francisco, 14pt).
  - Colors: White background, black text, blue copy button.

### Context Copy Dialog

**ASCII Diagram**:

```
+------------------------------------+
| Select Context to Copy             |
|------------------------------------|
| [ ] Full DOM                       |
| [x] Selected Element               |
| [ ] CSS                            |
| [ ] Network Logs                   |
|------------------------------------|
| Format: [JSON] [Plain Text]        |
|------------------------------------|
| Prompt: Debug this: {context}      |
|------------------------------------|
| [Preview] [Copy] [Cancel]          |
+------------------------------------+
```

- **Components**:
  - **Checkboxes**: `UISwitch` for selecting context (DOM, CSS, Network).
  - **Format Toggle**: `UISegmentedControl` for JSON or Plain Text.
  - **Prompt Field**: `UITextField` for custom LLM prompt template.
  - **Buttons**: `UIButton` for Preview (show context), Copy (to clipboard), Cancel.
- **Layout**:
  - Presented via `UIAlertController` (minimal size impact).
  - Stack view for vertical alignment, 10pt padding.
  - Colors: System blue for buttons, white background.

### Workflow Example
1. Load `https://example.com` in the URL bar.
2. Tap FAB to open dev tools, select “Elements” tab, view DOM.
3. Tap `<div class="example">` to select it.
4. Tap “Copy for LLM,” check “Selected Element” and “JSON,” tap “Copy.”
5. JSON output (e.g., `{ "html": "<div class='example'>Hello</div>" }`) copied to clipboard.
6. Paste into an LLM (e.g., Grok at `https://x.ai/grok`) for debugging.

## 4. Context Copying Implementation

### Data Extraction
- **DOM**:
  - Full DOM: `evaluateJavaScript("document.documentElement.outerHTML")`.
  - Selected Element: `evaluateJavaScript("document.querySelector('selector').outerHTML")`.
- **CSS**:
  - Inject JavaScript: `getComputedStyle(document.querySelector('selector')).cssText`.
- **Network**:
  - Use `WKURLSchemeHandler` to capture requests, storing URL, method, status, headers.
- **Console**:
  - Inject JavaScript to override `console.log`:
    ```javascript
    window.webkit.messageHandlers.console.postMessage(JSON.stringify({ type: 'log', data: arguments }));
    ```
  - Capture via `WKScriptMessageHandler`.

### Output Formats
- **JSON**:
  ```json
  {
    "html": "<div class='example'>Hello</div>",
    "css": "div.example { color: red; }",
    "network": [{ "url": "https://example.com/api", "status": 200 }]
  }
  ```
- **Plain Text**:
  ```
  HTML: <div class='example'>Hello</div>
  CSS: div.example { color: red; }
  Network: GET https://example.com/api (200)
  ```

### Clipboard
- Use `UIPasteboard.general.string` to copy context.
- Limit output to 100 KB to avoid clipboard lag.

### Prompt Template
- Stored in UserDefaults as a string (e.g., “Debug this: {context}”).
- Replace `{context}` with extracted data before copying.

## 5. Binary Size Optimizations
- **No Dependencies**: Use only iOS frameworks (WebKit, UIKit, Foundation).
- **Code Stripping**:
  - Enable `DEAD_CODE_STRIPPING=YES` in Xcode.
  - Use `-Osize` for Swift compilation.
- **Assets**:
  - SF Symbols only (e.g., `arrow.left`, `plus.circle`).
  - No images, fonts, or videos.
- **JavaScript**:
  - Minify scripts using terser (e.g., DOM extraction <10 KB).
  - Inject at runtime via `WKUserScript`.
- **Build Settings**:
  - Target arm64 only (exclude armv7, simulator).
  - Enable Bitcode for App Thinning.
  - Strip debug symbols (`STRIP_STYLE=non-global`).
- **Storage**:
  - Use UserDefaults for settings (~1 KB).
  - Cache pages with FileManager, cap at 10 MB.

## 6. Security Considerations
- ** JavaScript Injection**: Sanitize scripts to avoid XSS (e.g., escape `<script>` tags).
- **WebView**: Disable `allowsLinkPreview` and `dataDetectorTypes` in WKWebView.
- **Clipboard**: Sanitize and limit output size to prevent injection attacks.
- **HTTPS Only**: Enforce `https://` URLs in WKWebView.

## 7. Implementation Details

### Sample Code (Context Copying)
```swift
import WebKit
import UIKit

class BrowserViewController: UIViewController, WKScriptMessageHandler, WKNavigationDelegate {
    let webView = WKWebView()
    let urlField = UITextField()
    let copyButton = UIButton(primaryAction: UIAction(title: "Copy", handler: { _ in /* Show dialog */ }))
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        setupUI()
    }
    
    func setupWebView() {
        let config = WKWebViewConfiguration()
        config.userContentController.add(self, name: "console")
        let script = WKUserScript(source: """
            window.webkit.messageHandlers.console.postMessage(JSON.stringify({ type: 'log', data: console.log }));
        """, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        config.userContentController.addUserScript(script)
        webView.configuration = config
        webView.navigationDelegate = self
        webView.frame = view.bounds.inset(by: UIEdgeInsets(top: 44, left: 0, bottom: 0, right: 0))
        view.addSubview(webView)
        webView.load(URLRequest(url: URL(string: "https://example.com")!))
    }
    
    func setupUI() {
        urlField.frame = CGRect(x: 10, y: 10, width: view.frame.width - 60, height: 34)
        urlField.borderStyle = .roundedRect
        view.addSubview(urlField)
        
        copyButton.frame = CGRect(x: view.frame.width - 60, y: view.frame.height - 60, width: 50, height: 50)
        copyButton.setImage(UIImage(systemName: "plus.circle"), for: .normal)
        view.addSubview(copyButton)
    }
    
    func copyContext(selector: String = "body") {
        let js = "JSON.stringify({ html: document.querySelector('\(selector)').outerHTML })"
        webView.evaluateJavaScript(js) { result, error in
            if let json = result as? String {
                UIPasteboard.general.string = json
                print("Copied: \(json.prefix(100))...")
            }
        }
    }
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "console", let log = message.body as? String {
            print("Log: \(log)")
        }
    }
}
```

- **Size Impact**: ~50 KB (Swift code, UIKit components).
- **Functionality**: Loads webpage, captures console logs, copies DOM as JSON.

### Error Handling
- Handle WKWebView errors (e.g., network failures) with `UIAlertController`.
- Log errors to console tab for debugging.

## 8. Testing Requirements
- **Devices**: iPhone 8 (iOS 15), iPhone 13 (iOS 18), iPad Air.
- **Scenarios**:
  - Load complex websites (e.g., `https://example.com`, `https://w3.org`).
  - Inspect DOM, capture console logs, list network requests.
  - Copy context and paste into Grok (`https://x.ai/grok`).
- **Performance**: Ensure <500ms latency for DOM extraction on iPhone 8.
- **Binary Size**: Verify <4 MB uncompressed via Xcode Archive.

## 9. Monetization and Distribution
- **Free App**: Available on App Store, no in-app purchases for MVP.
- **Future Premium**: Add advanced features (e.g., LLM API integration) as on-demand resources.
- **Distribution**: App Store with Bitcode and App Thinning enabled.
- **Documentation**: In-app guide for pasting context into LLMs (e.g., `https://x.ai/grok`).

## 10. Conclusion
BerrryDebugger is a lean, native iOS app with a ~3-4 MB binary size, built with Swift, UIKit, and WKWebView. It provides a minimal browser, essential developer tools (Elements, Console, Network), and context copying for LLMs, with a mobile-optimized UI depicted in ASCII diagrams. By avoiding dependencies, minifying JavaScript, and using built-in iOS frameworks, the app achieves a small footprint while enabling developers to debug web pages and leverage LLMs effectively.