import Foundation
import WebKit

protocol NetworkMonitorDelegate: AnyObject {
    func networkMonitor(_ monitor: NetworkMonitor, didCaptureRequest request: NetworkRequestModel)
    func networkMonitor(_ monitor: NetworkMonitor, didUpdateRequest request: NetworkRequestModel)
}

class NetworkMonitor: NSObject {
    
    weak var delegate: NetworkMonitorDelegate?
    private var activeConnections: [String: NetworkRequestModel] = [:]
    
    // MARK: - JavaScript Injection
    
    var comprehensiveNetworkScript: WKUserScript {
        let source = """
        (function() {
            // Utility function to generate unique IDs
            function generateId() {
                return Math.random().toString(36).substr(2, 9);
            }
            
            // Utility function to safely post messages
            function postMessage(data) {
                try {
                    webkit.messageHandlers.networkMonitor.postMessage(data);
                } catch (e) {
                    console.error('Failed to post network message:', e);
                }
            }
            
            // 1. FETCH API INTERCEPTION
            const originalFetch = window.fetch;
            window.fetch = function(input, init) {
                const requestId = generateId();
                const startTime = performance.now();
                
                let url = input;
                let method = 'GET';
                let headers = {};
                
                if (input instanceof Request) {
                    url = input.url;
                    method = input.method;
                    headers = Object.fromEntries(input.headers.entries());
                } else if (init) {
                    method = init.method || 'GET';
                    if (init.headers) {
                        if (init.headers instanceof Headers) {
                            headers = Object.fromEntries(init.headers.entries());
                        } else {
                            headers = init.headers;
                        }
                    }
                }
                
                postMessage({
                    type: 'fetch',
                    event: 'request',
                    id: requestId,
                    url: url,
                    method: method,
                    headers: headers,
                    body: init?.body ? String(init.body) : null,
                    timestamp: Date.now(),
                    startTime: startTime
                });
                
                return originalFetch.apply(this, arguments)
                    .then(response => {
                        const endTime = performance.now();
                        
                        postMessage({
                            type: 'fetch',
                            event: 'response',
                            id: requestId,
                            status: response.status,
                            statusText: response.statusText,
                            headers: Object.fromEntries(response.headers.entries()),
                            url: response.url,
                            timestamp: Date.now(),
                            duration: endTime - startTime
                        });
                        
                        return response;
                    })
                    .catch(error => {
                        const endTime = performance.now();
                        
                        postMessage({
                            type: 'fetch',
                            event: 'error',
                            id: requestId,
                            error: error.message,
                            timestamp: Date.now(),
                            duration: endTime - startTime
                        });
                        
                        throw error;
                    });
            };
            
            // 2. XMLHTTPREQUEST INTERCEPTION
            const OriginalXHR = XMLHttpRequest;
            window.XMLHttpRequest = function() {
                const xhr = new OriginalXHR();
                const requestId = generateId();
                let startTime;
                let method, url;
                
                const originalOpen = xhr.open;
                xhr.open = function(m, u, async, user, password) {
                    method = m;
                    url = u;
                    startTime = performance.now();
                    
                    postMessage({
                        type: 'xhr',
                        event: 'open',
                        id: requestId,
                        method: method,
                        url: url,
                        async: async !== false,
                        timestamp: Date.now()
                    });
                    
                    return originalOpen.call(this, m, u, async, user, password);
                };
                
                const originalSend = xhr.send;
                xhr.send = function(data) {
                    postMessage({
                        type: 'xhr',
                        event: 'send',
                        id: requestId,
                        data: data ? String(data) : null,
                        timestamp: Date.now()
                    });
                    
                    return originalSend.call(this, data);
                };
                
                xhr.addEventListener('loadstart', function() {
                    postMessage({
                        type: 'xhr',
                        event: 'loadstart',
                        id: requestId,
                        timestamp: Date.now()
                    });
                });
                
                xhr.addEventListener('load', function() {
                    const endTime = performance.now();
                    postMessage({
                        type: 'xhr',
                        event: 'load',
                        id: requestId,
                        status: xhr.status,
                        statusText: xhr.statusText,
                        responseHeaders: xhr.getAllResponseHeaders(),
                        responseText: xhr.responseText,
                        timestamp: Date.now(),
                        duration: startTime ? endTime - startTime : 0
                    });
                });
                
                xhr.addEventListener('error', function() {
                    const endTime = performance.now();
                    postMessage({
                        type: 'xhr',
                        event: 'error',
                        id: requestId,
                        timestamp: Date.now(),
                        duration: startTime ? endTime - startTime : 0
                    });
                });
                
                return xhr;
            };
            
            // 3. WEBSOCKET INTERCEPTION
            const OriginalWebSocket = window.WebSocket;
            window.WebSocket = function(url, protocols) {
                const ws = new OriginalWebSocket(url, protocols);
                const connectionId = generateId();
                
                postMessage({
                    type: 'websocket',
                    event: 'connection',
                    id: connectionId,
                    url: url,
                    protocols: protocols,
                    timestamp: Date.now()
                });
                
                ws.addEventListener('open', function(event) {
                    postMessage({
                        type: 'websocket',
                        event: 'open',
                        id: connectionId,
                        timestamp: Date.now()
                    });
                });
                
                ws.addEventListener('message', function(event) {
                    postMessage({
                        type: 'websocket',
                        event: 'message',
                        id: connectionId,
                        data: event.data,
                        dataType: typeof event.data,
                        dataSize: event.data ? event.data.length : 0,
                        timestamp: Date.now()
                    });
                });
                
                ws.addEventListener('close', function(event) {
                    postMessage({
                        type: 'websocket',
                        event: 'close',
                        id: connectionId,
                        code: event.code,
                        reason: event.reason,
                        wasClean: event.wasClean,
                        timestamp: Date.now()
                    });
                });
                
                ws.addEventListener('error', function(event) {
                    postMessage({
                        type: 'websocket',
                        event: 'error',
                        id: connectionId,
                        timestamp: Date.now()
                    });
                });
                
                const originalSend = ws.send;
                ws.send = function(data) {
                    postMessage({
                        type: 'websocket',
                        event: 'send',
                        id: connectionId,
                        data: data,
                        dataType: typeof data,
                        dataSize: data ? data.length : 0,
                        timestamp: Date.now()
                    });
                    return originalSend.call(this, data);
                };
                
                return ws;
            };
            Object.setPrototypeOf(window.WebSocket, OriginalWebSocket);
            window.WebSocket.prototype = OriginalWebSocket.prototype;
            
            // 4. EVENTSOURCE INTERCEPTION
            if (window.EventSource) {
                const OriginalEventSource = window.EventSource;
                window.EventSource = function(url, eventSourceInitDict) {
                    const es = new OriginalEventSource(url, eventSourceInitDict);
                    const connectionId = generateId();
                    
                    postMessage({
                        type: 'eventsource',
                        event: 'connection',
                        id: connectionId,
                        url: url,
                        withCredentials: eventSourceInitDict?.withCredentials || false,
                        timestamp: Date.now()
                    });
                    
                    es.addEventListener('open', function(event) {
                        postMessage({
                            type: 'eventsource',
                            event: 'open',
                            id: connectionId,
                            timestamp: Date.now()
                        });
                    });
                    
                    es.addEventListener('message', function(event) {
                        postMessage({
                            type: 'eventsource',
                            event: 'message',
                            id: connectionId,
                            data: event.data,
                            lastEventId: event.lastEventId,
                            origin: event.origin,
                            timestamp: Date.now()
                        });
                    });
                    
                    es.addEventListener('error', function(event) {
                        postMessage({
                            type: 'eventsource',
                            event: 'error',
                            id: connectionId,
                            readyState: es.readyState,
                            timestamp: Date.now()
                        });
                    });
                    
                    return es;
                };
                Object.setPrototypeOf(window.EventSource, OriginalEventSource);
                window.EventSource.prototype = OriginalEventSource.prototype;
            }
            
            // 5. WEBRTC INTERCEPTION
            const OriginalRTCPeerConnection = window.RTCPeerConnection || 
                                           window.webkitRTCPeerConnection || 
                                           window.mozRTCPeerConnection;
            
            if (OriginalRTCPeerConnection) {
                window.RTCPeerConnection = function(configuration, constraints) {
                    const pc = new OriginalRTCPeerConnection(configuration, constraints);
                    const connectionId = generateId();
                    
                    postMessage({
                        type: 'webrtc',
                        event: 'connection',
                        id: connectionId,
                        configuration: configuration,
                        constraints: constraints,
                        timestamp: Date.now()
                    });
                    
                    pc.addEventListener('connectionstatechange', function() {
                        postMessage({
                            type: 'webrtc',
                            event: 'connectionstatechange',
                            id: connectionId,
                            connectionState: pc.connectionState,
                            timestamp: Date.now()
                        });
                    });
                    
                    pc.addEventListener('iceconnectionstatechange', function() {
                        postMessage({
                            type: 'webrtc',
                            event: 'iceconnectionstatechange',
                            id: connectionId,
                            iceConnectionState: pc.iceConnectionState,
                            timestamp: Date.now()
                        });
                    });
                    
                    pc.addEventListener('datachannel', function(event) {
                        postMessage({
                            type: 'webrtc',
                            event: 'datachannel',
                            id: connectionId,
                            channelLabel: event.channel.label,
                            channelId: event.channel.id,
                            timestamp: Date.now()
                        });
                    });
                    
                    const originalCreateDataChannel = pc.createDataChannel;
                    pc.createDataChannel = function(label, dataChannelDict) {
                        const channel = originalCreateDataChannel.call(this, label, dataChannelDict);
                        
                        postMessage({
                            type: 'webrtc',
                            event: 'createDataChannel',
                            id: connectionId,
                            label: label,
                            options: dataChannelDict,
                            timestamp: Date.now()
                        });
                        
                        return channel;
                    };
                    
                    return pc;
                };
                Object.setPrototypeOf(window.RTCPeerConnection, OriginalRTCPeerConnection);
                window.RTCPeerConnection.prototype = OriginalRTCPeerConnection.prototype;
                
                // Also handle the prefixed versions
                if (window.webkitRTCPeerConnection) {
                    window.webkitRTCPeerConnection = window.RTCPeerConnection;
                }
                if (window.mozRTCPeerConnection) {
                    window.mozRTCPeerConnection = window.RTCPeerConnection;
                }
            }
            
            // 6. PERFORMANCE OBSERVER FOR STATIC RESOURCES
            if (window.PerformanceObserver) {
                try {
                    const observer = new PerformanceObserver(function(list) {
                        list.getEntries().forEach(function(entry) {
                            if (entry.entryType === 'resource') {
                                postMessage({
                                    type: 'resource',
                                    event: 'load',
                                    id: generateId(),
                                    url: entry.name,
                                    method: 'GET',
                                    initiatorType: entry.initiatorType,
                                    duration: entry.duration,
                                    transferSize: entry.transferSize,
                                    encodedBodySize: entry.encodedBodySize,
                                    decodedBodySize: entry.decodedBodySize,
                                    timestamp: Date.now(),
                                    startTime: entry.startTime,
                                    responseStart: entry.responseStart,
                                    responseEnd: entry.responseEnd
                                });
                            }
                        });
                    });
                    observer.observe({entryTypes: ['resource']});
                } catch (e) {
                    console.warn('PerformanceObserver not supported:', e);
                }
            }
            
            console.log('🔍 BerrryDebugger network monitoring initialized');
            
            // Test message to verify injection is working
            postMessage({
                type: 'debug',
                event: 'initialized',
                message: 'Network monitoring script loaded successfully',
                timestamp: Date.now()
            });
        })();
        """
        
        return WKUserScript(
            source: source,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
    }
    
    // MARK: - DOM Inspection Script
    
    var domInspectionScript: WKUserScript {
        let source = """
        (function() {
            // Utility function to safely post messages
            function postDOMMessage(data) {
                try {
                    webkit.messageHandlers.domInspector.postMessage(data);
                } catch (e) {
                    console.error('Failed to post DOM message:', e);
                }
            }
            
            // Generate CSS selector for element
            function generateSelector(element) {
                if (element.id) return '#' + element.id;
                
                let selector = element.tagName.toLowerCase();
                if (element.className && element.className.trim()) {
                    const classes = element.className.trim().split(/\\s+/).join('.');
                    selector += '.' + classes;
                }
                
                // Add nth-child if no unique identifier
                if (!element.id && (!element.className || element.className.trim() === '')) {
                    const parent = element.parentNode;
                    if (parent) {
                        const siblings = Array.from(parent.children);
                        const index = siblings.indexOf(element) + 1;
                        selector += ':nth-child(' + index + ')';
                    }
                }
                
                return selector;
            }
            
            // Extract comprehensive element data
            function getElementData(element) {
                const rect = element.getBoundingClientRect();
                const computedStyle = window.getComputedStyle(element);
                
                return {
                    tagName: element.tagName,
                    id: element.id || null,
                    className: element.className || null,
                    attributes: Object.fromEntries(
                        Array.from(element.attributes).map(attr => [attr.name, attr.value])
                    ),
                    textContent: element.textContent ? element.textContent.substring(0, 200) : null,
                    innerHTML: element.innerHTML ? element.innerHTML.substring(0, 500) : null,
                    selector: generateSelector(element),
                    dimensions: {
                        width: Math.round(rect.width),
                        height: Math.round(rect.height),
                        top: Math.round(rect.top),
                        left: Math.round(rect.left)
                    },
                    styles: {
                        display: computedStyle.display,
                        position: computedStyle.position,
                        color: computedStyle.color,
                        backgroundColor: computedStyle.backgroundColor,
                        fontSize: computedStyle.fontSize,
                        fontFamily: computedStyle.fontFamily,
                        margin: computedStyle.margin,
                        padding: computedStyle.padding,
                        border: computedStyle.border,
                        zIndex: computedStyle.zIndex
                    }
                };
            }
            
            // Build DOM tree structure
            function buildDOMTree(root = document.documentElement, maxDepth = 10) {
                function traverse(element, depth = 0) {
                    if (depth > maxDepth) return null;
                    
                    const data = getElementData(element);
                    data.depth = depth;
                    data.hasChildren = element.children.length > 0;
                    data.childCount = element.children.length;
                    
                    // Only traverse children for first few levels to avoid huge trees
                    if (depth < 3) {
                        data.children = Array.from(element.children)
                            .filter(child => child.nodeType === 1) // Only element nodes
                            .map(child => traverse(child, depth + 1))
                            .filter(child => child !== null);
                    } else {
                        data.children = [];
                    }
                    
                    return data;
                }
                return traverse(root);
            }
            
            // Element selection and highlighting
            let selectionMode = false;
            let highlightOverlay = null;
            let selectedElement = null;
            
            function enableElementSelection() {
                selectionMode = true;
                document.body.style.cursor = 'crosshair';
                document.addEventListener('mouseover', highlightElement, true);
                document.addEventListener('click', selectElement, true);
                
                postDOMMessage({
                    type: 'selectionModeEnabled',
                    timestamp: Date.now()
                });
            }
            
            function disableElementSelection() {
                selectionMode = false;
                document.body.style.cursor = '';
                removeHighlight();
                document.removeEventListener('mouseover', highlightElement, true);
                document.removeEventListener('click', selectElement, true);
                
                postDOMMessage({
                    type: 'selectionModeDisabled',
                    timestamp: Date.now()
                });
            }
            
            function highlightElement(event) {
                if (!selectionMode) return;
                
                removeHighlight();
                const element = event.target;
                const rect = element.getBoundingClientRect();
                
                highlightOverlay = document.createElement('div');
                highlightOverlay.style.cssText = `
                    position: fixed;
                    top: ${rect.top}px;
                    left: ${rect.left}px;
                    width: ${rect.width}px;
                    height: ${rect.height}px;
                    border: 2px solid #007AFF;
                    background: rgba(0, 122, 255, 0.1);
                    pointer-events: none;
                    z-index: 999999;
                    box-sizing: border-box;
                `;
                highlightOverlay.setAttribute('data-berrry-highlight', 'true');
                document.body.appendChild(highlightOverlay);
            }
            
            function selectElement(event) {
                if (!selectionMode) return;
                
                event.preventDefault();
                event.stopPropagation();
                
                const element = event.target;
                if (element.hasAttribute('data-berrry-highlight')) return;
                
                selectedElement = element;
                const elementData = getElementData(element);
                
                postDOMMessage({
                    type: 'elementSelected',
                    element: elementData,
                    timestamp: Date.now()
                });
                
                disableElementSelection();
            }
            
            function removeHighlight() {
                if (highlightOverlay) {
                    highlightOverlay.remove();
                    highlightOverlay = null;
                }
            }
            
            // Storage inspection functions
            function getStorageData() {
                try {
                    const localStorageData = {};
                    for (let i = 0; i < localStorage.length; i++) {
                        const key = localStorage.key(i);
                        localStorageData[key] = localStorage.getItem(key);
                    }
                    
                    const sessionStorageData = {};
                    for (let i = 0; i < sessionStorage.length; i++) {
                        const key = sessionStorage.key(i);
                        sessionStorageData[key] = sessionStorage.getItem(key);
                    }
                    
                    const cookies = document.cookie.split(';').reduce((acc, cookie) => {
                        const [key, value] = cookie.trim().split('=');
                        if (key) acc[key] = value || '';
                        return acc;
                    }, {});
                    
                    return {
                        localStorage: localStorageData,
                        sessionStorage: sessionStorageData,
                        cookies: cookies,
                        url: window.location.href
                    };
                } catch (e) {
                    return {
                        error: 'Failed to access storage: ' + e.message,
                        url: window.location.href
                    };
                }
            }
            
            // Export functions to global scope for manual testing
            window.berrryDOM = {
                buildDOMTree,
                enableElementSelection,
                disableElementSelection,
                getElementData,
                getStorageData,
                getSelectedElement: () => selectedElement
            };
            
            console.log('🔍 BerrryDebugger DOM inspector initialized');
            
            // Initialize DOM tree on load
            if (document.readyState === 'complete') {
                const domTree = buildDOMTree();
                postDOMMessage({
                    type: 'domTreeReady',
                    tree: domTree,
                    timestamp: Date.now()
                });
            } else {
                window.addEventListener('load', () => {
                    const domTree = buildDOMTree();
                    postDOMMessage({
                        type: 'domTreeReady',
                        tree: domTree,
                        timestamp: Date.now()
                    });
                });
            }
        })();
        """
        
        return WKUserScript(
            source: source,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
    }
    
    // MARK: - Message Handling
    
    func handleNetworkMessage(_ message: [String: Any]) {
        guard let type = message["type"] as? String,
              let event = message["event"] as? String else { return }
        
        switch type {
        case "fetch":
            handleFetchMessage(message)
        case "xhr":
            handleXHRMessage(message)
        case "websocket":
            handleWebSocketMessage(message)
        case "eventsource":
            handleEventSourceMessage(message)
        case "webrtc":
            handleWebRTCMessage(message)
        case "resource":
            handleResourceMessage(message)
        case "debug":
            print("🔍 NetworkMonitor Debug: \(message["message"] ?? "Unknown debug message")")
        default:
            break
        }
    }
    
    private func handleFetchMessage(_ message: [String: Any]) {
        guard let event = message["event"] as? String,
              let id = message["id"] as? String else { return }
        
        switch event {
        case "request":
            let request = NetworkRequestModel(
                url: message["url"] as? String ?? "",
                method: message["method"] as? String ?? "GET",
                headers: message["headers"] as? [String: String] ?? [:],
                type: .fetch
            )
            request.connectionId = id
            activeConnections[id] = request
            delegate?.networkMonitor(self, didCaptureRequest: request)
            
        case "response":
            if let request = activeConnections[id] {
                request.status = message["status"] as? Int ?? 0
                request.responseHeaders = message["headers"] as? [String: String] ?? [:]
                request.duration = (message["duration"] as? Double ?? 0) / 1000.0
                delegate?.networkMonitor(self, didUpdateRequest: request)
            }
            
        case "error":
            if let request = activeConnections[id] {
                request.status = 0
                request.duration = (message["duration"] as? Double ?? 0) / 1000.0
                request.responseBody = message["error"] as? String ?? "Network Error"
                delegate?.networkMonitor(self, didUpdateRequest: request)
            }
        default:
            break
        }
    }
    
    private func handleXHRMessage(_ message: [String: Any]) {
        guard let event = message["event"] as? String,
              let id = message["id"] as? String else { return }
        
        switch event {
        case "open":
            let request = NetworkRequestModel(
                url: message["url"] as? String ?? "",
                method: message["method"] as? String ?? "GET",
                headers: [:],
                type: .xhr
            )
            request.connectionId = id
            activeConnections[id] = request
            delegate?.networkMonitor(self, didCaptureRequest: request)
            
        case "load":
            if let request = activeConnections[id] {
                request.status = message["status"] as? Int ?? 0
                request.responseBody = message["responseText"] as? String ?? ""
                request.duration = (message["duration"] as? Double ?? 0) / 1000.0
                
                // Parse response headers
                if let headerString = message["responseHeaders"] as? String {
                    request.responseHeaders = parseResponseHeaders(headerString)
                }
                
                delegate?.networkMonitor(self, didUpdateRequest: request)
            }
            
        case "error":
            if let request = activeConnections[id] {
                request.status = 0
                request.duration = (message["duration"] as? Double ?? 0) / 1000.0
                delegate?.networkMonitor(self, didUpdateRequest: request)
            }
        default:
            break
        }
    }
    
    private func handleWebSocketMessage(_ message: [String: Any]) {
        guard let event = message["event"] as? String,
              let id = message["id"] as? String else { return }
        
        switch event {
        case "connection":
            let request = NetworkRequestModel(
                url: message["url"] as? String ?? "",
                method: "WEBSOCKET",
                headers: [:],
                type: .websocket
            )
            request.connectionId = id
            request.status = 101 // WebSocket Upgrade
            activeConnections[id] = request
            delegate?.networkMonitor(self, didCaptureRequest: request)
            
        case "open":
            if let request = activeConnections[id] {
                request.eventData["state"] = "open"
                delegate?.networkMonitor(self, didUpdateRequest: request)
            }
            
        case "message":
            if let request = activeConnections[id] {
                let messageData = message["data"] as? String ?? ""
                let messageSize = message["dataSize"] as? Int ?? 0
                request.size += messageSize
                request.eventData["lastMessage"] = messageData
                request.eventData["messageCount"] = (request.eventData["messageCount"] as? Int ?? 0) + 1
                delegate?.networkMonitor(self, didUpdateRequest: request)
            }
            
        case "close":
            if let request = activeConnections[id] {
                request.eventData["state"] = "closed"
                request.eventData["closeCode"] = message["code"]
                request.eventData["closeReason"] = message["reason"]
                delegate?.networkMonitor(self, didUpdateRequest: request)
                activeConnections.removeValue(forKey: id)
            }
            
        case "error":
            if let request = activeConnections[id] {
                request.eventData["state"] = "error"
                request.status = 0
                delegate?.networkMonitor(self, didUpdateRequest: request)
            }
        default:
            break
        }
    }
    
    private func handleEventSourceMessage(_ message: [String: Any]) {
        guard let event = message["event"] as? String,
              let id = message["id"] as? String else { return }
        
        switch event {
        case "connection":
            let request = NetworkRequestModel(
                url: message["url"] as? String ?? "",
                method: "EVENTSOURCE",
                headers: [:],
                type: .eventsource
            )
            request.connectionId = id
            request.status = 200
            activeConnections[id] = request
            delegate?.networkMonitor(self, didCaptureRequest: request)
            
        case "message":
            if let request = activeConnections[id] {
                let messageData = message["data"] as? String ?? ""
                request.size += messageData.count
                request.eventData["lastMessage"] = messageData
                request.eventData["messageCount"] = (request.eventData["messageCount"] as? Int ?? 0) + 1
                delegate?.networkMonitor(self, didUpdateRequest: request)
            }
            
        case "error":
            if let request = activeConnections[id] {
                request.status = 0
                request.eventData["state"] = "error"
                delegate?.networkMonitor(self, didUpdateRequest: request)
            }
        default:
            break
        }
    }
    
    private func handleWebRTCMessage(_ message: [String: Any]) {
        guard let event = message["event"] as? String,
              let id = message["id"] as? String else { return }
        
        switch event {
        case "connection":
            let request = NetworkRequestModel(
                url: "webrtc://peer-connection",
                method: "WEBRTC",
                headers: [:],
                type: .webrtc
            )
            request.connectionId = id
            request.status = 200
            request.eventData["configuration"] = message["configuration"]
            activeConnections[id] = request
            delegate?.networkMonitor(self, didCaptureRequest: request)
            
        case "connectionstatechange":
            if let request = activeConnections[id] {
                request.eventData["connectionState"] = message["connectionState"]
                delegate?.networkMonitor(self, didUpdateRequest: request)
            }
            
        case "datachannel":
            if let request = activeConnections[id] {
                let channelCount = (request.eventData["dataChannelCount"] as? Int ?? 0) + 1
                request.eventData["dataChannelCount"] = channelCount
                delegate?.networkMonitor(self, didUpdateRequest: request)
            }
        default:
            break
        }
    }
    
    private func handleResourceMessage(_ message: [String: Any]) {
        let request = NetworkRequestModel(
            url: message["url"] as? String ?? "",
            method: "GET",
            headers: [:],
            type: .resource
        )
        request.status = 200
        request.duration = (message["duration"] as? Double ?? 0) / 1000.0
        request.size = message["transferSize"] as? Int ?? 0
        request.eventData["initiatorType"] = message["initiatorType"]
        
        delegate?.networkMonitor(self, didCaptureRequest: request)
    }
    
    private func parseResponseHeaders(_ headerString: String) -> [String: String] {
        var headers: [String: String] = [:]
        let lines = headerString.components(separatedBy: "\r\n")
        
        for line in lines {
            let parts = line.components(separatedBy: ": ")
            if parts.count >= 2 {
                let key = parts[0]
                let value = parts.dropFirst().joined(separator: ": ")
                headers[key] = value
            }
        }
        
        return headers
    }
}