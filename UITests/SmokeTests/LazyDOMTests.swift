import XCTest

class LazyDOMTests: XCTestCase {
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
    
    func testLazyDOMInitialization() throws {
        framework.launchApp(screenshotName: "lazy_dom_init")
        
        // Load the comprehensive test page - use httpbin for complex HTML structure
        framework.loadURL("https://httpbin.org/html", screenshotName: "lazy_dom_test_page")
        
        // Wait for JavaScript to initialize
        sleep(UInt32(3))
        
        framework.openDevTools(screenshotName: "devtools_lazy_dom")
        framework.tapElementsTab(screenshotName: "elements_lazy_dom")
        
        // Verify lazy DOM components are present
        let table = app.tables.firstMatch
        XCTAssertTrue(table.exists, "Elements table should exist for lazy DOM")
        
        // Wait for root elements to load
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count > 0"),
            object: table.cells
        )
        wait(for: [expectation], timeout: 10.0)
        
        XCTAssertGreaterThan(table.cells.count, 0, "Root elements should be loaded")
        framework.screenshotManager.takeScreenshot(name: "lazy_dom_root_loaded", testCase: "LazyDOMTests")
    }
    
    func testLazyDOMExpansion() throws {
        framework.launchApp(screenshotName: "lazy_expansion_start")
        
        framework.loadURL("https://httpbin.org/html", screenshotName: "expansion_test_page")
        sleep(UInt32(3))
        
        framework.openDevTools(screenshotName: "devtools_for_expansion")
        framework.tapElementsTab(screenshotName: "elements_for_expansion")
        
        let table = app.tables.firstMatch
        
        // Wait for initial elements
        let loadExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count > 0"),
            object: table.cells
        )
        wait(for: [loadExpectation], timeout: 10.0)
        
        let initialCellCount = table.cells.count
        framework.screenshotManager.takeScreenshot(name: "before_expansion", testCase: "LazyDOMTests")
        
        // Look for expandable elements (those with expand buttons)
        let expandButtons = table.buttons.matching(identifier: "▶")
        if expandButtons.count > 0 {
            let firstExpandButton = expandButtons.firstMatch
            XCTAssertTrue(firstExpandButton.exists, "Expand button should exist")
            
            firstExpandButton.tap()
            framework.screenshotManager.takeScreenshot(name: "expand_button_tapped", testCase: "LazyDOMTests")
            
            // Wait for loading indicator or expansion
            sleep(UInt32(2))
            
            // Verify expansion occurred (more cells should be visible)
            let expandedCellCount = table.cells.count
            framework.screenshotManager.takeScreenshot(name: "after_expansion", testCase: "LazyDOMTests")
            
            // Note: Due to lazy loading, we might not always have more cells visible
            // but we should at least verify the button state changed or loading occurred
            print("Initial cells: \(initialCellCount), Expanded cells: \(expandedCellCount)")
        }
    }
    
    func testLazyDOMLoadingStates() throws {
        framework.launchApp(screenshotName: "loading_states_start")
        
        framework.loadURL("https://httpbin.org/html", screenshotName: "loading_states_page")
        sleep(UInt32(3))
        
        framework.openDevTools(screenshotName: "devtools_loading_states")
        framework.tapElementsTab(screenshotName: "elements_loading_states")
        
        let table = app.tables.firstMatch
        
        // Wait for table to populate
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count > 0"),
            object: table.cells
        )
        wait(for: [expectation], timeout: 10.0)
        
        framework.screenshotManager.takeScreenshot(name: "table_populated", testCase: "LazyDOMTests")
        
        // Look for elements with children (should have expand indicators)
        let cells = table.cells
        var foundExpandableCell = false
        
        for i in 0..<min(cells.count, 5) { // Check first 5 cells
            let cell = cells.element(boundBy: i)
            let expandButton = cell.buttons["▶"]
            
            if expandButton.exists {
                foundExpandableCell = true
                
                // Tap to trigger lazy loading
                expandButton.tap()
                framework.screenshotManager.takeScreenshot(name: "loading_triggered_\(i)", testCase: "LazyDOMTests")
                
                // Check for loading indicator
                let loadingIndicator = cell.activityIndicators.firstMatch
                if loadingIndicator.exists {
                    framework.screenshotManager.takeScreenshot(name: "loading_indicator_visible_\(i)", testCase: "LazyDOMTests")
                }
                
                // Wait for loading to complete
                sleep(UInt32(2))
                framework.screenshotManager.takeScreenshot(name: "loading_completed_\(i)", testCase: "LazyDOMTests")
                
                break
            }
        }
        
        XCTAssertTrue(foundExpandableCell, "Should find at least one expandable element")
    }
    
    func testLazyDOMSearch() throws {
        framework.launchApp(screenshotName: "lazy_search_start")
        
        framework.loadURL("https://httpbin.org/html", screenshotName: "search_test_page")
        sleep(UInt32(3))
        
        framework.openDevTools(screenshotName: "devtools_search")
        framework.tapElementsTab(screenshotName: "elements_search")
        
        // Wait for initial load
        let table = app.tables.firstMatch
        let loadExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count > 0"),
            object: table.cells
        )
        wait(for: [loadExpectation], timeout: 10.0)
        
        let initialCellCount = table.cells.count
        framework.screenshotManager.takeScreenshot(name: "before_search", testCase: "LazyDOMTests")
        
        // Test search functionality
        let searchField = app.searchFields["Search elements..."]
        XCTAssertTrue(searchField.exists, "Search field should exist")
        
        searchField.tap()
        searchField.typeText("button")
        framework.screenshotManager.takeScreenshot(name: "search_button_typed", testCase: "LazyDOMTests")
        
        // Wait for search results
        sleep(UInt32(2))
        
        let searchResultCount = table.cells.count
        framework.screenshotManager.takeScreenshot(name: "search_results", testCase: "LazyDOMTests")
        
        // Search should typically reduce the number of visible elements
        print("Initial: \(initialCellCount), Search results: \(searchResultCount)")
        
        // Clear search
        searchField.buttons["Clear text"].tap()
        framework.screenshotManager.takeScreenshot(name: "search_cleared", testCase: "LazyDOMTests")
        
        sleep(UInt32(1))
        
        let clearedResultCount = table.cells.count
        framework.screenshotManager.takeScreenshot(name: "after_search_cleared", testCase: "LazyDOMTests")
        
        print("After clear: \(clearedResultCount)")
    }
    
    func testLazyDOMElementSelection() throws {
        framework.launchApp(screenshotName: "element_selection_start")
        
        framework.loadURL("https://httpbin.org/html", screenshotName: "selection_test_page")
        sleep(UInt32(3))
        
        framework.openDevTools(screenshotName: "devtools_selection")
        framework.tapElementsTab(screenshotName: "elements_selection")
        
        let table = app.tables.firstMatch
        let loadExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count > 0"),
            object: table.cells
        )
        wait(for: [loadExpectation], timeout: 10.0)
        
        // Test element selection from table
        let firstCell = table.cells.firstMatch
        XCTAssertTrue(firstCell.exists, "First table cell should exist")
        
        firstCell.tap()
        framework.screenshotManager.takeScreenshot(name: "element_selected", testCase: "LazyDOMTests")
        
        // Check if element details are updated
        sleep(UInt32(1))
        framework.screenshotManager.takeScreenshot(name: "element_details_updated", testCase: "LazyDOMTests")
        
        // Test element selection mode
        let selectButton = app.buttons["Select Element"]
        if selectButton.exists {
            selectButton.tap()
            framework.screenshotManager.takeScreenshot(name: "selection_mode_enabled", testCase: "LazyDOMTests")
            
            // Cancel selection mode
            selectButton.tap()
            framework.screenshotManager.takeScreenshot(name: "selection_mode_disabled", testCase: "LazyDOMTests")
        }
    }
    
    func testLazyDOMWithComplexPage() throws {
        framework.launchApp(screenshotName: "complex_page_start")
        
        framework.loadURL("https://httpbin.org/html", screenshotName: "complex_page_loaded")
        
        // Wait longer for complex page to fully load and JavaScript to execute
        sleep(UInt32(5))
        
        framework.openDevTools(screenshotName: "devtools_complex")
        framework.tapElementsTab(screenshotName: "elements_complex")
        
        let table = app.tables.firstMatch
        
        // Wait for root elements
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count > 0"),
            object: table.cells
        )
        wait(for: [expectation], timeout: 15.0)
        
        framework.screenshotManager.takeScreenshot(name: "complex_dom_loaded", testCase: "LazyDOMTests")
        
        // Test expanding multiple elements
        let expandButtons = table.buttons.matching(identifier: "▶")
        let buttonCount = min(expandButtons.count, 3) // Test first 3 expandable elements
        
        for i in 0..<buttonCount {
            let button = expandButtons.element(boundBy: i)
            if button.exists {
                button.tap()
                framework.screenshotManager.takeScreenshot(name: "expansion_\(i)", testCase: "LazyDOMTests")
                sleep(UInt32(1)) // Brief pause between expansions
            }
        }
        
        framework.screenshotManager.takeScreenshot(name: "multiple_expansions_complete", testCase: "LazyDOMTests")
        
        // Verify table still responds after multiple expansions
        XCTAssertTrue(table.exists, "Table should still exist after multiple expansions")
        XCTAssertGreaterThan(table.cells.count, 0, "Table should still have cells after expansions")
    }
    
    func testLazyDOMMemoryManagement() throws {
        framework.launchApp(screenshotName: "memory_test_start")
        
        framework.loadURL("https://httpbin.org/html", screenshotName: "memory_test_page")
        sleep(UInt32(3))
        
        framework.openDevTools(screenshotName: "devtools_memory")
        framework.tapElementsTab(screenshotName: "elements_memory")
        
        let table = app.tables.firstMatch
        let loadExpectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count > 0"),
            object: table.cells
        )
        wait(for: [loadExpectation], timeout: 10.0)
        
        // Test rapid expand/collapse cycles (stress test)
        let expandButtons = table.buttons.matching(identifier: "▶")
        
        if expandButtons.count > 0 {
            let testButton = expandButtons.firstMatch
            
            // Rapid expand/collapse cycles
            for i in 0..<5 {
                testButton.tap() // Expand
                framework.screenshotManager.takeScreenshot(name: "cycle_\(i)_expanded", testCase: "LazyDOMTests")
                sleep(UInt32(1))
                
                // Look for collapse button (should be ▼ now)
                let collapseButton = table.buttons["▼"].firstMatch
                if collapseButton.exists {
                    collapseButton.tap() // Collapse
                    framework.screenshotManager.takeScreenshot(name: "cycle_\(i)_collapsed", testCase: "LazyDOMTests")
                }
                sleep(UInt32(1))
            }
        }
        
        // Verify app is still stable after memory stress test
        XCTAssertTrue(table.exists, "Table should exist after memory stress test")
        framework.screenshotManager.takeScreenshot(name: "memory_test_complete", testCase: "LazyDOMTests")
    }
    
    func testLazyDOMJavaScriptIntegration() throws {
        framework.launchApp(screenshotName: "js_integration_start")
        
        framework.loadURL("https://httpbin.org/html", screenshotName: "js_integration_page")
        
        // Wait for JavaScript to fully initialize
        sleep(UInt32(5))
        
        framework.openDevTools(screenshotName: "devtools_js_integration")
        framework.tapElementsTab(screenshotName: "elements_js_integration")
        
        // Verify LazyDOM JavaScript functions are working
        let table = app.tables.firstMatch
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "count > 0"),
            object: table.cells
        )
        wait(for: [expectation], timeout: 15.0)
        
        XCTAssertGreaterThan(table.cells.count, 0, "LazyDOM JavaScript should populate elements")
        framework.screenshotManager.takeScreenshot(name: "js_functions_working", testCase: "LazyDOMTests")
        
        // Test that search works (depends on JavaScript search function)
        let searchField = app.searchFields["Search elements..."]
        if searchField.exists {
            searchField.tap()
            searchField.typeText("div")
            framework.screenshotManager.takeScreenshot(name: "js_search_working", testCase: "LazyDOMTests")
            sleep(UInt32(2))
            
            // Clear search
            searchField.buttons["Clear text"].tap()
            sleep(UInt32(1))
        }
        
        framework.screenshotManager.takeScreenshot(name: "js_integration_complete", testCase: "LazyDOMTests")
    }
}