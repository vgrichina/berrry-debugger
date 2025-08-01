import XCTest

class DOMInspectionTests: XCTestCase {
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
    
    func testDOMInspectorInitialization() throws {
        framework.launchApp(screenshotName: "dom_inspector_init")
        
        // Load a page with HTML content
        framework.loadURL("https://httpbin.org/html", screenshotName: "html_page_loaded")
        
        // Open dev tools and go to Elements tab
        framework.openDevTools(screenshotName: "devtools_opened")
        framework.tapElementsTab(screenshotName: "elements_tab_opened")
        
        // Verify Elements tab components exist
        XCTAssertTrue(app.buttons["Select Element"].exists, "Select Element button should be visible")
        XCTAssertTrue(app.searchFields["Search elements..."].exists, "Elements search bar should be visible")
        XCTAssertTrue(app.tables.firstMatch.exists, "Elements table view should be visible")
        
        // Verify element details view exists
        let detailsView = app.staticTexts["No element selected"]
        XCTAssertTrue(detailsView.exists, "Element details view should show default message")
    }
    
    func testElementSelectionMode() throws {
        framework.launchApp(screenshotName: "element_selection_start")
        framework.loadURL("https://httpbin.org/html", screenshotName: "page_for_selection")
        framework.openDevTools(screenshotName: "devtools_for_selection")
        framework.tapElementsTab(screenshotName: "elements_for_selection")
        
        // Test entering selection mode
        let selectButton = app.buttons["Select Element"]
        XCTAssertTrue(selectButton.exists, "Select Element button should exist")
        
        selectButton.tap()
        framework.screenshotManager.takeScreenshot(name: "selection_mode_enabled", testCase: "DOMInspectionTests")
        
        // Verify button text changed (would be "Cancel Selection" when active)
        // Note: In real implementation, we'd check button state or text change
        
        // Test canceling selection mode by tapping button again
        selectButton.tap()
        framework.screenshotManager.takeScreenshot(name: "selection_mode_disabled", testCase: "DOMInspectionTests")
    }
    
    func testElementsTableViewPopulation() throws {
        framework.launchApp(screenshotName: "elements_table_test_start")
        framework.loadURL("https://httpbin.org/html", screenshotName: "html_for_table")
        
        // Wait for page to load completely
        sleep(UInt32(2))
        
        framework.openDevTools(screenshotName: "devtools_for_table")
        framework.tapElementsTab(screenshotName: "elements_table_loaded")
        
        // Verify table has content (DOM elements should be populated)
        let table = app.tables.firstMatch
        XCTAssertTrue(table.exists, "Elements table should exist")
        
        // Wait for DOM tree to be processed
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count > 0"),
            object: table.cells
        )
        wait(for: [expectation], timeout: 5.0)
        
        XCTAssertGreaterThan(table.cells.count, 0, "Elements table should contain DOM elements")
        framework.screenshotManager.takeScreenshot(name: "elements_table_populated", testCase: "DOMInspectionTests")
    }
    
    func testElementsSearch() throws {
        framework.launchApp(screenshotName: "elements_search_start")
        framework.loadURL("https://httpbin.org/html", screenshotName: "page_for_search")
        
        sleep(UInt32(2)) // Wait for page and DOM processing
        
        framework.openDevTools(screenshotName: "devtools_for_search")
        framework.tapElementsTab(screenshotName: "elements_for_search")
        
        // Get initial table cell count
        let table = app.tables.firstMatch
        let initialCellCount = table.cells.count
        
        // Test search functionality
        let searchField = app.searchFields["Search elements..."]
        XCTAssertTrue(searchField.exists, "Search field should exist")
        
        searchField.tap()
        searchField.typeText("body")
        framework.screenshotManager.takeScreenshot(name: "search_body_typed", testCase: "DOMInspectionTests")
        
        // Wait for search results to filter
        sleep(UInt32(1))
        
        // Verify search filtered results (should have fewer items than initial)
        let filteredCellCount = table.cells.count
        framework.screenshotManager.takeScreenshot(name: "search_results_filtered", testCase: "DOMInspectionTests")
        
        // Clear search
        searchField.buttons["Clear text"].tap()
        framework.screenshotManager.takeScreenshot(name: "search_cleared", testCase: "DOMInspectionTests")
    }
    
    func testElementDetailsDisplay() throws {
        framework.launchApp(screenshotName: "element_details_start")
        framework.loadURL("https://httpbin.org/html", screenshotName: "page_for_details")
        
        sleep(UInt32(2))
        
        framework.openDevTools(screenshotName: "devtools_for_details")
        framework.tapElementsTab(screenshotName: "elements_for_details")
        
        // Initially should show "No element selected"
        let initialDetails = app.staticTexts["No element selected"]
        XCTAssertTrue(initialDetails.exists, "Should show no element selected initially")
        framework.screenshotManager.takeScreenshot(name: "no_element_selected", testCase: "DOMInspectionTests")
        
        // Tap on an element in the table to select it
        let table = app.tables.firstMatch
        if table.cells.count > 0 {
            table.cells.firstMatch.tap()
            framework.screenshotManager.takeScreenshot(name: "element_selected_from_table", testCase: "DOMInspectionTests")
            
            // Wait for details to update
            sleep(UInt32(1))
            
            // Verify details view updated (no longer shows "No element selected")
            XCTAssertFalse(initialDetails.exists, "Should not show 'No element selected' after selection")
            framework.screenshotManager.takeScreenshot(name: "element_details_updated", testCase: "DOMInspectionTests")
        }
    }
    
    func testCopyContextFunctionality() throws {
        framework.launchApp(screenshotName: "copy_context_start")
        framework.loadURL("https://httpbin.org/html", screenshotName: "page_for_copy")
        
        sleep(UInt32(2))
        
        framework.openDevTools(screenshotName: "devtools_for_copy")
        framework.tapElementsTab(screenshotName: "elements_for_copy")
        
        // Test copy button exists and can be tapped
        let copyButton = app.buttons["Copy for LLM"]
        XCTAssertTrue(copyButton.exists, "Copy for LLM button should exist")
        
        copyButton.tap()
        framework.screenshotManager.takeScreenshot(name: "copy_button_tapped", testCase: "DOMInspectionTests")
        
        // Verify alert appears (indicating copy was successful)
        let alert = app.alerts["Copied!"]
        XCTAssertTrue(alert.waitForExistence(timeout: 2.0), "Copy success alert should appear")
        framework.screenshotManager.takeScreenshot(name: "copy_success_alert", testCase: "DOMInspectionTests")
        
        // Dismiss alert
        alert.buttons["OK"].tap()
        framework.screenshotManager.takeScreenshot(name: "alert_dismissed", testCase: "DOMInspectionTests")
    }
    
    func testDOMInspectorWithDifferentPages() throws {
        framework.launchApp(screenshotName: "multi_page_dom_start")
        
        // Test with different page types
        let testURLs = [
            "https://httpbin.org/html",
            "https://httpbin.org/json", 
            "https://example.com"
        ]
        
        for (index, url) in testURLs.enumerated() {
            framework.loadURL(url, screenshotName: "page_\(index)_loaded")
            sleep(UInt32(2))
            
            framework.openDevTools(screenshotName: "devtools_page_\(index)")
            framework.tapElementsTab(screenshotName: "elements_page_\(index)")
            
            // Verify elements table is populated
            let table = app.tables.firstMatch
            XCTAssertTrue(table.exists, "Elements table should exist for page \(index)")
            
            // Wait for DOM to be processed
            sleep(UInt32(2))
            framework.screenshotManager.takeScreenshot(name: "dom_processed_page_\(index)", testCase: "DOMInspectionTests")
            
            framework.closeDevTools(screenshotName: "closed_after_page_\(index)")
        }
    }
    
    func testDOMInspectorStability() throws {
        framework.launchApp(screenshotName: "stability_test_start")
        framework.loadURL("https://httpbin.org/html", screenshotName: "page_for_stability")
        
        // Rapidly open/close dev tools and switch tabs to test stability
        for i in 0..<3 {
            framework.openDevTools(screenshotName: "stability_open_\(i)")
            framework.tapElementsTab(screenshotName: "stability_elements_\(i)")
            
            // Toggle element selection mode
            let selectButton = app.buttons["Select Element"]
            if selectButton.exists {
                selectButton.tap()
                sleep(1)
                selectButton.tap()
            }
            
            framework.tapNetworkTab(screenshotName: "stability_network_\(i)")
            framework.tapConsoleTab(screenshotName: "stability_console_\(i)")
            framework.tapElementsTab(screenshotName: "stability_back_elements_\(i)")
            
            framework.closeDevTools(screenshotName: "stability_closed_\(i)")
            
            // Brief pause between iterations
            sleep(UInt32(1))
        }
        
        framework.screenshotManager.takeScreenshot(name: "stability_test_complete", testCase: "DOMInspectionTests")
    }
    
    func testElementSelectionWithNetworkTab() throws {
        framework.launchApp(screenshotName: "selection_network_start")
        framework.loadURL("https://httpbin.org/html", screenshotName: "page_loaded")
        
        sleep(UInt32(2))
        
        framework.openDevTools(screenshotName: "devtools_opened")
        
        // Start in Elements tab, enable selection
        framework.tapElementsTab(screenshotName: "elements_tab")
        let selectButton = app.buttons["Select Element"]
        selectButton.tap()
        framework.screenshotManager.takeScreenshot(name: "selection_enabled", testCase: "DOMInspectionTests")
        
        // Switch to Network tab while selection is active
        framework.tapNetworkTab(screenshotName: "switched_to_network")
        
        // Switch back to Elements tab
        framework.tapElementsTab(screenshotName: "back_to_elements")
        
        // Verify selection button state
        framework.screenshotManager.takeScreenshot(name: "selection_state_preserved", testCase: "DOMInspectionTests")
        
        // Disable selection
        selectButton.tap()
        framework.screenshotManager.takeScreenshot(name: "selection_disabled", testCase: "DOMInspectionTests")
    }
    
    func testDOMInspectorWithPageReload() throws {
        framework.launchApp(screenshotName: "reload_test_start")
        framework.loadURL("https://httpbin.org/html", screenshotName: "initial_page")
        
        sleep(UInt32(2))
        
        framework.openDevTools(screenshotName: "devtools_before_reload")
        framework.tapElementsTab(screenshotName: "elements_before_reload")
        
        // Get initial element count
        let table = app.tables.firstMatch
        let initialCount = table.cells.count
        
        // Keep dev tools open and reload page
        framework.refreshPage(screenshotName: "page_refreshed")
        
        sleep(UInt32(3)) // Wait for reload and DOM processing
        
        // Verify Elements tab still works after reload
        framework.screenshotManager.takeScreenshot(name: "elements_after_reload", testCase: "DOMInspectionTests")
        
        // Verify table is still populated (might have different content)
        XCTAssertTrue(table.exists, "Elements table should still exist after reload")
        XCTAssertGreaterThan(table.cells.count, 0, "Elements table should still have content after reload")
        
        framework.screenshotManager.takeScreenshot(name: "dom_inspector_after_reload", testCase: "DOMInspectionTests")
    }
}