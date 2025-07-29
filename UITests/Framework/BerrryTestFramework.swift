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
        sleep(UInt32(3))
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
        
        sleep(UInt32(3))
        screenshotManager.takeScreenshot(name: screenshotName, testCase: getCurrentTestName())
    }
    
    func openDevTools(screenshotName: String) {
        // Dismiss keyboard by tapping on webview to ensure FAB button is visible
        let webView = app.webViews.firstMatch
        if webView.exists {
            webView.tap()
            sleep(UInt32(1)) // Wait for keyboard to dismiss
        }
        
        let fabButton = app.buttons["Developer Tools"]
        XCTAssertTrue(fabButton.waitForExistence(timeout: 5), "FAB button should exist")
        
        fabButton.tap()
        
        // Wait for dev tools to open
        sleep(UInt32(1))
        screenshotManager.takeScreenshot(name: screenshotName, testCase: getCurrentTestName())
    }
    
    func tapNetworkTab(screenshotName: String) {
        let networkTab = app.buttons["Network"]
        XCTAssertTrue(networkTab.waitForExistence(timeout: 5), "Network tab should exist")
        
        networkTab.tap()
        sleep(UInt32(1))
        screenshotManager.takeScreenshot(name: screenshotName, testCase: getCurrentTestName())
    }
    
    func tapElementsTab(screenshotName: String) {
        let elementsTab = app.buttons["Elements"] 
        XCTAssertTrue(elementsTab.waitForExistence(timeout: 5), "Elements tab should exist")
        
        elementsTab.tap()
        sleep(UInt32(1))
        screenshotManager.takeScreenshot(name: screenshotName, testCase: getCurrentTestName())
    }
    
    func tapConsoleTab(screenshotName: String) {
        let consoleTab = app.buttons["Console"]
        XCTAssertTrue(consoleTab.waitForExistence(timeout: 5), "Console tab should exist")
        
        consoleTab.tap()
        sleep(UInt32(1))
        screenshotManager.takeScreenshot(name: screenshotName, testCase: getCurrentTestName())
    }
    
    func closeDevTools(screenshotName: String) {
        // Look for close button first, fallback to tapping webview
        let closeButton = app.buttons.matching(identifier: "xmark.circle.fill").firstMatch
        if closeButton.exists {
            closeButton.tap()
        } else {
            // Tap outside dev tools to close
            let webView = app.webViews.firstMatch
            if webView.exists {
                webView.tap()
            }
        }
        
        sleep(UInt32(1))
        screenshotManager.takeScreenshot(name: screenshotName, testCase: getCurrentTestName())
    }
    
    // MARK: - DOM Inspection Actions
    
    func enableElementSelection(screenshotName: String) {
        let selectButton = app.buttons["Select Element"]
        XCTAssertTrue(selectButton.waitForExistence(timeout: 5), "Select Element button should exist")
        
        selectButton.tap()
        sleep(UInt32(1))
        screenshotManager.takeScreenshot(name: screenshotName, testCase: getCurrentTestName())
    }
    
    func disableElementSelection(screenshotName: String) {
        let selectButton = app.buttons["Cancel Selection"]
        if selectButton.exists {
            selectButton.tap()
        } else {
            // Fallback to "Select Element" button if not in selection mode
            let fallbackButton = app.buttons["Select Element"]
            if fallbackButton.exists {
                fallbackButton.tap()
            }
        }
        
        sleep(UInt32(1))
        screenshotManager.takeScreenshot(name: screenshotName, testCase: getCurrentTestName())
    }
    
    func searchElements(query: String, screenshotName: String) {
        let searchField = app.searchFields["Search elements..."]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Elements search field should exist")
        
        searchField.tap()
        searchField.typeText(query)
        
        sleep(UInt32(1)) // Wait for search results
        screenshotManager.takeScreenshot(name: screenshotName, testCase: getCurrentTestName())
    }
    
    func clearElementsSearch(screenshotName: String) {
        let searchField = app.searchFields["Search elements..."]
        if searchField.exists {
            searchField.tap()
            // Clear the search field
            let clearButton = searchField.buttons["Clear text"]
            if clearButton.exists {
                clearButton.tap()
            } else {
                // Alternative: select all and delete
                searchField.doubleTap()
                app.keyboards.keys["delete"].tap()
            }
        }
        
        sleep(UInt32(1))
        screenshotManager.takeScreenshot(name: screenshotName, testCase: getCurrentTestName())
    }
    
    func selectElementFromTable(index: Int = 0, screenshotName: String) {
        let table = app.tables.firstMatch
        XCTAssertTrue(table.waitForExistence(timeout: 5), "Elements table should exist")
        
        if table.cells.count > index {
            table.cells.element(boundBy: index).tap()
            sleep(UInt32(1))
        }
        
        screenshotManager.takeScreenshot(name: screenshotName, testCase: getCurrentTestName())
    }
    
    func copyLLMContext(screenshotName: String) {
        let copyButton = app.buttons["Copy for LLM"]
        XCTAssertTrue(copyButton.waitForExistence(timeout: 5), "Copy for LLM button should exist")
        
        copyButton.tap()
        sleep(UInt32(1)) // Wait for copy operation and potential alert
        screenshotManager.takeScreenshot(name: screenshotName, testCase: getCurrentTestName())
    }
    
    func dismissCopyAlert(screenshotName: String) {
        let alert = app.alerts["Copied!"]
        if alert.waitForExistence(timeout: 3) {
            let okButton = alert.buttons["OK"]
            if okButton.exists {
                okButton.tap()
            }
        }
        
        sleep(UInt32(1))
        screenshotManager.takeScreenshot(name: screenshotName, testCase: getCurrentTestName())
    }
    
    func refreshPage(screenshotName: String) {
        let refreshButton = app.buttons.matching(identifier: "arrow.clockwise").firstMatch
        if refreshButton.exists {
            refreshButton.tap()
        } else {
            // Alternative: reload via URL field
            let urlField = app.textFields["URL"]
            if urlField.exists {
                urlField.tap()
                app.buttons["Go"].tap()
            }
        }
        
        sleep(UInt32(3)) // Wait for page reload
        screenshotManager.takeScreenshot(name: screenshotName, testCase: getCurrentTestName())
    }
    
    func verifyElementDetailsVisible(screenshotName: String) -> Bool {
        let detailsView = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Element:'")).firstMatch
        let hasDetails = detailsView.exists
        
        screenshotManager.takeScreenshot(name: screenshotName, testCase: getCurrentTestName())
        return hasDetails
    }
    
    func verifyElementsTablePopulated(screenshotName: String) -> Int {
        let table = app.tables.firstMatch
        let cellCount = table.cells.count
        
        screenshotManager.takeScreenshot(name: screenshotName, testCase: getCurrentTestName())
        return cellCount
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
        sleep(UInt32(timeout))
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