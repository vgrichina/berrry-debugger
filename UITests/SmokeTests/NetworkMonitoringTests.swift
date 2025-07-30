import XCTest

class NetworkMonitoringTests: XCTestCase {
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
    
    func testNetworkMonitoringBasic() throws {
        framework.launchApp(screenshotName: "network_test_start")
        
        // Load the debug test page
        framework.loadURL("http://localhost:8080/test_network_debug.html", screenshotName: "debug_page_loaded")
        
        // Open DevTools and go to Network tab
        framework.openDevTools(screenshotName: "devtools_opened")
        framework.tapNetworkTab(screenshotName: "network_tab_opened")
        
        // Verify network tab is empty initially
        let networkTable = app.tables.firstMatch
        XCTAssertTrue(networkTable.exists, "Network table should exist")
        framework.screenshotManager.takeScreenshot(name: "initial_network_state", testCase: "NetworkMonitoringTests")
        
        // Close DevTools to interact with page
        framework.closeDevTools(screenshotName: "devtools_closed")
        
        // Test 1: Simple JSON API
        let jsonTestButton = app.buttons["Test httpbin.org/json"]
        XCTAssertTrue(jsonTestButton.waitForExistence(timeout: 5), "JSON test button should exist")
        jsonTestButton.tap()
        framework.screenshotManager.takeScreenshot(name: "json_test_clicked", testCase: "NetworkMonitoringTests")
        
        // Wait for request to complete
        sleep(UInt32(3))
        
        // Check network tab
        framework.openDevTools(screenshotName: "devtools_after_json")
        framework.tapNetworkTab(screenshotName: "network_after_json")
        
        // Verify request appears in network tab
        let networkCells = networkTable.cells.count
        XCTAssertGreaterThan(networkCells, 0, "Should have at least one network request")
        framework.screenshotManager.takeScreenshot(name: "network_requests_captured", testCase: "NetworkMonitoringTests")
        
        // Close DevTools for next test
        framework.closeDevTools(screenshotName: "devtools_closed_after_json")
    }
    
    func testNetworkMonitoringLargeResponse() throws {
        framework.launchApp(screenshotName: "large_response_test_start")
        framework.loadURL("http://localhost:8080/test_network_debug.html", screenshotName: "debug_page_loaded")
        
        // Test large response
        let largeTestButton = app.buttons["Test httpbin.org/base64"]
        XCTAssertTrue(largeTestButton.waitForExistence(timeout: 5), "Large test button should exist")
        largeTestButton.tap()
        framework.screenshotManager.takeScreenshot(name: "large_test_clicked", testCase: "NetworkMonitoringTests")
        
        sleep(UInt32(5)) // Wait for large response
        
        framework.openDevTools(screenshotName: "devtools_after_large")
        framework.tapNetworkTab(screenshotName: "network_after_large")
        
        // Check if we have requests with size data
        let networkTable = app.tables.firstMatch
        if networkTable.cells.count > 0 {
            // Tap first request to see details
            networkTable.cells.firstMatch.tap()
            framework.screenshotManager.takeScreenshot(name: "request_details_expanded", testCase: "NetworkMonitoringTests")
        }
        
        framework.screenshotManager.takeScreenshot(name: "large_response_network_state", testCase: "NetworkMonitoringTests")
    }
    
    func testNetworkMonitoringPOST() throws {
        framework.launchApp(screenshotName: "post_test_start")
        framework.loadURL("http://localhost:8080/test_network_debug.html", screenshotName: "debug_page_loaded")
        
        // Test POST request
        let postTestButton = app.buttons["Test POST with data"]
        XCTAssertTrue(postTestButton.waitForExistence(timeout: 5), "POST test button should exist")
        postTestButton.tap()
        framework.screenshotManager.takeScreenshot(name: "post_test_clicked", testCase: "NetworkMonitoringTests")
        
        sleep(UInt32(3))
        
        framework.openDevTools(screenshotName: "devtools_after_post")
        framework.tapNetworkTab(screenshotName: "network_after_post")
        
        // Look for POST request in network tab
        let networkTable = app.tables.firstMatch
        let cells = networkTable.cells
        
        // Try to find a POST request (would show "POST" in the cell)
        for i in 0..<cells.count {
            let cell = cells.element(boundBy: i)
            if cell.staticTexts["POST"].exists {
                cell.tap()
                framework.screenshotManager.takeScreenshot(name: "post_request_details", testCase: "NetworkMonitoringTests")
                break
            }
        }
        
        framework.screenshotManager.takeScreenshot(name: "post_test_network_state", testCase: "NetworkMonitoringTests")
    }
    
    func testNetworkMonitoringMultiple() throws {
        framework.launchApp(screenshotName: "multiple_test_start")
        framework.loadURL("http://localhost:8080/test_network_debug.html", screenshotName: "debug_page_loaded")
        
        // Test multiple simultaneous requests
        let multipleTestButton = app.buttons["Fire 5 simultaneous requests"]
        XCTAssertTrue(multipleTestButton.waitForExistence(timeout: 5), "Multiple test button should exist")
        multipleTestButton.tap()
        framework.screenshotManager.takeScreenshot(name: "multiple_test_clicked", testCase: "NetworkMonitoringTests")
        
        sleep(UInt32(5)) // Wait for all requests to complete
        
        framework.openDevTools(screenshotName: "devtools_after_multiple")
        framework.tapNetworkTab(screenshotName: "network_after_multiple")
        
        // Verify multiple requests were captured
        let networkTable = app.tables.firstMatch
        let requestCount = networkTable.cells.count
        
        framework.screenshotManager.takeScreenshot(name: "multiple_requests_captured", testCase: "NetworkMonitoringTests")
        
        // Should have multiple requests (at least 3-5)
        XCTAssertGreaterThanOrEqual(requestCount, 3, "Should capture multiple requests")
        
        // Check each request for size/timing data
        for i in 0..<min(requestCount, 3) {
            let cell = networkTable.cells.element(boundBy: i)
            cell.tap()
            framework.screenshotManager.takeScreenshot(name: "request_\(i)_details", testCase: "NetworkMonitoringTests")
            
            // Look for timing information
            let timingExists = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Duration:'")).firstMatch.exists
            if timingExists {
                framework.screenshotManager.takeScreenshot(name: "request_\(i)_has_timing", testCase: "NetworkMonitoringTests")
            } else {
                framework.screenshotManager.takeScreenshot(name: "request_\(i)_missing_timing", testCase: "NetworkMonitoringTests")
            }
        }
    }
    
    func testNetworkMonitoringDebugging() throws {
        framework.launchApp(screenshotName: "debug_info_test_start")
        framework.loadURL("http://localhost:8080/test_network_debug.html", screenshotName: "debug_page_loaded")
        
        // Check debug information
        let debugButton = app.buttons["Check Network Monitoring"]
        XCTAssertTrue(debugButton.waitForExistence(timeout: 5), "Debug button should exist")
        debugButton.tap()
        framework.screenshotManager.takeScreenshot(name: "debug_info_clicked", testCase: "NetworkMonitoringTests")
        
        sleep(UInt32(2))
        
        // Look for debug information in the results
        let debugResults = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'webkit.messageHandlers.networkMonitor'")).firstMatch
        let hasWebkitHandlers = debugResults.exists
        
        framework.screenshotManager.takeScreenshot(name: "debug_info_displayed", testCase: "NetworkMonitoringTests")
        
        // This tells us if our JavaScript injection is working
        XCTAssertTrue(hasWebkitHandlers, "webkit.messageHandlers should be available")
        
        // Also check for BerrryDOM
        let domResults = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'window.berrryDOM'")).firstMatch
        let hasBerrryDOM = domResults.exists
        
        if hasBerrryDOM {
            framework.screenshotManager.takeScreenshot(name: "berrry_dom_available", testCase: "NetworkMonitoringTests")
        } else {
            framework.screenshotManager.takeScreenshot(name: "berrry_dom_missing", testCase: "NetworkMonitoringTests")
        }
    }
    
    func testNetworkMonitoringAccuracy() throws {
        framework.launchApp(screenshotName: "accuracy_test_start")
        framework.loadURL("http://localhost:8080/test_network_debug.html", screenshotName: "debug_page_loaded")
        
        // Run a simple test and compare results
        let jsonTestButton = app.buttons["Test httpbin.org/json"]
        jsonTestButton.tap()
        framework.screenshotManager.takeScreenshot(name: "accuracy_test_clicked", testCase: "NetworkMonitoringTests")
        
        sleep(UInt32(3))
        
        // Check what the page reports
        let pageResults = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Success!'")).firstMatch
        let hasPageResults = pageResults.exists
        framework.screenshotManager.takeScreenshot(name: "page_results_displayed", testCase: "NetworkMonitoringTests")
        
        // Check what DevTools reports
        framework.openDevTools(screenshotName: "devtools_for_accuracy")
        framework.tapNetworkTab(screenshotName: "network_for_accuracy")
        
        let networkTable = app.tables.firstMatch
        if networkTable.cells.count > 0 {
            // Tap the request
            networkTable.cells.firstMatch.tap()
            framework.screenshotManager.takeScreenshot(name: "devtools_request_details", testCase: "NetworkMonitoringTests")
            
            // Look for size and timing info
            let sizeInfo = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Size:'")).firstMatch
            let timingInfo = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Duration:'")).firstMatch
            
            if sizeInfo.exists && timingInfo.exists {
                framework.screenshotManager.takeScreenshot(name: "complete_request_info", testCase: "NetworkMonitoringTests")
            } else {
                framework.screenshotManager.takeScreenshot(name: "incomplete_request_info", testCase: "NetworkMonitoringTests")
            }
            
            // Extract actual values for comparison
            let hasSizeData = !app.staticTexts["0B"].exists
            let hasTimingData = !app.staticTexts["0ms"].exists
            
            XCTAssertTrue(hasSizeData || hasTimingData, "Should have either size or timing data")
        }
    }
    
    func testNetworkMonitoringWithRealWebsite() throws {
        framework.launchApp(screenshotName: "real_website_test_start")
        
        // Test with a real website that has multiple resources
        framework.loadURL("https://httpbin.org/html", screenshotName: "real_website_loaded")
        
        sleep(UInt32(5)) // Wait for all resources to load
        
        framework.openDevTools(screenshotName: "devtools_real_website")
        framework.tapNetworkTab(screenshotName: "network_real_website")
        
        let networkTable = app.tables.firstMatch
        let requestCount = networkTable.cells.count
        
        framework.screenshotManager.takeScreenshot(name: "real_website_requests", testCase: "NetworkMonitoringTests")
        
        // Should have captured the main HTML request at minimum
        XCTAssertGreaterThan(requestCount, 0, "Should capture requests from real website")
        
        // Check the main request
        if requestCount > 0 {
            networkTable.cells.firstMatch.tap()
            framework.screenshotManager.takeScreenshot(name: "main_request_details", testCase: "NetworkMonitoringTests")
            
            // Look for response headers and content
            let hasHeaders = app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Response Headers'")).firstMatch.exists
            if hasHeaders {
                framework.screenshotManager.takeScreenshot(name: "response_headers_present", testCase: "NetworkMonitoringTests")
            }
        }
        
        // Test each visible request for data quality
        let maxRequests = min(requestCount, 5)
        var requestsWithData = 0
        var requestsWithoutData = 0
        
        for i in 0..<maxRequests {
            let cell = networkTable.cells.element(boundBy: i)
            cell.tap()
            framework.screenshotManager.takeScreenshot(name: "request_\(i)_analysis", testCase: "NetworkMonitoringTests")
            
            // Check if this request has size/timing data
            let hasSize = !cell.staticTexts["0B"].exists
            let hasTiming = !cell.staticTexts["0ms"].exists
            
            if hasSize || hasTiming {
                requestsWithData += 1
                framework.screenshotManager.takeScreenshot(name: "request_\(i)_has_data", testCase: "NetworkMonitoringTests")
            } else {
                requestsWithoutData += 1
                framework.screenshotManager.takeScreenshot(name: "request_\(i)_missing_data", testCase: "NetworkMonitoringTests")
            }
        }
        
        framework.screenshotManager.takeScreenshot(name: "final_analysis", testCase: "NetworkMonitoringTests")
        
        // Report the ratio of working vs broken requests
        print("✅ Requests with data: \(requestsWithData)")
        print("❌ Requests without data: \(requestsWithoutData)")
        
        // At least 50% of requests should have proper data
        let successRate = Double(requestsWithData) / Double(maxRequests)
        XCTAssertGreaterThanOrEqual(successRate, 0.5, "At least 50% of requests should have proper size/timing data")
    }
}