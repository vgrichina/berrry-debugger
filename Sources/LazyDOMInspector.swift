import Foundation
import WebKit

protocol LazyDOMInspectorDelegate: AnyObject {
    func domInspector(_ inspector: LazyDOMInspector, didLoadRootElement element: LazyDOMElement)
    func domInspector(_ inspector: LazyDOMInspector, didLoadChildren children: [LazyDOMElement], for elementId: String)
    func domInspector(_ inspector: LazyDOMInspector, didFailWithError error: Error)
    func domInspector(_ inspector: LazyDOMInspector, didSelectElement element: LazyDOMElement)
}

// MARK: - Lazy DOM Element Model

struct LazyDOMElement {
    let tagName: String
    let id: String?
    let className: String?
    let attributes: [String: String]
    let textContent: String?
    let elementId: String
    let displaySelector: String?
    let dimensions: DOMDimensions
    let styles: DOMStyles
    let depth: Int
    let hasChildren: Bool
    let childCount: Int
    
    // Lazy loading state
    var children: [LazyDOMElement] = []
    var isExpanded: Bool = false
    var loadingState: LoadingState = .notLoaded
    
    enum LoadingState: Equatable {
        case notLoaded
        case loading
        case loaded
        case error(String)
    }
    
    init(from data: [String: Any]) {
        self.tagName = data["tagName"] as? String ?? ""
        self.id = data["id"] as? String
        self.className = data["className"] as? String
        self.attributes = data["attributes"] as? [String: String] ?? [:]
        self.textContent = data["textContent"] as? String
        self.elementId = data["elementId"] as? String ?? ""
        self.displaySelector = data["displaySelector"] as? String
        self.depth = data["depth"] as? Int ?? 0
        self.hasChildren = data["hasChildren"] as? Bool ?? false
        self.childCount = data["childCount"] as? Int ?? 0
        
        // Parse dimensions
        if let dimensionData = data["dimensions"] as? [String: Any] {
            self.dimensions = DOMDimensions(from: dimensionData)
        } else {
            self.dimensions = DOMDimensions(width: 0, height: 0, top: 0, left: 0)
        }
        
        // Parse styles
        if let stylesData = data["styles"] as? [String: Any] {
            self.styles = DOMStyles(from: stylesData)
        } else {
            self.styles = DOMStyles()
        }
        
        // Start with not loaded state for lazy loading
        self.loadingState = hasChildren ? .notLoaded : .loaded
    }
    
    mutating func setChildren(_ children: [LazyDOMElement]) {
        self.children = children
        self.loadingState = .loaded
    }
    
    mutating func setExpanded(_ expanded: Bool) {
        self.isExpanded = expanded
    }
    
    mutating func setLoadingState(_ state: LoadingState) {
        self.loadingState = state
    }
}

// MARK: - Lazy DOM Inspector

class LazyDOMInspector {
    
    weak var delegate: LazyDOMInspectorDelegate?
    private weak var webView: WKWebView?
    
    // State management
    private var rootElementId: String? = nil  // Single root element (usually <html>)
    private var elementMap: [String: LazyDOMElement] = [:]
    private var expandedElementIds: Set<String> = []
    private var selectedElement: LazyDOMElement?
    
    init() {
        self.webView = nil
    }
    
    init(webView: WKWebView) {
        self.webView = webView
    }
    
    func setWebView(_ webView: WKWebView) {
        self.webView = webView
        NSLog("✅ LazyDOMInspector: WebView set, ready to receive messages")
    }
    
    // MARK: - Public Methods
    
    func loadInitialDOM() {
        guard let webView = webView else {
            NSLog("❌ LazyDOMInspector: Cannot load DOM - webView not set")
            return
        }
        
        NSLog("🔍 LazyDOMInspector: Explicitly requesting root elements from JavaScript")
        
        // First test if the LazyDOM object exists
        webView.evaluateJavaScript("typeof window.LazyDOM") { result, error in
            NSLog("🔍 LazyDOMInspector: typeof window.LazyDOM = %@", String(describing: result))
            if let error = error {
                NSLog("❌ LazyDOMInspector: Error checking LazyDOM: %@", error.localizedDescription)
            }
        }
        
        // Test if initializeLazyDOM function exists
        webView.evaluateJavaScript("typeof initializeLazyDOM") { result, error in
            NSLog("🔍 LazyDOMInspector: typeof initializeLazyDOM = %@", String(describing: result))
            if let error = error {
                NSLog("❌ LazyDOMInspector: Error checking initializeLazyDOM: %@", error.localizedDescription)
            }
        }
        
        // Test basic JavaScript execution
        webView.evaluateJavaScript("document.body ? document.body.children.length : -1") { result, error in
            NSLog("🔍 LazyDOMInspector: document.body.children.length = %@", String(describing: result))
            if let error = error {
                NSLog("❌ LazyDOMInspector: Error checking body children: %@", error.localizedDescription)
            }
        }
        
        // Call the JavaScript function to initialize and send root elements
        let jsCode = "initializeLazyDOM()"
        NSLog("🔍 LazyDOMInspector: About to execute JavaScript: %@", jsCode)
        
        webView.evaluateJavaScript(jsCode) { result, error in
            if let error = error {
                NSLog("❌ LazyDOMInspector: Error calling initializeLazyDOM(): %@", error.localizedDescription)
            } else {
                NSLog("✅ LazyDOMInspector: Successfully triggered DOM initialization, result: %@", String(describing: result))
            }
        }
    }
    
    // Handle messages from LazyDOM JavaScript
    func handleMessage(_ messageBody: [String: Any]) {
        guard let messageType = messageBody["type"] as? String else {
            NSLog("❌ LazyDOM message missing type: %@", String(describing: messageBody))
            return
        }
        
        NSLog("🔍 LazyDOM message received: %@", messageType)
        
        switch messageType {
        case "rootElements":
            handleRootElementMessage(messageBody)
        case "childElements":
            handleChildElementsMessage(messageBody)
        case "elementSelected":
            handleElementSelectedMessage(messageBody)
        default:
            NSLog("❌ Unknown LazyDOM message type: %@", messageType)
        }
    }
    
    private func handleRootElementMessage(_ messageBody: [String: Any]) {
        guard let elementsData = messageBody["elements"] as? [[String: Any]] else {
            NSLog("❌ Invalid root elements data")
            return
        }
        
        NSLog("✅ LazyDOMInspector: Received %d root elements via message passing", elementsData.count)
        let elements = elementsData.map { LazyDOMElement(from: $0) }
        
        // Take the first element as the single root (should be <html>)
        guard let rootElement = elements.first else {
            NSLog("❌ No root element found")
            return
        }
        
        self.rootElementId = rootElement.elementId
        NSLog("✅ LazyDOMInspector: Set root element ID: %@", rootElement.elementId)
        
        // Store all elements in the map
        for element in elements {
            self.elementMap[element.elementId] = element
        }
        NSLog("✅ LazyDOMInspector: Updated element map with %d elements", self.elementMap.count)
        
        DispatchQueue.main.async {
            NSLog("✅ LazyDOMInspector: Calling delegate didLoadRootElement: %@", rootElement.tagName)
            self.delegate?.domInspector(self, didLoadRootElement: rootElement)
        }
    }
    
    private func handleChildElementsMessage(_ messageBody: [String: Any]) {
        guard let elementId = messageBody["elementId"] as? String,
              let childrenData = messageBody["children"] as? [[String: Any]] else {
            NSLog("❌ Invalid child elements data")
            return
        }
        
        let children = childrenData.map { LazyDOMElement(from: $0) }
        
        // Update element with children
        if var element = elementMap[elementId] {
            // Check if element was marked for expansion (should be true when children arrive)
            let shouldBeExpanded = expandedElementIds.contains(elementId)
            NSLog("🔍 handleChildElementsMessage: elementId=%@, shouldBeExpanded=%@, loadingState=%@", elementId, shouldBeExpanded ? "true" : "false", String(describing: element.loadingState))
            element.setChildren(children)
            element.setExpanded(shouldBeExpanded)  // Use the expansion intent, not current state
            element.setLoadingState(.loaded)       // Mark as loaded
            NSLog("🔍 handleChildElementsMessage: AFTER setChildren - isExpanded=%@, loadingState=%@, childrenCount=%d", element.isExpanded ? "true" : "false", String(describing: element.loadingState), element.children.count)
            elementMap[elementId] = element
            
            // No need to sync rootElements - we only use elementMap now
            
            // Add children to element map
            for child in children {
                elementMap[child.elementId] = child
            }
            
            DispatchQueue.main.async {
                self.delegate?.domInspector(self, didLoadChildren: children, for: elementId)
            }
        }
    }
    
    private func handleElementSelectedMessage(_ messageBody: [String: Any]) {
        guard let elementData = messageBody["element"] as? [String: Any] else {
            NSLog("❌ Invalid selected element data")
            return
        }
        
        let element = LazyDOMElement(from: elementData)
        self.selectedElement = element
        
        DispatchQueue.main.async {
            self.delegate?.domInspector(self, didSelectElement: element)
        }
    }
    
    func expandElement(elementId: String) {
        NSLog("🔍 expandElement called for elementId: %@", elementId)
        
        guard let webView = webView else {
            NSLog("❌ expandElement: webView is nil")
            return
        }
        
        guard var element = elementMap[elementId] else {
            NSLog("❌ expandElement: element not found for elementId: %@", elementId)
            return
        }
        
        guard element.hasChildren else {
            NSLog("❌ expandElement: element has no children (hasChildren: %@, childCount: %d)", element.hasChildren ? "YES" : "NO", element.childCount)
            return
        }
        
        NSLog("✅ expandElement: proceeding with expansion for element: %@", element.tagName)
        
        // Only expand if not already loaded or loading
        switch element.loadingState {
        case .loaded, .loading:
            return
        case .notLoaded, .error:
            break
        }
        
        // Update UI state immediately
        element.setLoadingState(.loading)
        element.setExpanded(true)
        NSLog("🔍 expandElement: MARKED as expanded - elementId=%@, isExpanded=%@, loadingState=%@", elementId, element.isExpanded ? "true" : "false", String(describing: element.loadingState))
        elementMap[elementId] = element
        expandedElementIds.insert(elementId)
        
        // Element is now stored only in elementMap - no need to check rootElements
        
        // Call LazyDOM to get children for this element, passing parent's depth
        let parentDepth = element.depth
        let script = """
        (function() {
            if (window.LazyDOM && window.LazyDOM.getChildren) {
                console.log('🔍 JavaScript: About to call LazyDOM.getChildren for elementId: \(elementId)');
                return window.LazyDOM.getChildren('\(elementId)', \(parentDepth));
            } else {
                console.log('❌ JavaScript: LazyDOM or getChildren not available');
                return null;
            }
        })();
        """
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                NSLog("❌ LazyDOMInspector: Error calling getChildren: %@", error.localizedDescription)
                var errorElement = self.elementMap[elementId]!
                errorElement.setLoadingState(.error(error.localizedDescription))
                self.elementMap[elementId] = errorElement
                
                DispatchQueue.main.async {
                    self.delegate?.domInspector(self, didFailWithError: error)
                }
                return
            }
            
            NSLog("✅ LazyDOMInspector: Successfully called getChildren, result: %@", String(describing: result))
            // Children will arrive via handleChildElementsMessage when JavaScript sends the message
        }
    }
    
    func collapseElement(elementId: String) {
        guard var element = elementMap[elementId] else { 
            NSLog("❌ collapseElement: element not found for elementId: %@", elementId)
            return 
        }
        
        NSLog("✅ collapseElement: collapsing element %@ (elementId: %@)", element.tagName, elementId)
        element.setExpanded(false)
        elementMap[elementId] = element
        expandedElementIds.remove(elementId)
        NSLog("✅ collapseElement: element collapsed, expandedElementIds count: %d", expandedElementIds.count)
        
        // Optionally remove children from memory to save space
        removeChildrenFromMemory(elementId: elementId)
        
        // Notify delegate about the collapse (reusing the existing didLoadChildren method)
        DispatchQueue.main.async {
            NSLog("✅ collapseElement: notifying delegate about collapse")
            self.delegate?.domInspector(self, didLoadChildren: [], for: elementId)
        }
    }
    
    func selectElement(elementId: String) {
        guard let webView = webView else { return }
        
        // Get detailed element info
        let script = "window.LazyDOM ? window.LazyDOM.getElementDetails('\(elementId)') : null"
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }
            
            if let elementData = result as? [String: Any] {
                let element = LazyDOMElement(from: elementData)
                self.selectedElement = element
                
                DispatchQueue.main.async {
                    self.delegate?.domInspector(self, didSelectElement: element)
                }
            }
        }
        
        // Highlight element on page - use displaySelector for highlighting
        if let element = elementMap[elementId], let displaySelector = element.displaySelector {
            webView.evaluateJavaScript("window.LazyDOM ? window.LazyDOM.highlightElement('\(displaySelector)') : false") { _, _ in }
        }
    }
    
    func searchElements(query: String, completion: @escaping ([LazyDOMElement]) -> Void) {
        guard let webView = webView, !query.isEmpty else {
            completion([])
            return
        }
        
        let escapedQuery = query.replacingOccurrences(of: "'", with: "\\'")
        let script = "window.LazyDOM ? window.LazyDOM.searchElements('\(escapedQuery)') : []"
        
        webView.evaluateJavaScript(script) { result, error in
            if let elementDataArray = result as? [[String: Any]] {
                let elements = elementDataArray.map { LazyDOMElement(from: $0) }
                DispatchQueue.main.async {
                    completion(elements)
                }
            } else {
                DispatchQueue.main.async {
                    completion([])
                }
            }
        }
    }
    
    func removeHighlights() {
        webView?.evaluateJavaScript("window.LazyDOM ? window.LazyDOM.removeHighlights() : false") { _, _ in }
    }
    
    func getPageStats(completion: @escaping ([String: Any]?) -> Void) {
        guard let webView = webView else {
            completion(nil)
            return
        }
        
        webView.evaluateJavaScript("window.LazyDOM ? window.LazyDOM.getPageStats() : null") { result, error in
            DispatchQueue.main.async {
                completion(result as? [String: Any])
            }
        }
    }
    
    // MARK: - Data Access
    
    func getFlattenedVisibleElements() -> [LazyDOMElement] {
        NSLog("🔍 LazyDOMInspector: getFlattenedVisibleElements called - rootElementId: %@", rootElementId ?? "nil")
        var flatElements: [LazyDOMElement] = []
        
        guard let rootElementId = rootElementId,
              let rootElement = elementMap[rootElementId] else {
            NSLog("❌ No root element found")
            return flatElements
        }
        
        func addVisibleElements(_ element: LazyDOMElement) {
            flatElements.append(element)
            NSLog("🔍 addVisibleElements: elementId=%@, isExpanded=%@, loadingState=%@, childrenCount=%d", element.elementId, element.isExpanded ? "true" : "false", String(describing: element.loadingState), element.children.count)
            
            if element.isExpanded {
                switch element.loadingState {
                case .loaded:
                    NSLog("🔍 addVisibleElements: RECURSING into %d children for %@", element.children.count, element.elementId)
                    // CRITICAL FIX: Get fresh children from elementMap instead of using cached element.children
                    for child in element.children {
                        // Get the current state of the child from elementMap
                        if let currentChild = elementMap[child.elementId] {
                            addVisibleElements(currentChild)
                        } else {
                            // Fallback to cached child if not in map
                            addVisibleElements(child)
                        }
                    }
                default:
                    NSLog("🔍 addVisibleElements: SKIPPING children for %@ (loadingState=%@)", element.elementId, String(describing: element.loadingState))
                    break
                }
            } else {
                NSLog("🔍 addVisibleElements: SKIPPING children for %@ (not expanded)", element.elementId)
            }
        }
        
        // CRITICAL FIX: Get fresh root element from elementMap to ensure current state
        if let currentRootElement = elementMap[rootElementId] {
            addVisibleElements(currentRootElement)
        } else {
            addVisibleElements(rootElement)
        }
        NSLog("🔍 LazyDOMInspector: getFlattenedVisibleElements returning %d elements", flatElements.count)
        return flatElements
    }
    
    func getRootElement() -> LazyDOMElement? {
        guard let rootElementId = rootElementId else { return nil }
        return elementMap[rootElementId]
    }
    
    func getSelectedElement() -> LazyDOMElement? {
        return selectedElement
    }
    
    func getElement(elementId: String) -> LazyDOMElement? {
        return elementMap[elementId]
    }
    
    func isElementExpanded(elementId: String) -> Bool {
        return expandedElementIds.contains(elementId)
    }
    
    // MARK: - Memory Management
    
    private func removeChildrenFromMemory(elementId: String) {
        guard let element = elementMap[elementId] else { return }
        
        // Remove all descendant elements from memory
        func removeDescendants(_ elements: [LazyDOMElement]) {
            for child in elements {
                elementMap.removeValue(forKey: child.elementId)
                expandedElementIds.remove(child.elementId)
                removeDescendants(child.children)
            }
        }
        
        removeDescendants(element.children)
        
        // Reset element state
        var updatedElement = element
        updatedElement.setChildren([])
        updatedElement.setLoadingState(.notLoaded)
        elementMap[elementId] = updatedElement
    }
    
    func clearAll() {
        rootElementId = nil
        elementMap.removeAll()
        expandedElementIds.removeAll()
        selectedElement = nil
        removeHighlights()
    }
}