import Foundation
import WebKit

protocol LazyDOMInspectorDelegate: AnyObject {
    func domInspector(_ inspector: LazyDOMInspector, didLoadRootElements elements: [LazyDOMElement])
    func domInspector(_ inspector: LazyDOMInspector, didLoadChildren children: [LazyDOMElement], for selector: String)
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
    let selector: String
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
        self.selector = data["selector"] as? String ?? ""
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
    private var rootElements: [LazyDOMElement] = []
    private var elementMap: [String: LazyDOMElement] = [:]
    private var expandedSelectors: Set<String> = []
    private var selectedElement: LazyDOMElement?
    
    init(webView: WKWebView) {
        self.webView = webView
    }
    
    // MARK: - Public Methods
    
    func loadInitialDOM() {
        guard let webView = webView else { return }
        
        webView.evaluateJavaScript("window.LazyDOM ? window.LazyDOM.getRootElements() : null") { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                self.delegate?.domInspector(self, didFailWithError: error)
                return
            }
            
            if let elementDataArray = result as? [[String: Any]] {
                let elements = elementDataArray.map { LazyDOMElement(from: $0) }
                self.rootElements = elements
                
                // Update element map
                for element in elements {
                    self.elementMap[element.selector] = element
                }
                
                DispatchQueue.main.async {
                    self.delegate?.domInspector(self, didLoadRootElements: elements)
                }
            } else {
                let error = NSError(domain: "LazyDOMInspector", code: 1, 
                                  userInfo: [NSLocalizedDescriptionKey: "Failed to load initial DOM"])
                self.delegate?.domInspector(self, didFailWithError: error)
            }
        }
    }
    
    func expandElement(selector: String) {
        guard let webView = webView,
              var element = elementMap[selector],
              element.hasChildren else {
            return
        }
        
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
        elementMap[selector] = element
        expandedSelectors.insert(selector)
        
        let script = "window.LazyDOM ? window.LazyDOM.getChildren('\(selector)') : []"
        
        webView.evaluateJavaScript(script) { [weak self] result, error in
            guard let self = self else { return }
            
            if let error = error {
                var errorElement = self.elementMap[selector]!
                errorElement.setLoadingState(.error(error.localizedDescription))
                self.elementMap[selector] = errorElement
                
                DispatchQueue.main.async {
                    self.delegate?.domInspector(self, didFailWithError: error)
                }
                return
            }
            
            if let childrenData = result as? [[String: Any]] {
                let children = childrenData.map { LazyDOMElement(from: $0) }
                
                // Update element with children
                var updatedElement = self.elementMap[selector]!
                updatedElement.setChildren(children)
                self.elementMap[selector] = updatedElement
                
                // Add children to element map
                for child in children {
                    self.elementMap[child.selector] = child
                }
                
                DispatchQueue.main.async {
                    self.delegate?.domInspector(self, didLoadChildren: children, for: selector)
                }
            } else {
                var errorElement = self.elementMap[selector]!
                errorElement.setLoadingState(.error("No children data received"))
                self.elementMap[selector] = errorElement
                
                let error = NSError(domain: "LazyDOMInspector", code: 2,
                                  userInfo: [NSLocalizedDescriptionKey: "Failed to load children for \(selector)"])
                DispatchQueue.main.async {
                    self.delegate?.domInspector(self, didFailWithError: error)
                }
            }
        }
    }
    
    func collapseElement(selector: String) {
        guard var element = elementMap[selector] else { return }
        
        element.setExpanded(false)
        elementMap[selector] = element
        expandedSelectors.remove(selector)
        
        // Optionally remove children from memory to save space
        removeChildrenFromMemory(selector: selector)
    }
    
    func selectElement(selector: String) {
        guard let webView = webView else { return }
        
        // Get detailed element info
        let script = "window.LazyDOM ? window.LazyDOM.getElementDetails('\(selector)') : null"
        
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
        
        // Highlight element on page
        webView.evaluateJavaScript("window.LazyDOM ? window.LazyDOM.highlightElement('\(selector)') : false") { _, _ in }
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
        var flatElements: [LazyDOMElement] = []
        
        func addVisibleElements(_ elements: [LazyDOMElement]) {
            for element in elements {
                flatElements.append(element)
                
                if element.isExpanded {
                    switch element.loadingState {
                    case .loaded:
                        addVisibleElements(element.children)
                    default:
                        break
                    }
                }
            }
        }
        
        addVisibleElements(rootElements)
        return flatElements
    }
    
    func getRootElements() -> [LazyDOMElement] {
        return rootElements
    }
    
    func getSelectedElement() -> LazyDOMElement? {
        return selectedElement
    }
    
    func getElement(selector: String) -> LazyDOMElement? {
        return elementMap[selector]
    }
    
    func isElementExpanded(selector: String) -> Bool {
        return expandedSelectors.contains(selector)
    }
    
    // MARK: - Memory Management
    
    private func removeChildrenFromMemory(selector: String) {
        guard let element = elementMap[selector] else { return }
        
        // Remove all descendant elements from memory
        func removeDescendants(_ elements: [LazyDOMElement]) {
            for child in elements {
                elementMap.removeValue(forKey: child.selector)
                expandedSelectors.remove(child.selector)
                removeDescendants(child.children)
            }
        }
        
        removeDescendants(element.children)
        
        // Reset element state
        var updatedElement = element
        updatedElement.setChildren([])
        updatedElement.setLoadingState(.notLoaded)
        elementMap[selector] = updatedElement
    }
    
    func clearAll() {
        rootElements.removeAll()
        elementMap.removeAll()
        expandedSelectors.removeAll()
        selectedElement = nil
        removeHighlights()
    }
}