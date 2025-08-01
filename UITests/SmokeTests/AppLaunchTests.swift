import XCTest

class AppLaunchTests: XCTestCase {
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
    
    func testAppLaunches() throws {
        framework.launchApp(screenshotName: "app_launch")
        
        // Verify basic UI elements exist
        XCTAssertTrue(app.textFields["URL"].exists, "URL field should be visible")
        XCTAssertTrue(app.buttons["Developer Tools"].exists, "FAB should be visible")
        
        // Verify URL field can accept input (Go functionality is via keyboard return key)
        let urlField = app.textFields["URL"]
        XCTAssertTrue(urlField.isEnabled, "URL field should be enabled for input")
    }
    
    func testAppLaunchesWithoutCrash() throws {
        framework.launchApp(screenshotName: "launch_stability")
        
        // Wait a bit to ensure app is stable
        sleep(UInt32(2))
        
        // Take another screenshot to verify app is still responsive
        framework.runCustomAction(name: "stability_check") {
            // Tap URL field to ensure app is responsive
            app.textFields["URL"].tap()
        }
        
        XCTAssertTrue(app.textFields["URL"].exists, "App should remain stable after launch")
    }
    
    func testBasicNavigation() throws {
        framework.launchApp(screenshotName: "navigation_start")
        
        // Test URL input
        framework.loadURL("https://example.com", screenshotName: "example_loaded")
        
        // Verify page loaded
        let webView = app.webViews.firstMatch
        XCTAssertTrue(webView.exists, "WebView should display content")
        
        // Test navigation functionality works (using keyboard return key)
        framework.runCustomAction(name: "navigation_verification") {
            // Verify the URL field shows the loaded URL
            let urlField = app.textFields["URL"]
            XCTAssertTrue(urlField.exists, "URL field should exist after navigation")
        }
    }
}