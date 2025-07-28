import XCTest

class DevToolsTests: XCTestCase {
    var app: XCUIApplication!
    var framework: BerrryTestFramework!
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        framework = BerrryTestFramework(app: app)
    }
    
    override func tearDownWithError() throws {
        app = nil
        framework = nil
    }
    
    func testDevToolsOpen() throws {
        framework.launchApp(screenshotName: "devtools_test_start")
        
        // Load a page first
        framework.loadURL("https://httpbin.org/get", screenshotName: "before_devtools")
        
        // Open dev tools
        framework.openDevTools(screenshotName: "devtools_opened")
        
        // Verify dev tools elements exist
        XCTAssertTrue(app.buttons["Network"].exists, "Network tab should be visible")
        XCTAssertTrue(app.buttons["Elements"].exists, "Elements tab should be visible") 
        XCTAssertTrue(app.buttons["Console"].exists, "Console tab should be visible")
    }
    
    func testDevToolsTabs() throws {
        framework.launchApp(screenshotName: "tabs_test_start")
        framework.loadURL("https://httpbin.org/json", screenshotName: "json_loaded")
        framework.openDevTools(screenshotName: "devtools_for_tabs")
        
        // Test Network tab
        framework.tapNetworkTab(screenshotName: "network_tab_active")
        
        // Test Elements tab
        framework.tapElementsTab(screenshotName: "elements_tab_active")
        
        // Test Console tab
        framework.tapConsoleTab(screenshotName: "console_tab_active")
        
        // Return to Network tab
        framework.tapNetworkTab(screenshotName: "back_to_network")
    }
    
    func testDevToolsWithNetworkActivity() throws {
        framework.launchApp(screenshotName: "network_activity_start")
        
        // Load a page that makes network requests
        framework.loadURL("https://httpbin.org/html", screenshotName: "html_page_loaded")
        
        // Wait for potential network requests
        framework.waitForNetworkRequests(count: 1, timeout: 3)
        
        // Open dev tools and check network tab
        framework.openDevTools(screenshotName: "devtools_with_requests")
        framework.tapNetworkTab(screenshotName: "network_requests_visible")
    }
    
    func testDevToolsClose() throws {
        framework.launchApp(screenshotName: "close_test_start")
        framework.loadURL("https://example.com", screenshotName: "example_for_close")
        framework.openDevTools(screenshotName: "devtools_before_close")
        
        // Close dev tools
        framework.closeDevTools(screenshotName: "devtools_closed")
        
        // Verify we're back to normal browser view
        let webView = app.webViews.firstMatch
        XCTAssertTrue(webView.exists, "WebView should be visible after closing dev tools")
    }
    
    func testDevToolsWithMultiplePageLoads() throws {
        framework.launchApp(screenshotName: "multiple_loads_start")
        
        // Load multiple pages and check dev tools state
        framework.loadURL("https://httpbin.org/get", screenshotName: "first_page")
        framework.openDevTools(screenshotName: "devtools_first_page")
        framework.tapNetworkTab(screenshotName: "network_first")
        
        // Close dev tools and load another page
        framework.closeDevTools(screenshotName: "closed_between_loads")
        framework.loadURL("https://httpbin.org/json", screenshotName: "second_page")
        
        // Open dev tools again
        framework.openDevTools(screenshotName: "devtools_second_page")
        framework.tapNetworkTab(screenshotName: "network_second")
    }
}