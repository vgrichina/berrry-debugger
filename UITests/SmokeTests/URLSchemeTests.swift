import XCTest

class URLSchemeTests: XCTestCase {
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
    
    func testURLSchemeHandling() throws {
        framework.launchApp(screenshotName: "before_url_scheme")
        
        // Test berrry-debugger:// scheme
        framework.loadURLViaScheme("https://httpbin.org/get", screenshotName: "url_scheme_httpbin")
        
        // Verify the URL was loaded
        let webView = app.webViews.firstMatch
        XCTAssertTrue(webView.exists, "WebView should display content after URL scheme")
    }
    
    func testMultipleURLSchemes() throws {
        framework.launchApp(screenshotName: "multiple_schemes_start")
        
        // Test different URL schemes work
        framework.loadURLViaScheme("https://httpbin.org/json", screenshotName: "scheme_json")
        
        sleep(UInt32(2))
        
        framework.loadURLViaScheme("https://example.com", screenshotName: "scheme_example")
        
        // Verify final state
        let webView = app.webViews.firstMatch
        XCTAssertTrue(webView.exists, "WebView should handle multiple URL scheme loads")
    }
    
    func testURLSchemeWithSpecialCharacters() throws {
        framework.launchApp(screenshotName: "special_chars_start")
        
        // Test URL with query parameters and special characters
        let complexURL = "https://httpbin.org/get?param1=value%20with%20spaces&param2=special&chars"
        framework.loadURLViaScheme(complexURL, screenshotName: "complex_url_scheme")
        
        let webView = app.webViews.firstMatch
        XCTAssertTrue(webView.exists, "WebView should handle complex URLs via scheme")
    }
}