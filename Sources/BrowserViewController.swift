import UIKit
import WebKit

class BrowserViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    
    // MARK: - UI Components
    private let urlTextField = UITextField()
    private let goButton = UIButton(type: .system)
    private let backButton = UIButton(type: .system)
    private let forwardButton = UIButton(type: .system)
    private let refreshButton = UIButton(type: .system)
    private var webView: WKWebView!
    private let devToolsFAB = UIButton(type: .system)
    
    // MARK: - Dev Tools
    private var devToolsViewController: DevToolsViewController?
    private var consoleLogs: [String] = []
    private var networkRequests: [NetworkRequest] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupWebView()
        setupUI()
        setupConstraints()
        loadDefaultPage()
    }
    
    // MARK: - WebView Setup
    private func setupWebView() {
        let config = WKWebViewConfiguration()
        
        // Add console message handler
        config.userContentController.add(self, name: "console")
        
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
        
        // URL Text Field
        urlTextField.borderStyle = .roundedRect
        urlTextField.placeholder = "https://example.com"
        urlTextField.keyboardType = .URL
        urlTextField.autocapitalizationType = .none
        urlTextField.autocorrectionType = .no
        urlTextField.delegate = self
        urlTextField.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(urlTextField)
        
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
        
        // Dev Tools FAB
        devToolsFAB.setImage(UIImage(systemName: "plus.circle.fill"), for: .normal)
        devToolsFAB.backgroundColor = UIColor.systemBlue
        devToolsFAB.tintColor = .white
        devToolsFAB.layer.cornerRadius = 25
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
    }
    
    // MARK: - Layout
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // URL Bar
            urlTextField.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            urlTextField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            urlTextField.trailingAnchor.constraint(equalTo: goButton.leadingAnchor, constant: -8),
            urlTextField.heightAnchor.constraint(equalToConstant: 44),
            
            // Go Button
            goButton.centerYAnchor.constraint(equalTo: urlTextField.centerYAnchor),
            goButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            goButton.widthAnchor.constraint(equalToConstant: 60),
            goButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Navigation Buttons
            backButton.topAnchor.constraint(equalTo: urlTextField.bottomAnchor, constant: 8),
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
            
            // WebView
            webView.topAnchor.constraint(equalTo: backButton.bottomAnchor, constant: 8),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Dev Tools FAB
            devToolsFAB.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            devToolsFAB.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            devToolsFAB.widthAnchor.constraint(equalToConstant: 50),
            devToolsFAB.heightAnchor.constraint(equalToConstant: 50)
        ])
    }
    
    // MARK: - Actions
    @objc private func goButtonTapped() {
        guard let urlString = urlTextField.text?.trimmingCharacters(in: .whitespacesAndNewlines),
              !urlString.isEmpty else { return }
        
        let finalURLString: String
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            finalURLString = urlString
        } else {
            finalURLString = "https://" + urlString
        }
        
        guard let url = URL(string: finalURLString) else { return }
        let request = URLRequest(url: url)
        webView.load(request)
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
        guard let url = URL(string: "https://example.com") else { return }
        let request = URLRequest(url: url)
        webView.load(request)
        urlTextField.text = "https://example.com"
    }
    
    // MARK: - WKNavigationDelegate
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        urlTextField.text = webView.url?.absoluteString
        
        // Update navigation button states
        backButton.isEnabled = webView.canGoBack
        forwardButton.isEnabled = webView.canGoForward
        
        // Update button appearance based on state
        backButton.alpha = webView.canGoBack ? 1.0 : 0.5
        forwardButton.alpha = webView.canGoForward ? 1.0 : 0.5
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Only allow HTTPS
        if let url = navigationAction.request.url,
           url.scheme == "http" {
            // Convert to HTTPS
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.scheme = "https"
            if let httpsURL = components?.url {
                let httpsRequest = URLRequest(url: httpsURL)
                webView.load(httpsRequest)
            }
            decisionHandler(.cancel)
            return
        }
        
        // Track network request
        if let url = navigationAction.request.url {
            let networkRequest = NetworkRequest(
                url: url.absoluteString,
                method: navigationAction.request.httpMethod ?? "GET",
                status: 0, // Will be updated when response is received
                headers: navigationAction.request.allHTTPHeaderFields ?? [:]
            )
            networkRequests.append(networkRequest)
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