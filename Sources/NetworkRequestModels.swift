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
    
    init(url: String, method: String, headers: [String: String] = [:]) {
        self.url = url
        self.method = method
        self.headers = headers
        self.timestamp = Date()
    }
    
    var domain: String {
        guard let urlComponents = URLComponents(string: url) else { return "unknown" }
        return urlComponents.host ?? "unknown"
    }
    
    var resourceType: NetworkResourceType {
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
        case .other: return "📎"
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