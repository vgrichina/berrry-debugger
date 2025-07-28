import XCTest

// Example of how to create custom tests using the framework
class ExampleCustomTest: XCTestCase {
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
    
    func testComplexWebsiteFlow() throws {
        framework.launchApp(screenshotName: "custom_test_start")
        
        // Load a complex page
        framework.loadTestPage(type: .complex, screenshotName: "complex_page_loaded")
        
        // Open dev tools and examine network requests
        framework.openDevTools(screenshotName: "devtools_complex_page")
        framework.tapNetworkTab(screenshotName: "network_complex_requests")
        
        // Switch to elements tab to see DOM
        framework.tapElementsTab(screenshotName: "elements_complex_dom")
        
        // Check console for any errors
        framework.tapConsoleTab(screenshotName: "console_complex_logs")
    }
    
    func testErrorHandling() throws {
        framework.launchApp(screenshotName: "error_test_start")
        
        // Load a page that returns 404
        framework.loadTestPage(type: .failure, screenshotName: "error_page_loaded")
        
        // Check how dev tools handle error scenarios
        framework.openDevTools(screenshotName: "devtools_error_state")
        framework.tapNetworkTab(screenshotName: "network_error_requests")
        framework.tapConsoleTab(screenshotName: "console_error_logs")
    }
    
    func testCustomInteractionFlow() throws {
        framework.launchApp(screenshotName: "interaction_start")
        
        framework.runCustomAction(name: "custom_url_input") {
            // Custom interaction: manually type URL character by character
            let urlField = app.textFields["URL"]
            urlField.tap()
            urlField.typeText("https://")
            sleep(UInt32(1))
            urlField.typeText("httpbin.org/get")
        }
        
        framework.runCustomAction(name: "manual_go_button") {
            app.buttons["Go"].tap()
            sleep(UInt32(3))
        }
        
        framework.openDevTools(screenshotName: "custom_devtools")
        
        framework.runCustomAction(name: "network_inspection") {
            framework.tapNetworkTab(screenshotName: "inspect_requests")
            
            // Custom validation logic
            let networkTab = app.buttons["Network"]
            XCTAssertTrue(networkTab.isSelected, "Network tab should be selected")
        }
    }
}