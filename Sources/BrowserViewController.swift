import UIKit
import WebKit

class BrowserViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    
    // MARK: - UI Components
    private let urlContainerView = UIView()
    private let securityIndicator = UIButton(type: .system)
    private let urlTextField = UITextField()
    private let goButton = UIButton(type: .system)
    private let backButton = UIButton(type: .system)
    private let forwardButton = UIButton(type: .system)
    private let refreshButton = UIButton(type: .system)
    private let shareButton = UIButton(type: .system)
    private var webView: WKWebView!
    private let devToolsFAB = UIButton(type: .system)
    private let progressView = UIProgressView(progressViewStyle: .default)
    
    // MARK: - Dev Tools
    private var devToolsViewController: DevToolsViewController?
    private var consoleLogs: [String] = []
    private var networkRequests: [NetworkRequestModel] = []
    private var networkMonitor: NetworkMonitor?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        setupUI()
        setupConstraints()
        setupWebViewObservers()
        loadDefaultPage()
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
        
        // Inject comprehensive network monitoring script
        if let networkMonitor = networkMonitor {
            config.userContentController.addUserScript(networkMonitor.comprehensiveNetworkScript)
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
        
        // URL Container View
        urlContainerView.backgroundColor = UIColor.systemGray6
        urlContainerView.layer.cornerRadius = 12
        urlContainerView.layer.borderWidth = 1
        urlContainerView.layer.borderColor = UIColor.systemGray4.cgColor
        urlContainerView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(urlContainerView)
        
        // Security Indicator
        securityIndicator.setImage(UIImage(systemName: "lock.fill"), for: .normal)
        securityIndicator.tintColor = UIColor.systemGreen
        securityIndicator.addTarget(self, action: #selector(securityIndicatorTapped), for: .touchUpInside)
        securityIndicator.translatesAutoresizingMaskIntoConstraints = false
        urlContainerView.addSubview(securityIndicator)
        
        // URL Text Field
        urlTextField.borderStyle = .none
        urlTextField.placeholder = "Search or enter URL"
        urlTextField.keyboardType = .URL
        urlTextField.autocapitalizationType = .none
        urlTextField.autocorrectionType = .no
        urlTextField.delegate = self
        urlTextField.backgroundColor = UIColor.clear
        urlTextField.font = UIFont.systemFont(ofSize: 16)
        urlTextField.translatesAutoresizingMaskIntoConstraints = false
        urlContainerView.addSubview(urlTextField)
        
        // Go Button
        goButton.setTitle("Go", for: .normal)
        goButton.backgroundColor = UIColor.systemBlue
        goButton.setTitleColor(.white, for: .normal)
        goButton.layer.cornerRadius = 8
        goButton.addTarget(self, action: #selector(goButtonTapped), for: .touchUpInside)
        goButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(goButton)
        
        // Navigation Buttons
        setupNavigationButtons()
        
        // Progress View
        progressView.progressTintColor = UIColor.systemBlue
        progressView.trackTintColor = UIColor.clear
        progressView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(progressView)
        
        // Dev Tools FAB
        devToolsFAB.setImage(UIImage(systemName: "wrench.and.screwdriver"), for: .normal)
        devToolsFAB.backgroundColor = UIColor.systemBlue
        devToolsFAB.tintColor = .white
        devToolsFAB.layer.cornerRadius = 28
        devToolsFAB.layer.shadowColor = UIColor.black.cgColor
        devToolsFAB.layer.shadowOffset = CGSize(width: 0, height: 2)
        devToolsFAB.layer.shadowRadius = 4
        devToolsFAB.layer.shadowOpacity = 0.2
        devToolsFAB.addTarget(self, action: #selector(showDevTools), for: .touchUpInside)
        devToolsFAB.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(devToolsFAB)
        
        webView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupNavigationButtons() {
        // Back Button
        backButton.setImage(UIImage(systemName: "arrow.left"), for: .normal)
        backButton.addTarget(self, action: #selector(goBack), for: .touchUpInside)
        backButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(backButton)
        
        // Forward Button
        forwardButton.setImage(UIImage(systemName: "arrow.right"), for: .normal)
        forwardButton.addTarget(self, action: #selector(goForward), for: .touchUpInside)
        forwardButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(forwardButton)
        
        // Refresh Button
        refreshButton.setImage(UIImage(systemName: "arrow.clockwise"), for: .normal)
        refreshButton.addTarget(self, action: #selector(refresh), for: .touchUpInside)
        refreshButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(refreshButton)
        
        // Share Button
        shareButton.setImage(UIImage(systemName: "square.and.arrow.up"), for: .normal)
        shareButton.addTarget(self, action: #selector(shareCurrentPage), for: .touchUpInside)
        shareButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(shareButton)
    }
    
    // MARK: - Layout
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // URL Container
            urlContainerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            urlContainerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            urlContainerView.trailingAnchor.constraint(equalTo: goButton.leadingAnchor, constant: -8),
            urlContainerView.heightAnchor.constraint(equalToConstant: 48),
            
            // Security Indicator
            securityIndicator.leadingAnchor.constraint(equalTo: urlContainerView.leadingAnchor, constant: 12),
            securityIndicator.centerYAnchor.constraint(equalTo: urlContainerView.centerYAnchor),
            securityIndicator.widthAnchor.constraint(equalToConstant: 24),
            securityIndicator.heightAnchor.constraint(equalToConstant: 24),
            
            // URL Text Field
            urlTextField.leadingAnchor.constraint(equalTo: securityIndicator.trailingAnchor, constant: 8),
            urlTextField.trailingAnchor.constraint(equalTo: urlContainerView.trailingAnchor, constant: -12),
            urlTextField.centerYAnchor.constraint(equalTo: urlContainerView.centerYAnchor),
            urlTextField.heightAnchor.constraint(equalToConstant: 40),
            
            // Go Button
            goButton.centerYAnchor.constraint(equalTo: urlContainerView.centerYAnchor),
            goButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            goButton.widthAnchor.constraint(equalToConstant: 60),
            goButton.heightAnchor.constraint(equalToConstant: 48),
            
            // Navigation Buttons
            backButton.topAnchor.constraint(equalTo: urlContainerView.bottomAnchor, constant: 8),
            backButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: 44),
            
            forwardButton.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            forwardButton.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 8),
            forwardButton.widthAnchor.constraint(equalToConstant: 44),
            forwardButton.heightAnchor.constraint(equalToConstant: 44),
            
            refreshButton.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            refreshButton.leadingAnchor.constraint(equalTo: forwardButton.trailingAnchor, constant: 8),
            refreshButton.widthAnchor.constraint(equalToConstant: 44),
            refreshButton.heightAnchor.constraint(equalToConstant: 44),
            
            shareButton.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),
            shareButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            shareButton.widthAnchor.constraint(equalToConstant: 44),
            shareButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Progress View
            progressView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 4),
            progressView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 2),
            
            // WebView
            webView.topAnchor.constraint(equalTo: progressView.bottomAnchor, constant: 4),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Dev Tools FAB
            devToolsFAB.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            devToolsFAB.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            devToolsFAB.widthAnchor.constraint(equalToConstant: 56),
            devToolsFAB.heightAnchor.constraint(equalToConstant: 56)
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
    @objc private func goButtonTapped() {
        guard let urlString = urlTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !urlString.isEmpty else { return }
        
        loadURL(urlString)
    }
    
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
        
        // Handle iPad presentation
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = shareButton
            popover.sourceRect = shareButton.bounds
        }
        
        present(activityViewController, animated: true)
    }
    
    @objc private func securityIndicatorTapped() {
        guard let url = webView.url else { return }
        
        let isSecure = url.scheme == "https"
        let title = isSecure ? "🔒 Secure Connection" : "⚠️ Not Secure"
        let message = isSecure ? 
            "Your connection to this site is encrypted and secure." :
            "Your connection to this site is not secure. Avoid entering sensitive information."
        
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        present(alert, animated: true)
    }
    
    @objc private func showDevTools() {
        if devToolsViewController == nil {
            devToolsViewController = DevToolsViewController()
            devToolsViewController?.delegate = self
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
        backButton.isEnabled = webView.canGoBack
        forwardButton.isEnabled = webView.canGoForward
        
        // Update button appearance based on state
        backButton.alpha = webView.canGoBack ? 1.0 : 0.5
        forwardButton.alpha = webView.canGoForward ? 1.0 : 0.5
    }
    
    private func updateSecurityIndicator(for url: URL?) {
        guard let url = url else {
            securityIndicator.setImage(UIImage(systemName: "globe"), for: .normal)
            securityIndicator.tintColor = UIColor.systemGray
            urlContainerView.layer.borderColor = UIColor.systemGray4.cgColor
            return
        }
        
        let isSecure = url.scheme == "https"
        
        if isSecure {
            securityIndicator.setImage(UIImage(systemName: "lock.fill"), for: .normal)
            securityIndicator.tintColor = UIColor.systemGreen
            urlContainerView.layer.borderColor = UIColor.systemGreen.withAlphaComponent(0.3).cgColor
        } else {
            securityIndicator.setImage(UIImage(systemName: "exclamationmark.triangle.fill"), for: .normal)
            securityIndicator.tintColor = UIColor.systemOrange
            urlContainerView.layer.borderColor = UIColor.systemOrange.withAlphaComponent(0.3).cgColor
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
        }
    }
}

// MARK: - UITextFieldDelegate
extension BrowserViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        goButtonTapped()
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