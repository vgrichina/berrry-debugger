import UIKit
import WebKit

protocol DevToolsViewControllerDelegate: AnyObject {
    func devToolsDidRequestDOMExtraction(for selector: String, completion: @escaping (String?) -> Void)
    func devToolsDidRequestCSSExtraction(for selector: String, completion: @escaping (String?) -> Void)
}

class DevToolsViewController: UIViewController {
    
    weak var delegate: DevToolsViewControllerDelegate?
    
    // MARK: - UI Components
    private let tabBar = UITabBar()
    private let contentContainer = UIView()
    private let copyButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    
    // Tab Content Views
    private let elementsTextView = UITextView()
    private let consoleTableView = UITableView()
    private let networkTableView = UITableView()
    
    // Data
    private var consoleLogs: [String] = []
    private var networkRequests: [NetworkRequest] = []
    private var currentWebView: WKWebView?
    private var selectedElementSelector: String = ""
    
    private enum Tab: Int, CaseIterable {
        case elements = 0
        case console = 1
        case network = 2
        
        var title: String {
            switch self {
            case .elements: return "Elements"
            case .console: return "Console"
            case .network: return "Network"
            }
        }
        
        var imageName: String {
            switch self {
            case .elements: return "doc.text"
            case .console: return "terminal"
            case .network: return "network"
            }
        }
    }
    
    private var currentTab: Tab = .elements
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupTabBar()
        showTab(.elements)
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // Close Button
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        
        // Tab Bar
        tabBar.backgroundColor = UIColor.systemGray6
        tabBar.delegate = self
        tabBar.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tabBar)
        
        // Copy Button
        copyButton.setTitle("Copy for LLM", for: .normal)
        copyButton.backgroundColor = UIColor.systemBlue
        copyButton.setTitleColor(.white, for: .normal)
        copyButton.layer.cornerRadius = 8
        copyButton.addTarget(self, action: #selector(copyButtonTapped), for: .touchUpInside)
        copyButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(copyButton)
        
        // Content Container
        contentContainer.backgroundColor = UIColor.systemBackground
        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(contentContainer)
        
        setupTabContent()
    }
    
    private func setupTabContent() {
        // Elements Text View
        elementsTextView.isEditable = false
        elementsTextView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        elementsTextView.backgroundColor = UIColor.systemGray6
        elementsTextView.translatesAutoresizingMaskIntoConstraints = false
        
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(elementsTextViewTapped(_:)))
        elementsTextView.addGestureRecognizer(tapGesture)
        
        // Console Table View
        consoleTableView.delegate = self
        consoleTableView.dataSource = self
        consoleTableView.register(UITableViewCell.self, forCellReuseIdentifier: "ConsoleCell")
        consoleTableView.translatesAutoresizingMaskIntoConstraints = false
        
        // Network Table View
        networkTableView.delegate = self
        networkTableView.dataSource = self
        networkTableView.register(UITableViewCell.self, forCellReuseIdentifier: "NetworkCell")
        networkTableView.translatesAutoresizingMaskIntoConstraints = false
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Close Button
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            closeButton.widthAnchor.constraint(equalToConstant: 30),
            closeButton.heightAnchor.constraint(equalToConstant: 30),
            
            // Tab Bar
            tabBar.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 10),
            tabBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tabBar.heightAnchor.constraint(equalToConstant: 49),
            
            // Copy Button
            copyButton.topAnchor.constraint(equalTo: tabBar.bottomAnchor, constant: 10),
            copyButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            copyButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            copyButton.heightAnchor.constraint(equalToConstant: 44),
            
            // Content Container
            contentContainer.topAnchor.constraint(equalTo: copyButton.bottomAnchor, constant: 10),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupTabBar() {
        var tabBarItems: [UITabBarItem] = []
        
        for tab in Tab.allCases {
            let item = UITabBarItem(
                title: tab.title,
                image: UIImage(systemName: tab.imageName),
                tag: tab.rawValue
            )
            tabBarItems.append(item)
        }
        
        tabBar.setItems(tabBarItems, animated: false)
        tabBar.selectedItem = tabBarItems[0]
    }
    
    // MARK: - Tab Management
    private func showTab(_ tab: Tab) {
        currentTab = tab
        
        // Remove all subviews from container
        contentContainer.subviews.forEach { $0.removeFromSuperview() }
        
        let contentView: UIView
        
        switch tab {
        case .elements:
            contentView = elementsTextView
            loadDOMContent()
        case .console:
            contentView = consoleTableView
            consoleTableView.reloadData()
        case .network:
            contentView = networkTableView
            networkTableView.reloadData()
        }
        
        contentContainer.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
    }
    
    private func loadDOMContent() {
        delegate?.devToolsDidRequestDOMExtraction(for: "") { [weak self] html in
            DispatchQueue.main.async {
                self?.elementsTextView.text = html ?? "Failed to load DOM"
            }
        }
    }
    
    // MARK: - Actions
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func copyButtonTapped() {
        let contextCopyController = ContextCopyController()
        contextCopyController.delegate = self
        contextCopyController.showContextCopyOptions(from: self)
    }
    
    @objc private func elementsTextViewTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: elementsTextView)
        let position = elementsTextView.closestPosition(to: location)
        
        if let position = position {
            let offset = elementsTextView.offset(from: elementsTextView.beginningOfDocument, to: position)
            
            // Simple element selection logic - find the nearest HTML tag
            let text = elementsTextView.text ?? ""
            let index = text.index(text.startIndex, offsetBy: min(offset, text.count - 1))
            
            // Find the nearest opening tag
            var startIndex = index
            while startIndex > text.startIndex && text[startIndex] != "<" {
                startIndex = text.index(before: startIndex)
            }
            
            var endIndex = startIndex
            while endIndex < text.endIndex && text[endIndex] != ">" {
                endIndex = text.index(after: endIndex)
            }
            
            if startIndex < endIndex {
                let tagContent = String(text[startIndex...endIndex])
                
                // Extract tag name and create selector
                if let tagName = extractTagName(from: tagContent) {
                    selectedElementSelector = tagName
                    
                    // Highlight selection (simple approach)
                    let attributedText = NSMutableAttributedString(string: text)
                    let range = NSRange(startIndex..<text.index(after: endIndex), in: text)
                    attributedText.addAttribute(.backgroundColor, value: UIColor.systemYellow, range: range)
                    elementsTextView.attributedText = attributedText
                }
            }
        }
    }
    
    private func extractTagName(from tag: String) -> String? {
        let components = tag.dropFirst().dropLast().components(separatedBy: " ")
        return components.first?.lowercased()
    }
    
    // MARK: - Public Methods
    func updateData(consoleLogs: [String], networkRequests: [NetworkRequest], webView: WKWebView) {
        self.consoleLogs = consoleLogs
        self.networkRequests = networkRequests
        self.currentWebView = webView
        
        // Reload current tab
        showTab(currentTab)
    }
}

// MARK: - UITabBarDelegate
extension DevToolsViewController: UITabBarDelegate {
    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        if let tab = Tab(rawValue: item.tag) {
            showTab(tab)
        }
    }
}

// MARK: - UITableViewDataSource & UITableViewDelegate
extension DevToolsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == consoleTableView {
            return consoleLogs.count
        } else if tableView == networkTableView {
            return networkRequests.count
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == consoleTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ConsoleCell", for: indexPath)
            cell.textLabel?.text = consoleLogs[indexPath.row]
            cell.textLabel?.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            cell.textLabel?.numberOfLines = 0
            return cell
        } else if tableView == networkTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "NetworkCell", for: indexPath)
            let request = networkRequests[indexPath.row]
            cell.textLabel?.text = "\(request.method) \(request.url)"
            cell.detailTextLabel?.text = "Status: \(request.status)"
            cell.textLabel?.font = UIFont.systemFont(ofSize: 14)
            cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 12)
            return cell
        }
        return UITableViewCell()
    }
}

// MARK: - ContextCopyControllerDelegate
extension DevToolsViewController: ContextCopyControllerDelegate {
    func contextCopyController(_ controller: ContextCopyController, didRequestDOMExtraction completion: @escaping (String?) -> Void) {
        delegate?.devToolsDidRequestDOMExtraction(for: selectedElementSelector.isEmpty ? "" : selectedElementSelector, completion: completion)
    }
    
    func contextCopyController(_ controller: ContextCopyController, didRequestCSSExtraction completion: @escaping (String?) -> Void) {
        delegate?.devToolsDidRequestCSSExtraction(for: selectedElementSelector.isEmpty ? "body" : selectedElementSelector, completion: completion)
    }
    
    func contextCopyControllerDidRequestConsoleLogs(_ controller: ContextCopyController) -> [String] {
        return consoleLogs
    }
    
    func contextCopyControllerDidRequestNetworkLogs(_ controller: ContextCopyController) -> [NetworkRequest] {
        return networkRequests
    }
}