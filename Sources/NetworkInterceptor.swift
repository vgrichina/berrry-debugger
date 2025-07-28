import Foundation
import WebKit

protocol NetworkInterceptorDelegate: AnyObject {
    func networkInterceptor(_ interceptor: NetworkInterceptor, didCaptureRequest request: NetworkRequestModel)
    func networkInterceptor(_ interceptor: NetworkInterceptor, didUpdateRequest request: NetworkRequestModel)
}

class NetworkInterceptor: NSObject, WKURLSchemeHandler {
    
    weak var delegate: NetworkInterceptorDelegate?
    private var activeTasks: [UUID: URLSessionDataTask] = [:]
    private var requestModels: [UUID: NetworkRequestModel] = [:]
    
    // MARK: - WKURLSchemeHandler
    
    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(NSError(domain: "NetworkInterceptor", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        // Create NetworkRequestModel to track this request
        let networkRequest = NetworkRequestModel(
            url: url.absoluteString,
            method: urlSchemeTask.request.httpMethod ?? "GET",
            headers: urlSchemeTask.request.allHTTPHeaderFields ?? [:]
        )
        
        let taskId = UUID()
        requestModels[taskId] = networkRequest
        
        // Notify delegate about new request
        delegate?.networkInterceptor(self, didCaptureRequest: networkRequest)
        
        // Create URLRequest for actual HTTP request
        var actualRequest = urlSchemeTask.request
        
        // Make the actual HTTP request using URLSession
        let dataTask = URLSession.shared.dataTask(with: actualRequest) { [weak self] data, response, error in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Update request model with response data
                if let httpResponse = response as? HTTPURLResponse {
                    networkRequest.status = httpResponse.statusCode
                    
                    // Convert HTTPURLResponse headers to [String: String]
                    var stringHeaders: [String: String] = [:]
                    for (key, value) in httpResponse.allHeaderFields {
                        stringHeaders["\(key)"] = "\(value)"
                    }
                    networkRequest.responseHeaders = stringHeaders
                }
                
                if let data = data {
                    networkRequest.size = data.count
                    networkRequest.responseBody = String(data: data, encoding: .utf8) ?? ""
                }
                
                networkRequest.duration = Date().timeIntervalSince(networkRequest.timestamp)
                
                // Notify delegate about updated request
                self.delegate?.networkInterceptor(self, didUpdateRequest: networkRequest)
                
                // Forward response to WKWebView
                if let error = error {
                    urlSchemeTask.didFailWithError(error)
                } else {
                    if let response = response {
                        urlSchemeTask.didReceive(response)
                    }
                    
                    if let data = data {
                        urlSchemeTask.didReceive(data)
                    }
                    
                    urlSchemeTask.didFinish()
                }
                
                // Clean up
                self.activeTasks.removeValue(forKey: taskId)
                self.requestModels.removeValue(forKey: taskId)
            }
        }
        
        // Store the task for potential cancellation
        activeTasks[taskId] = dataTask
        
        // Start the request
        dataTask.resume()
    }
    
    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {
        // Find and cancel the corresponding URLSession task
        if let taskId = activeTasks.first(where: { $0.value.originalRequest?.url == urlSchemeTask.request.url })?.key {
            activeTasks[taskId]?.cancel()
            activeTasks.removeValue(forKey: taskId)
            requestModels.removeValue(forKey: taskId)
        }
    }
}

// MARK: - Enhanced NetworkRequestModel

extension NetworkRequestModel {
    
    /// More accurate resource type detection using response content-type
    func updateResourceType(from response: HTTPURLResponse) {
        guard let contentType = response.allHeaderFields["Content-Type"] as? String else { return }
        
        let lowerContentType = contentType.lowercased()
        
        if lowerContentType.contains("text/html") {
            // Keep as document
        } else if lowerContentType.contains("text/css") {
            // Update internal resource type if we had one
        } else if lowerContentType.contains("javascript") || lowerContentType.contains("application/javascript") {
            // Update to script type
        } else if lowerContentType.contains("image/") {
            // Update to image type
        } else if lowerContentType.contains("font") || lowerContentType.contains("woff") {
            // Update to font type
        } else if lowerContentType.contains("application/json") || lowerContentType.contains("application/xml") {
            // Update to XHR type
        } else if lowerContentType.contains("video/") || lowerContentType.contains("audio/") {
            // Update to media type
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