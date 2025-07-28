import Foundation

// Enhanced Network Request Model
class NetworkRequestModel {
    let id = UUID()
    let url: String
    let method: String
    var status: Int = 0
    let headers: [String: String]
    let timestamp: Date
    var responseHeaders: [String: String] = [:]
    var responseBody: String = ""
    var duration: TimeInterval = 0
    var size: Int = 0
    var requestType: NetworkRequestType = .fetch
    var connectionId: String?
    var eventData: [String: Any] = [:]
    
    init(url: String, method: String, headers: [String: String] = [:], type: NetworkRequestType = .fetch) {
        self.url = url
        self.method = method
        self.headers = headers
        self.requestType = type
        self.timestamp = Date()
    }
    
    var domain: String {
        guard let urlComponents = URLComponents(string: url) else { return "unknown" }
        return urlComponents.host ?? "unknown"
    }
    
    var resourceType: NetworkResourceType {
        // First check the request type
        switch requestType {
        case .websocket:
            return .websocket
        case .eventsource:
            return .eventsource
        case .webrtc:
            return .webrtc
        case .xhr:
            return .xhr
        case .fetch, .navigation, .resource:
            break // Continue to URL-based detection
        }
        
        guard let urlComponents = URLComponents(string: url),
              let path = urlComponents.path.split(separator: ".").last else {
            return .document
        }
        
        let ext = String(path).lowercased()
        switch ext {
        case "css": return .stylesheet
        case "js": return .script
        case "png", "jpg", "jpeg", "gif", "webp", "svg": return .image
        case "woff", "woff2", "ttf", "otf": return .font
        case "json": return .xhr
        case "mp4", "webm", "ogg": return .media
        default: return .document
        }
    }
    
    var statusColor: NetworkStatusColor {
        switch status {
        case 200...299: return .success
        case 300...399: return .redirect
        case 400...499: return .clientError
        case 500...599: return .serverError
        default: return .pending
        }
    }
    
    var formattedSize: String {
        if size < 1024 {
            return "\(size)B"
        } else if size < 1024 * 1024 {
            return "\(size / 1024)KB"
        } else {
            return String(format: "%.1fMB", Double(size) / (1024 * 1024))
        }
    }
    
    var formattedDuration: String {
        if duration < 1.0 {
            return "\(Int(duration * 1000))ms"
        } else {
            return String(format: "%.1fs", duration)
        }
    }
    
    var statusText: String {
        switch status {
        case 200: return "OK"
        case 201: return "Created"
        case 204: return "No Content"
        case 301: return "Moved Permanently"
        case 302: return "Found"
        case 304: return "Not Modified"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 500: return "Internal Server Error"
        case 502: return "Bad Gateway"
        case 503: return "Service Unavailable"
        default: return status > 0 ? "\(status)" : "Pending"
        }
    }
}

enum NetworkResourceType: String, CaseIterable {
    case all = "All"
    case document = "Doc"
    case stylesheet = "CSS"
    case script = "JS"
    case image = "Img"
    case font = "Font"
    case xhr = "XHR"
    case media = "Media"
    case websocket = "WS"
    case eventsource = "SSE"
    case webrtc = "RTC"
    case other = "Other"
    
    var emoji: String {
        switch self {
        case .all: return "📂"
        case .document: return "📄"
        case .stylesheet: return "🎨"
        case .script: return "⚙️"
        case .image: return "🖼️"
        case .font: return "🔤"
        case .xhr: return "🔗"
        case .media: return "🎬"
        case .websocket: return "🔌"
        case .eventsource: return "📡"
        case .webrtc: return "🎥"
        case .other: return "📎"
        }
    }
}

enum NetworkRequestType: String, CaseIterable {
    case fetch = "fetch"
    case xhr = "xhr"
    case websocket = "websocket"
    case eventsource = "eventsource"
    case webrtc = "webrtc"
    case navigation = "navigation"
    case resource = "resource"
    
    var displayName: String {
        switch self {
        case .fetch: return "Fetch"
        case .xhr: return "XHR"
        case .websocket: return "WebSocket"
        case .eventsource: return "EventSource"
        case .webrtc: return "WebRTC"
        case .navigation: return "Navigation"
        case .resource: return "Resource"
        }
    }
    
    var emoji: String {
        switch self {
        case .fetch: return "🔄"
        case .xhr: return "📡"
        case .websocket: return "🔌"
        case .eventsource: return "📻"
        case .webrtc: return "🎥"
        case .navigation: return "🧭"
        case .resource: return "📦"
        }
    }
}

enum NetworkStatusColor {
    case pending
    case success
    case redirect
    case clientError
    case serverError
    
    var systemColorName: String {
        switch self {
        case .pending: return "systemGray"
        case .success: return "systemGreen"
        case .redirect: return "systemBlue"
        case .clientError: return "systemOrange"
        case .serverError: return "systemRed"
        }
    }
}

// Network request detail view sections
enum NetworkDetailSection: String, CaseIterable {
    case headers = "Headers"
    case response = "Response"
    case timing = "Timing"
    
    var emoji: String {
        switch self {
        case .headers: return "📋"
        case .response: return "📦"
        case .timing: return "⏱️"
        }
    }
}