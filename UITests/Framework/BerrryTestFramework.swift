import XCTest

class BerrryTestFramework {
    let app: XCUIApplication
    let screenshotManager: ScreenshotManager
    
    init(app: XCUIApplication) {
        self.app = app
        self.screenshotManager = ScreenshotManager()
    }
    
    // MARK: - Core Actions with Screenshots
    
    func launchApp(screenshotName: String = "app_launch") {
        app.launch()
        waitForAppToLoad()
        screenshotManager.takeScreenshot(name: screenshotName, testCase: getCurrentTestName())
    }
    
    func loadURL(_ url: String, screenshotName: String) {
        let urlField = app.textFields["URL"]
        XCTAssertTrue(urlField.waitForExistence(timeout: 5), "URL field should exist")
        
        urlField.tap()
        urlField.clearAndEnterText(url)
        app.buttons["Go"].tap()
        
        // Wait for page load
        sleep(3)
        screenshotManager.takeScreenshot(name: screenshotName, testCase: getCurrentTestName())
    }
    
    func loadURLViaScheme(_ url: String, screenshotName: String) {
        let encodedURL = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? url
        let scheme = "berrry-debugger://open?url=\(encodedURL)"
        
        // Use springboard to open URL scheme
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        springboard.activate()
        
        // Simulate opening URL (in real test, this would come from external trigger)
        app.activate()
        
        sleep(3)
        screenshotManager.takeScreenshot(name: screenshotName, testCase: getCurrentTestName())
    }
    
    func openDevTools(screenshotName: String) {
        let fabButton = app.buttons["Developer Tools"]
        XCTAssertTrue(fabButton.waitForExistence(timeout: 5), "FAB button should exist")
        
        fabButton.tap()
        
        // Wait for dev tools to open
        sleep(1)
        screenshotManager.takeScreenshot(name: screenshotName, testCase: getCurrentTestName())
    }
    
    func tapNetworkTab(screenshotName: String) {
        let networkTab = app.buttons["Network"]
        XCTAssertTrue(networkTab.waitForExistence(timeout: 5), "Network tab should exist")
        
        networkTab.tap()
        sleep(1)
        screenshotManager.takeScreenshot(name: screenshotName, testCase: getCurrentTestName())
    }
    
    func tapElementsTab(screenshotName: String) {
        let elementsTab = app.buttons["Elements"] 
        XCTAssertTrue(elementsTab.waitForExistence(timeout: 5), "Elements tab should exist")
        
        elementsTab.tap()
        sleep(1)
        screenshotManager.takeScreenshot(name: screenshotName, testCase: getCurrentTestName())
    }
    
    func tapConsoleTab(screenshotName: String) {
        let consoleTab = app.buttons["Console"]
        XCTAssertTrue(consoleTab.waitForExistence(timeout: 5), "Console tab should exist")
        
        consoleTab.tap()
        sleep(1)
        screenshotManager.takeScreenshot(name: screenshotName, testCase: getCurrentTestName())
    }
    
    func closeDevTools(screenshotName: String) {
        // Tap outside dev tools to close or use close button if exists
        let webView = app.webViews.firstMatch
        if webView.exists {
            webView.tap()
        }
        
        sleep(1)
        screenshotManager.takeScreenshot(name: screenshotName, testCase: getCurrentTestName())
    }
    
    // MARK: - Custom Action Runner
    
    func runCustomAction(name: String, action: () -> Void) {
        action()
        screenshotManager.takeScreenshot(name: name, testCase: getCurrentTestName())
    }
    
    // MARK: - Web Test Actions
    
    func loadTestPage(type: NetworkTestType, screenshotName: String) {
        let url = type.testURL
        loadURL(url, screenshotName: screenshotName)
    }
    
    func waitForNetworkRequests(count: Int, timeout: TimeInterval = 10) {
        // Wait for network requests to appear in dev tools
        // This is a best-effort wait since we can't directly inspect the network list
        sleep(Int(timeout))
    }
    
    // MARK: - Utilities
    
    private func waitForAppToLoad() {
        let webView = app.webViews.firstMatch
        XCTAssertTrue(webView.waitForExistence(timeout: 10), "WebView should load")
    }
    
    private func getCurrentTestName() -> String {
        // Extract test name from current test context
        return Thread.current.threadDictionary["XCTestCase"] as? String ?? "unknown_test"
    }
}

// MARK: - Network Test Types

enum NetworkTestType {
    case simple
    case json
    case complex
    case websocket
    case failure
    
    var testURL: String {
        switch self {
        case .simple:
            return "https://httpbin.org/get"
        case .json:
            return "https://httpbin.org/json"
        case .complex:
            return "https://httpbin.org/html"
        case .websocket:
            return "wss://echo.websocket.org"
        case .failure:
            return "https://httpbin.org/status/404"
        }
    }
}

// MARK: - XCUIElement Extensions

extension XCUIElement {
    func clearAndEnterText(_ text: String) {
        guard let stringValue = self.value as? String else {
            XCTFail("Tried to clear and enter text into a non-string value")
            return
        }
        
        self.tap()
        
        let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: stringValue.count)
        self.typeText(deleteString)
        self.typeText(text)
    }
}