import Foundation
import UIKit

// MARK: - DOM Models

struct DOMElement {
    let tagName: String
    let id: String?
    let className: String?
    let attributes: [String: String]
    let textContent: String?
    let innerHTML: String?
    let selector: String
    let dimensions: DOMDimensions
    let styles: DOMStyles
    let depth: Int
    let hasChildren: Bool
    let childCount: Int
    var children: [DOMElement]
    
    init(from data: [String: Any]) {
        self.tagName = data["tagName"] as? String ?? ""
        self.id = data["id"] as? String
        self.className = data["className"] as? String
        self.attributes = data["attributes"] as? [String: String] ?? [:]
        self.textContent = data["textContent"] as? String
        self.innerHTML = data["innerHTML"] as? String
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
        
        // Parse children recursively
        if let childrenData = data["children"] as? [[String: Any]] {
            self.children = childrenData.map { DOMElement(from: $0) }
        } else {
            self.children = []
        }
    }
}

struct DOMDimensions {
    let width: Int
    let height: Int
    let top: Int
    let left: Int
    
    init(width: Int, height: Int, top: Int, left: Int) {
        self.width = width
        self.height = height
        self.top = top
        self.left = left
    }
    
    init(from data: [String: Any]) {
        self.width = data["width"] as? Int ?? 0
        self.height = data["height"] as? Int ?? 0
        self.top = data["top"] as? Int ?? 0
        self.left = data["left"] as? Int ?? 0
    }
}

struct DOMStyles {
    let display: String
    let position: String
    let color: String
    let backgroundColor: String
    let fontSize: String
    let fontFamily: String
    let margin: String
    let padding: String
    let border: String
    let zIndex: String
    
    init() {
        self.display = ""
        self.position = ""
        self.color = ""
        self.backgroundColor = ""
        self.fontSize = ""
        self.fontFamily = ""
        self.margin = ""
        self.padding = ""
        self.border = ""
        self.zIndex = ""
    }
    
    init(from data: [String: Any]) {
        self.display = data["display"] as? String ?? ""
        self.position = data["position"] as? String ?? ""
        self.color = data["color"] as? String ?? ""
        self.backgroundColor = data["backgroundColor"] as? String ?? ""
        self.fontSize = data["fontSize"] as? String ?? ""
        self.fontFamily = data["fontFamily"] as? String ?? ""
        self.margin = data["margin"] as? String ?? ""
        self.padding = data["padding"] as? String ?? ""
        self.border = data["border"] as? String ?? ""
        self.zIndex = data["zIndex"] as? String ?? ""
    }
}

struct StorageData {
    let localStorage: [String: String]
    let sessionStorage: [String: String]
    let cookies: [String: String]
    let url: String
    let error: String?
    
    init(from data: [String: Any]) {
        self.localStorage = data["localStorage"] as? [String: String] ?? [:]
        self.sessionStorage = data["sessionStorage"] as? [String: String] ?? [:]
        self.cookies = data["cookies"] as? [String: String] ?? [:]
        self.url = data["url"] as? String ?? ""
        self.error = data["error"] as? String
    }
}

// MARK: - DOM Inspector Class

class DOMInspector {
    
    // MARK: - Properties
    private var currentDOMTree: DOMElement?
    private var selectedElement: DOMElement?
    private var flattenedElements: [DOMElement] = []
    
    // MARK: - Public Methods
    
    func updateDOMTree(_ treeData: [String: Any]) {
        self.currentDOMTree = DOMElement(from: treeData)
        self.flattenedElements = flattenDOMTree()
    }
    
    func updateSelectedElement(_ elementData: [String: Any]) {
        self.selectedElement = DOMElement(from: elementData)
    }
    
    func getCurrentDOMTree() -> DOMElement? {
        return currentDOMTree
    }
    
    func getSelectedElement() -> DOMElement? {
        return selectedElement
    }
    
    func getFlattenedElements() -> [DOMElement] {
        return flattenedElements
    }
    
    func searchElements(query: String) -> [DOMElement] {
        let lowercaseQuery = query.lowercased()
        return flattenedElements.filter { element in
            element.tagName.lowercased().contains(lowercaseQuery) ||
            element.id?.lowercased().contains(lowercaseQuery) == true ||
            element.className?.lowercased().contains(lowercaseQuery) == true ||
            element.textContent?.lowercased().contains(lowercaseQuery) == true ||
            element.selector.lowercased().contains(lowercaseQuery)
        }
    }
    
    // MARK: - Context Generation for LLMs
    
    func generateBugReportContext(
        selectedElement: DOMElement?,
        consoleLogs: [String],
        networkRequests: [Any],
        currentURL: String
    ) -> String {
        var context = """
        # 🐛 Bug Report Context
        
        ## Page Information
        - URL: \(currentURL)
        - Timestamp: \(Date())
        
        """
        
        if let element = selectedElement {
            context += """
            ## Selected Element
            - Tag: \(element.tagName)
            - Selector: \(element.selector)
            - Dimensions: \(element.dimensions.width)×\(element.dimensions.height)
            - Position: (\(element.dimensions.left), \(element.dimensions.top))
            - Text Content: \(element.textContent ?? "None")
            
            ### Computed Styles
            - Display: \(element.styles.display)
            - Position: \(element.styles.position)
            - Color: \(element.styles.color)
            - Background: \(element.styles.backgroundColor)
            - Font: \(element.styles.fontSize) \(element.styles.fontFamily)
            
            ### Attributes
            """
            
            for (key, value) in element.attributes {
                context += "- \(key): \(value)\n"
            }
        }
        
        if !consoleLogs.isEmpty {
            context += """
            
            ## Console Logs
            """
            let recentLogs = consoleLogs.suffix(10)
            for log in recentLogs {
                context += "- \(log)\n"
            }
        }
        
        context += """
        
        ## LLM Debugging Prompt
        Please analyze this bug report context and suggest potential causes and solutions.
        Focus on the selected element's properties and any console errors.
        """
        
        return context
    }
    
    func generateLayoutAnalysisContext(selectedElement: DOMElement?) -> String {
        guard let element = selectedElement else {
            return "No element selected for layout analysis."
        }
        
        return """
        # 📐 Layout Analysis Context
        
        ## Element Information
        - Tag: \(element.tagName)
        - Selector: \(element.selector)
        - Dimensions: \(element.dimensions.width)×\(element.dimensions.height)
        - Position: (\(element.dimensions.left), \(element.dimensions.top))
        
        ## Layout Properties
        - Display: \(element.styles.display)
        - Position: \(element.styles.position)
        - Margin: \(element.styles.margin)
        - Padding: \(element.styles.padding)
        - Border: \(element.styles.border)
        - Z-Index: \(element.styles.zIndex)
        
        ## Element Hierarchy
        - Depth: \(element.depth)
        - Has Children: \(element.hasChildren)
        - Child Count: \(element.childCount)
        
        ## LLM Analysis Prompt
        Analyze this element's layout properties and suggest improvements for:
        1. Responsive design compatibility
        2. Accessibility compliance
        3. Visual hierarchy optimization
        4. Mobile touch target guidelines (minimum 44x44pt)
        """
    }
    
    func generatePerformanceContext(element: DOMElement?) -> String {
        var context = """
        # ⚡ Performance Analysis Context
        
        ## DOM Structure Analysis
        - Total Elements: \(flattenedElements.count)
        - DOM Depth: \(getMaxDepth())
        
        """
        
        if let element = element {
            context += """
            ## Selected Element Performance
            - Tag: \(element.tagName)
            - Selector Complexity: \(analyzeSelectorComplexity(element.selector))
            - Content Size: \(element.textContent?.count ?? 0) characters
            - HTML Size: \(element.innerHTML?.count ?? 0) characters
            
            """
        }
        
        let largeElements = flattenedElements.filter { 
            $0.dimensions.width > 300 || $0.dimensions.height > 300 
        }
        
        if !largeElements.isEmpty {
            context += """
            ## Large Elements (>300px)
            """
            for element in largeElements.prefix(5) {
                context += "- \(element.tagName) (\(element.dimensions.width)×\(element.dimensions.height)): \(element.selector)\n"
            }
        }
        
        context += """
        
        ## LLM Performance Prompt
        Analyze this DOM structure for performance optimization opportunities:
        1. Element count and nesting depth optimization
        2. Large element impact on rendering
        3. Selector efficiency improvements
        4. Mobile performance considerations
        """
        
        return context
    }
    
    // MARK: - Private Helper Methods
    
    private func flattenDOMTree() -> [DOMElement] {
        guard let root = currentDOMTree else { return [] }
        
        var flattened: [DOMElement] = []
        
        func traverse(_ element: DOMElement) {
            flattened.append(element)
            for child in element.children {
                traverse(child)
            }
        }
        
        traverse(root)
        return flattened
    }
    
    private func getMaxDepth() -> Int {
        return flattenedElements.map { $0.depth }.max() ?? 0
    }
    
    private func analyzeSelectorComplexity(_ selector: String) -> String {
        let parts = selector.components(separatedBy: CharacterSet(charactersIn: " >+~"))
        let classCount = selector.components(separatedBy: ".").count - 1
        let idCount = selector.components(separatedBy: "#").count - 1
        
        if idCount > 0 {
            return "Low (ID-based)"
        } else if classCount > 2 {
            return "High (Multiple classes)"
        } else if parts.count > 3 {
            return "Medium (Nested)"
        } else {
            return "Low (Simple)"
        }
    }
}

// MARK: - Export Utilities

extension DOMInspector {
    
    enum ExportFormat {
        case markdown
        case json
        case plainText
    }
    
    func exportSelectedElementContext(format: ExportFormat = .markdown) -> String {
        guard let element = selectedElement else {
            return "No element selected"
        }
        
        switch format {
        case .markdown:
            return generateMarkdownExport(for: element)
        case .json:
            return generateJSONExport(for: element)
        case .plainText:
            return generatePlainTextExport(for: element)
        }
    }
    
    private func generateMarkdownExport(for element: DOMElement) -> String {
        return """
        # Element Details
        
        **Tag:** `\(element.tagName)`  
        **Selector:** `\(element.selector)`  
        **Dimensions:** \(element.dimensions.width) × \(element.dimensions.height)  
        **Position:** (\(element.dimensions.left), \(element.dimensions.top))
        
        ## Attributes
        \(element.attributes.map { "- **\($0.key):** `\($0.value)`" }.joined(separator: "\n"))
        
        ## Computed Styles
        - **Display:** `\(element.styles.display)`
        - **Position:** `\(element.styles.position)`
        - **Color:** `\(element.styles.color)`
        - **Background:** `\(element.styles.backgroundColor)`
        - **Font:** `\(element.styles.fontSize)` `\(element.styles.fontFamily)`
        - **Margin:** `\(element.styles.margin)`
        - **Padding:** `\(element.styles.padding)`
        
        ## Content
        ```
        \(element.textContent ?? "No text content")
        ```
        """
    }
    
    private func generateJSONExport(for element: DOMElement) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        let exportData: [String: Any] = [
            "tagName": element.tagName,
            "selector": element.selector,
            "attributes": element.attributes,
            "dimensions": [
                "width": element.dimensions.width,
                "height": element.dimensions.height,
                "top": element.dimensions.top,
                "left": element.dimensions.left
            ],
            "styles": [
                "display": element.styles.display,
                "position": element.styles.position,
                "color": element.styles.color,
                "backgroundColor": element.styles.backgroundColor,
                "fontSize": element.styles.fontSize,
                "fontFamily": element.styles.fontFamily
            ],
            "textContent": element.textContent ?? NSNull()
        ]
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
            return String(data: jsonData, encoding: .utf8) ?? "Export failed"
        } catch {
            return "JSON export error: \(error)"
        }
    }
    
    private func generatePlainTextExport(for element: DOMElement) -> String {
        return """
        Element: \(element.tagName)
        Selector: \(element.selector)
        Size: \(element.dimensions.width)×\(element.dimensions.height)
        Position: (\(element.dimensions.left), \(element.dimensions.top))
        Display: \(element.styles.display)
        Position: \(element.styles.position)
        Text: \(element.textContent ?? "None")
        """
    }
}