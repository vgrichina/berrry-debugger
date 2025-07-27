import Foundation

// MARK: - DOM Tree Models
class DOMNode {
    let tagName: String
    let attributes: [String: String]
    let textContent: String?
    var children: [DOMNode] = []
    weak var parent: DOMNode?
    var isExpanded: Bool = false
    var depth: Int = 0
    
    init(tagName: String, attributes: [String: String] = [:], textContent: String? = nil) {
        self.tagName = tagName
        self.attributes = attributes
        self.textContent = textContent
    }
    
    var displayName: String {
        var name = tagName.lowercased()
        
        if let id = attributes["id"], !id.isEmpty {
            name += "#\(id)"
        }
        
        if let className = attributes["class"], !className.isEmpty {
            let classes = className.split(separator: " ").prefix(2).joined(separator: " ")
            name += ".\(classes.replacingOccurrences(of: " ", with: "."))"
        }
        
        if let text = textContent?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty && text.count <= 30 {
            name += ": \"\(text)\""
        }
        
        return name
    }
    
    var selector: String {
        var parts: [String] = []
        var current: DOMNode? = self
        
        while let node = current {
            var part = node.tagName.lowercased()
            
            if let id = node.attributes["id"], !id.isEmpty {
                part += "#\(id)"
                parts.insert(part, at: 0)
                break // ID is unique, no need to go further
            }
            
            if let className = node.attributes["class"], !className.isEmpty {
                let firstClass = className.split(separator: " ").first!
                part += ".\(firstClass)"
            }
            
            parts.insert(part, at: 0)
            current = node.parent
        }
        
        return parts.joined(separator: " > ")
    }
    
    func addChild(_ child: DOMNode) {
        child.parent = self
        child.depth = self.depth + 1
        children.append(child)
    }
    
    func toggleExpanded() {
        isExpanded.toggle()
    }
    
    // Get flattened list for table view
    func flattenedNodes(includeCollapsed: Bool = false) -> [DOMNode] {
        var nodes: [DOMNode] = [self]
        
        if isExpanded || includeCollapsed {
            for child in children {
                nodes.append(contentsOf: child.flattenedNodes(includeCollapsed: includeCollapsed))
            }
        }
        
        return nodes
    }
}

// MARK: - DOM Parser
class DOMParser {
    static func parseHTML(_ html: String) -> DOMNode? {
        // Simple HTML parser - in a production app, you'd use a proper HTML parser
        // This is a simplified version for the demo
        
        let rootNode = DOMNode(tagName: "html")
        
        // Extract basic structure using regex patterns
        let bodyPattern = #"<body[^>]*>(.*?)</body>"#
        let headPattern = #"<head[^>]*>(.*?)</head>"#
        
        do {
            let bodyRegex = try NSRegularExpression(pattern: bodyPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
            let headRegex = try NSRegularExpression(pattern: headPattern, options: [.caseInsensitive, .dotMatchesLineSeparators])
            
            let range = NSRange(location: 0, length: html.count)
            
            // Parse head
            if let headMatch = headRegex.firstMatch(in: html, range: range) {
                let headNode = DOMNode(tagName: "head")
                rootNode.addChild(headNode)
                parseBasicElements(in: String(html[Range(headMatch.range(at: 1), in: html)!]), parent: headNode)
            }
            
            // Parse body
            if let bodyMatch = bodyRegex.firstMatch(in: html, range: range) {
                let bodyNode = DOMNode(tagName: "body")
                rootNode.addChild(bodyNode)
                parseBasicElements(in: String(html[Range(bodyMatch.range(at: 1), in: html)!]), parent: bodyNode)
            }
            
        } catch {
            print("Regex error: \(error)")
        }
        
        // Auto-expand root and first level
        rootNode.isExpanded = true
        rootNode.children.forEach { $0.isExpanded = true }
        
        return rootNode
    }
    
    private static func parseBasicElements(in content: String, parent: DOMNode) {
        // Simple element extraction - matches opening tags
        let elementPattern = #"<(\w+)([^>]*)>([^<]*)"#
        
        do {
            let regex = try NSRegularExpression(pattern: elementPattern, options: [.caseInsensitive])
            let matches = regex.matches(in: content, range: NSRange(location: 0, length: content.count))
            
            for match in matches {
                let tagName = String(content[Range(match.range(at: 1), in: content)!])
                let attributesString = String(content[Range(match.range(at: 2), in: content)!])
                let textContent = String(content[Range(match.range(at: 3), in: content)!]).trimmingCharacters(in: .whitespacesAndNewlines)
                
                let attributes = parseAttributes(attributesString)
                let node = DOMNode(
                    tagName: tagName,
                    attributes: attributes,
                    textContent: textContent.isEmpty ? nil : textContent
                )
                
                parent.addChild(node)
            }
        } catch {
            print("Element parsing error: \(error)")
        }
    }
    
    private static func parseAttributes(_ attributesString: String) -> [String: String] {
        var attributes: [String: String] = [:]
        
        let attributePattern = #"(\w+)=["']([^"']*)["']"#
        do {
            let regex = try NSRegularExpression(pattern: attributePattern, options: [])
            let matches = regex.matches(in: attributesString, range: NSRange(location: 0, length: attributesString.count))
            
            for match in matches {
                let key = String(attributesString[Range(match.range(at: 1), in: attributesString)!])
                let value = String(attributesString[Range(match.range(at: 2), in: attributesString)!])
                attributes[key] = value
            }
        } catch {
            print("Attribute parsing error: \(error)")
        }
        
        return attributes
    }
}