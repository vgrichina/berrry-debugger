import UIKit
import WebKit

class BrowserViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    
    // MARK: - UI Components
    private let urlTextField = UITextField()
    private var webView: WKWebView!
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let toolbar = UIToolbar()
    
    // MARK: - Dev Tools
    private var devToolsViewController: DevToolsViewController?
    private var consoleLogs: [String] = []
    private var networkRequests: [NetworkRequestModel] = []
    private var networkMonitor: NetworkMonitor?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupNavigationBar()
        setupWebView()
        setupUI()
        setupConstraints()
        setupWebViewObservers()
        loadDefaultPage()
    }
    
    private func setupNavigationBar() {
        title = "BerrryDebugger"
        
        // Create navigation bar buttons
        let backButton = UIBarButtonItem(image: UIImage(systemName: "arrow.left"), style: .plain, target: self, action: #selector(goBack))
        let forwardButton = UIBarButtonItem(image: UIImage(systemName: "arrow.right"), style: .plain, target: self, action: #selector(goForward))
        let refreshButton = UIBarButtonItem(image: UIImage(systemName: "arrow.clockwise"), style: .plain, target: self, action: #selector(refresh))
        let shareButton = UIBarButtonItem(image: UIImage(systemName: "square.and.arrow.up"), style: .plain, target: self, action: #selector(shareCurrentPage))
        
        // Set left navigation items
        navigationItem.leftBarButtonItems = [backButton, forwardButton, refreshButton]
        
        // Set right navigation item
        navigationItem.rightBarButtonItem = shareButton
        
        // Setup URL field as title view
        urlTextField.borderStyle = .roundedRect
        urlTextField.placeholder = "Search or enter URL"
        urlTextField.keyboardType = .URL
        urlTextField.autocapitalizationType = .none
        urlTextField.autocorrectionType = .no
        urlTextField.delegate = self
        urlTextField.font = UIFont.systemFont(ofSize: 16)
        urlTextField.accessibilityIdentifier = "URL"
        urlTextField.returnKeyType = .go
        
        navigationItem.titleView = urlTextField
    }
    
    private func setupWebViewObservers() {
        // Observe loading progress
        webView.addObserver(self, forKeyPath: "estimatedProgress", options: .new, context: nil)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "estimatedProgress" {
            progressView.setProgress(Float(webView.estimatedProgress), animated: true)
        }
    }
    
    deinit {
        webView.removeObserver(self, forKeyPath: "estimatedProgress")
    }
    
    // MARK: - WebView Setup
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        
        // Setup network monitor
        networkMonitor = NetworkMonitor()
        networkMonitor?.delegate = self
        
        // Add console message handler
        config.userContentController.add(self, name: "console")
        
        // Add network monitoring handler
        config.userContentController.add(self, name: "networkMonitor")
        
        // Add DOM inspector handler
        config.userContentController.add(self, name: "domInspector")
        
        // Inject comprehensive network monitoring script
        if let networkMonitor = networkMonitor {
            config.userContentController.addUserScript(networkMonitor.comprehensiveNetworkScript)
            config.userContentController.addUserScript(networkMonitor.domInspectionScript)
        }
        
        // Inject console capture script
        let consoleScript = WKUserScript(
            source: """
                const originalLog = console.log;
                const originalError = console.error;
                const originalWarn = console.warn;
                
                console.log = function(...args) {
                    window.webkit.messageHandlers.console.postMessage({
                        type: 'log',
                        message: args.map(String).join(' ')
                    });
                    originalLog.apply(console, args);
                };
                
                console.error = function(...args) {
                    window.webkit.messageHandlers.console.postMessage({
                        type: 'error',
                        message: args.map(String).join(' ')
                    });
                    originalError.apply(console, args);
                };
                
                console.warn = function(...args) {
                    window.webkit.messageHandlers.console.postMessage({
                        type: 'warn',
                        message: args.map(String).join(' ')
                    });
                    originalWarn.apply(console, args);
                };
            """,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        
        config.userContentController.addUserScript(consoleScript)
        
        // Security settings
        config.allowsInlineMediaPlayback = false
        config.mediaTypesRequiringUserActionForPlayback = .all
        
        webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        
        view.addSubview(webView)
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // Progress View - attach to navigation bar
        progressView.progressTintColor = UIColor.systemBlue
        progressView.trackTintColor = UIColor.clear
        progressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressView)
        
        // Setup toolbar
        setupToolbar()
        
        webView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupToolbar() {
        // Create toolbar items
        let devToolsButton = UIBarButtonItem(
            image: UIImage(systemName: "wrench.and.screwdriver"),
            style: .plain,
            target: self,
            action: #selector(showDevTools)
        )
        devToolsButton.accessibilityIdentifier = "Developer Tools"
        
        let flexibleSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbar.items = [flexibleSpace, devToolsButton]
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toolbar)
    }
    
    
    // MARK: - Layout
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Progress View - attached to navigation bar
            progressView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),
            
            // WebView
            webView.topAnchor.constraint(equalTo: progressView.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: toolbar.topAnchor),
            
            // Toolbar
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            toolbar.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
    
    // MARK: - Public Methods
    func loadURL(_ urlString: String) {
        let finalURLString: String
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            finalURLString = urlString
        } else {
            finalURLString = "https://" + urlString
        }
        
        guard let url = URL(string: finalURLString) else { return }
        let request = URLRequest(url: url)
        webView.load(request)
        
        // Update URL text field
        DispatchQueue.main.async { [weak self] in
            self?.urlTextField.text = finalURLString
        }
    }
    
    // MARK: - Actions
    
    @objc private func goBack() {
        webView.goBack()
    }
    
    @objc private func goForward() {
        webView.goForward()
    }
    
    @objc private func refresh() {
        webView.reload()
    }
    
    @objc private func shareCurrentPage() {
        guard let url = webView.url else { return }
        
        let activityViewController = UIActivityViewController(
            activityItems: [url],
            applicationActivities: nil
        )
        
        // Handle iPad presentation - use navigation bar for popover
        if let popover = activityViewController.popoverPresentationController {
            popover.barButtonItem = navigationItem.rightBarButtonItem
        }
        
        present(activityViewController, animated: true)
    }
    
    
    @objc private func showDevTools() {
        if devToolsViewController == nil {
            devToolsViewController = DevToolsViewController()
            devToolsViewController?.delegate = self
            devToolsViewController?.setBrowserViewController(self)
        }
        
        // Configure sheet presentation
        devToolsViewController?.modalPresentationStyle = .pageSheet
        if let sheet = devToolsViewController?.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
        
        devToolsViewController?.updateData(
            consoleLogs: consoleLogs,
            networkRequests: networkRequests,
            webView: webView
        )
        
        present(devToolsViewController!, animated: true)
    }
    
    private func loadDefaultPage() {
        guard let url = URL(string: "https://httpbin.org/") else { return }
        let request = URLRequest(url: url)
        webView.load(request)
        updateSecurityIndicator(for: url)
    }
    
    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        progressView.setProgress(0.1, animated: true)
        updateSecurityIndicator(for: webView.url)
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        progressView.setProgress(1.0, animated: true)
        
        // Hide progress view after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.progressView.setProgress(0.0, animated: false)
        }
        
        updateURLDisplay()
        updateNavigationButtons()
        updateSecurityIndicator(for: webView.url)
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        progressView.setProgress(0.0, animated: false)
        updateURLDisplay()
        updateNavigationButtons()
    }
    
    private func updateURLDisplay() {
        guard let url = webView.url else { return }
        
        // Format URL for display (remove https:// for cleaner look)
        var displayURL = url.absoluteString
        if displayURL.hasPrefix("https://") {
            displayURL = String(displayURL.dropFirst(8))
        } else if displayURL.hasPrefix("http://") {
            displayURL = String(displayURL.dropFirst(7))
        }
        
        urlTextField.text = displayURL
    }
    
    private func updateNavigationButtons() {
        // Update navigation bar buttons
        if let leftItems = navigationItem.leftBarButtonItems {
            // Back button (first item)
            if leftItems.count > 0 {
                leftItems[0].isEnabled = webView.canGoBack
            }
            // Forward button (second item)
            if leftItems.count > 1 {
                leftItems[1].isEnabled = webView.canGoForward
            }
        }
    }
    
    private func updateSecurityIndicator(for url: URL?) {
        // Security indication is now handled through URL display
        // The URL field itself shows the security state visually
        guard let url = url else { return }
        
        let isSecure = url.scheme == "https"
        
        // Update URL field appearance based on security
        if isSecure {
            urlTextField.textColor = UIColor.label
        } else {
            urlTextField.textColor = UIColor.systemOrange
        }
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Clear network requests for main frame navigations (new page loads)
        if navigationAction.targetFrame?.isMainFrame == true {
            networkRequests.removeAll()
            
            // Capture the navigation request itself
            if let url = navigationAction.request.url {
                let navigationRequest = NetworkRequestModel(
                    url: url.absoluteString,
                    method: navigationAction.request.httpMethod ?? "GET",
                    headers: navigationAction.request.allHTTPHeaderFields ?? [:],
                    type: .navigation
                )
                navigationRequest.status = 200 // Will be updated when load completes
                networkRequests.append(navigationRequest)
            }
            
            // Update DevTools if it's currently open
            if let devTools = devToolsViewController {
                devTools.updateData(consoleLogs: consoleLogs, networkRequests: networkRequests, webView: webView)
            }
        }
        
        decisionHandler(.allow)
    }
    
    // MARK: - WKScriptMessageHandler
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        if message.name == "console",
           let body = message.body as? [String: Any],
           let type = body["type"] as? String,
           let logMessage = body["message"] as? String {
            
            let formattedLog = "[\(type.uppercased())] \(logMessage)"
            consoleLogs.append(formattedLog)
            
            // Limit console logs to prevent memory issues
            if consoleLogs.count > 1000 {
                consoleLogs.removeFirst(100)
            }
        } else if message.name == "networkMonitor",
                  let body = message.body as? [String: Any] {
            networkMonitor?.handleNetworkMessage(body)
        } else if message.name == "domInspector",
                  let body = message.body as? [String: Any] {
            handleDOMInspectorMessage(body)
        }
    }
    
    // MARK: - DOM Inspector Message Handling
    private func handleDOMInspectorMessage(_ messageBody: [String: Any]) {
        guard let type = messageBody["type"] as? String else { return }
        
        DispatchQueue.main.async { [weak self] in
            switch type {
            case "domTreeReady":
                if let treeData = messageBody["tree"] as? [String: Any] {
                    self?.devToolsViewController?.updateDOMTree(treeData)
                }
            case "elementSelected":
                if let elementData = messageBody["element"] as? [String: Any] {
                    self?.devToolsViewController?.updateSelectedElement(elementData)
                }
            case "selectionModeEnabled":
                print("🔍 Element selection mode enabled")
            case "selectionModeDisabled":
                print("🔍 Element selection mode disabled")
            default:
                print("🔍 Unknown DOM inspector message type: \(type)")
            }
        }
    }
    
    // MARK: - Public Methods for DOM Inspection
    func enableElementSelection() {
        webView.evaluateJavaScript("window.berrryDOM?.enableElementSelection();") { result, error in
            if let error = error {
                print("Error enabling element selection: \(error)")
            }
        }
    }
    
    func disableElementSelection() {
        webView.evaluateJavaScript("window.berrryDOM?.disableElementSelection();") { result, error in
            if let error = error {
                print("Error disabling element selection: \(error)")
            }
        }
    }
    
    func refreshDOMTree() {
        webView.evaluateJavaScript("window.berrryDOM?.buildDOMTree();") { [weak self] result, error in
            if let error = error {
                print("Error refreshing DOM tree: \(error)")
                return
            }
            
            if let treeData = result as? [String: Any] {
                DispatchQueue.main.async {
                    self?.devToolsViewController?.updateDOMTree(treeData)
                }
            }
        }
    }
}

// MARK: - UITextFieldDelegate
extension BrowserViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let urlString = textField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !urlString.isEmpty else { return false }
        
        loadURL(urlString)
        textField.resignFirstResponder()
        return true
    }
}

// MARK: - NetworkMonitorDelegate
extension BrowserViewController: NetworkMonitorDelegate {
    func networkMonitor(_ monitor: NetworkMonitor, didCaptureRequest request: NetworkRequestModel) {
        DispatchQueue.main.async {
            self.networkRequests.append(request)
            
            // Limit network requests to prevent memory issues
            if self.networkRequests.count > 500 {
                self.networkRequests.removeFirst(100)
            }
            
            // Update DevTools if it's currently open and showing network tab
            if let devTools = self.devToolsViewController {
                devTools.updateData(consoleLogs: self.consoleLogs, networkRequests: self.networkRequests, webView: self.webView)
            }
        }
    }
    
    func networkMonitor(_ monitor: NetworkMonitor, didUpdateRequest request: NetworkRequestModel) {
        DispatchQueue.main.async {
            // The request object is already in our array and updated by reference
            // Just refresh the DevTools display
            if let devTools = self.devToolsViewController {
                devTools.updateData(consoleLogs: self.consoleLogs, networkRequests: self.networkRequests, webView: self.webView)
            }
        }
    }
}

// MARK: - DevToolsViewControllerDelegate
extension BrowserViewController: DevToolsViewControllerDelegate {
    func devToolsDidRequestDOMExtraction(for selector: String, completion: @escaping (String?) -> Void) {
        let script = selector.isEmpty ? 
            "document.documentElement.outerHTML" :
            "document.querySelector('\(selector)')?.outerHTML || ''"
        
        webView.evaluateJavaScript(script) { result, error in
            completion(result as? String)
        }
    }
    
    func devToolsDidRequestCSSExtraction(for selector: String, completion: @escaping (String?) -> Void) {
        let script = """
            const element = document.querySelector('\(selector)');
            if (element) {
                const styles = window.getComputedStyle(element);
                let cssText = '';
                for (let i = 0; i < styles.length; i++) {
                    const property = styles[i];
                    cssText += property + ': ' + styles.getPropertyValue(property) + '; ';
                }
                cssText;
            } else {
                '';
            }
        """
        
        webView.evaluateJavaScript(script) { result, error in
            completion(result as? String)
        }
    }
}