import Foundation

struct NetworkRequest {
    let url: String
    let method: String
    var status: Int
    let headers: [String: String]
    let timestamp: Date
    
    init(url: String, method: String, status: Int, headers: [String: String]) {
        self.url = url
        self.method = method
        self.status = status
        self.headers = headers
        self.timestamp = Date()
    }
}

struct ContextData {
    let html: String?
    let css: String?
    let networkLogs: [NetworkRequestModel]
    let consoleLogs: [String]
    
    func toJSON() -> String {
        var jsonObject: [String: Any] = [:]
        
        if let html = html {
            jsonObject["html"] = html
        }
        
        if let css = css {
            jsonObject["css"] = css
        }
        
        if !networkLogs.isEmpty {
            jsonObject["network"] = networkLogs.map { request in
                [
                    "url": request.url,
                    "method": request.method,
                    "status": request.status,
                    "headers": request.headers
                ]
            }
        }
        
        if !consoleLogs.isEmpty {
            jsonObject["console"] = consoleLogs
        }
        
        guard let data = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        
        return jsonString
    }
    
    func toPlainText() -> String {
        var text = ""
        
        if let html = html {
            text += "HTML:\n\(html)\n\n"
        }
        
        if let css = css {
            text += "CSS:\n\(css)\n\n"
        }
        
        if !networkLogs.isEmpty {
            text += "Network Requests:\n"
            for request in networkLogs {
                text += "\(request.method) \(request.url) (\(request.status))\n"
            }
            text += "\n"
        }
        
        if !consoleLogs.isEmpty {
            text += "Console Logs:\n"
            for log in consoleLogs {
                text += "\(log)\n"
            }
        }
        
        return text
    }
}

enum ContextFormat {
    case json
    case plainText
}

enum ContextType {
    case fullDOM
    case selectedElement
    case css
    case networkLogs
    case consoleLogs
}