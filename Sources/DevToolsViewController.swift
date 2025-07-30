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
    private let elementsTableView = UITableView()
    private let elementsSearchBar = UISearchBar()
    private let elementSelectButton = UIButton(type: .system)
    private let elementDetailsView = UIView()
    private let elementDetailsLabel = UILabel()
    private let consoleTableView = UITableView()
    private let networkTableView = UITableView()
    private let networkSearchBar = UISearchBar()
    private let networkClearButton = UIButton(type: .system)
    
    // Data
    private var consoleLogs: [String] = []
    private var networkRequests: [NetworkRequestModel] = []
    private var filteredNetworkRequests: [NetworkRequestModel] = []
    private var expandedNetworkRequests: Set<UUID> = []
    private var currentWebView: WKWebView?
    private var selectedElementSelector: String = ""
    private var domTreeRoot: DOMNode?
    private var flattenedDOMNodes: [DOMNode] = []
    private var filteredDOMNodes: [DOMNode] = []
    private var selectedDOMNode: DOMNode?
    private var searchText: String = ""
    private var networkSearchText: String = ""
    
    // DOM Inspector
    private let domInspector = DOMInspector()
    private var isElementSelectionMode = false
    weak var browserViewController: BrowserViewController?
    
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
        // Elements Search Bar
        elementsSearchBar.placeholder = "Search elements..."
        elementsSearchBar.delegate = self
        elementsSearchBar.searchBarStyle = .minimal
        elementsSearchBar.translatesAutoresizingMaskIntoConstraints = false
        
        // Elements Table View
        elementsTableView.delegate = self
        elementsTableView.dataSource = self
        elementsTableView.register(DOMTreeTableViewCell.self, forCellReuseIdentifier: DOMTreeTableViewCell.identifier)
        elementsTableView.separatorStyle = .none
        elementsTableView.backgroundColor = UIColor.systemBackground
        elementsTableView.translatesAutoresizingMaskIntoConstraints = false
        
        // Console Table View
        consoleTableView.delegate = self
        consoleTableView.dataSource = self
        consoleTableView.register(UITableViewCell.self, forCellReuseIdentifier: "ConsoleCell")
        consoleTableView.translatesAutoresizingMaskIntoConstraints = false
        
        // Network Search Bar
        networkSearchBar.placeholder = "Filter network requests..."
        networkSearchBar.delegate = self
        networkSearchBar.searchBarStyle = .minimal
        networkSearchBar.translatesAutoresizingMaskIntoConstraints = false
        
        // Network Table View
        networkTableView.delegate = self
        networkTableView.dataSource = self
        networkTableView.register(NetworkRequestTableViewCell.self, forCellReuseIdentifier: NetworkRequestTableViewCell.identifier)
        networkTableView.separatorStyle = .none
        networkTableView.translatesAutoresizingMaskIntoConstraints = false
        
        // Clear button
        networkClearButton.setTitle("🗑️ Clear", for: .normal)
        networkClearButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        networkClearButton.setTitleColor(UIColor.systemRed, for: .normal)
        networkClearButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
        networkClearButton.layer.cornerRadius = 8
        networkClearButton.addTarget(self, action: #selector(clearNetworkRequests), for: .touchUpInside)
        networkClearButton.translatesAutoresizingMaskIntoConstraints = false
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
            item.accessibilityIdentifier = tab.title
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
            setupElementsTabLayout()
            return // Special handling for elements tab
        case .console:
            contentView = consoleTableView
            consoleTableView.reloadData()
        case .network:
            setupNetworkTabLayout()
            return // Special handling for network tab
        }
        
        contentContainer.addSubview(contentView)
        
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
    }
    
    private func setupElementsTabLayout() {
        // Setup element selection button
        elementSelectButton.setTitle("Select Element", for: .normal)
        elementSelectButton.setTitle("Cancel Selection", for: .selected)
        elementSelectButton.backgroundColor = UIColor.systemBlue
        elementSelectButton.setTitleColor(.white, for: .normal)
        elementSelectButton.layer.cornerRadius = 8
        elementSelectButton.addTarget(self, action: #selector(elementSelectButtonTapped), for: .touchUpInside)
        elementSelectButton.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(elementSelectButton)
        
        // Setup search bar
        elementsSearchBar.delegate = self
        elementsSearchBar.placeholder = "Search elements..."
        elementsSearchBar.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(elementsSearchBar)
        
        // Setup elements table view
        elementsTableView.delegate = self
        elementsTableView.dataSource = self
        elementsTableView.register(DOMTreeTableViewCell.self, forCellReuseIdentifier: "DOMCell")
        elementsTableView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(elementsTableView)
        
        // Setup element details view
        elementDetailsView.backgroundColor = UIColor.systemGray6
        elementDetailsView.layer.cornerRadius = 8
        elementDetailsView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(elementDetailsView)
        
        elementDetailsLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        elementDetailsLabel.numberOfLines = 0
        elementDetailsLabel.text = "No element selected"
        elementDetailsLabel.translatesAutoresizingMaskIntoConstraints = false
        elementDetailsView.addSubview(elementDetailsLabel)
        
        // Trigger DOM content loading when Elements tab is shown
        loadDOMContent()
        
        NSLayoutConstraint.activate([
            // Element select button
            elementSelectButton.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 8),
            elementSelectButton.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 16),
            elementSelectButton.widthAnchor.constraint(equalToConstant: 140),
            elementSelectButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Search bar
            elementsSearchBar.topAnchor.constraint(equalTo: elementSelectButton.bottomAnchor, constant: 8),
            elementsSearchBar.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            elementsSearchBar.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            elementsSearchBar.heightAnchor.constraint(equalToConstant: 44),
            
            // Elements table view (takes 60% of remaining space)
            elementsTableView.topAnchor.constraint(equalTo: elementsSearchBar.bottomAnchor),
            elementsTableView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            elementsTableView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            elementsTableView.heightAnchor.constraint(equalTo: contentContainer.heightAnchor, multiplier: 0.4),
            
            // Element details view (takes remaining space)
            elementDetailsView.topAnchor.constraint(equalTo: elementsTableView.bottomAnchor, constant: 8),
            elementDetailsView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor, constant: 8),
            elementDetailsView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -8),
            elementDetailsView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: -8),
            
            // Element details label
            elementDetailsLabel.topAnchor.constraint(equalTo: elementDetailsView.topAnchor, constant: 8),
            elementDetailsLabel.leadingAnchor.constraint(equalTo: elementDetailsView.leadingAnchor, constant: 8),
            elementDetailsLabel.trailingAnchor.constraint(equalTo: elementDetailsView.trailingAnchor, constant: -8),
            elementDetailsLabel.bottomAnchor.constraint(equalTo: elementDetailsView.bottomAnchor, constant: -8)
        ])
    }
    
    private func loadDOMContent() {
        delegate?.devToolsDidRequestDOMExtraction(for: "") { [weak self] html in
            DispatchQueue.main.async {
                guard let self = self, let html = html else { return }
                
                // Parse HTML into DOM tree
                self.domTreeRoot = DOMParser.parseHTML(html)
                self.updateDOMDisplay()
            }
        }
    }
    
    private func updateDOMDisplay() {
        guard let root = domTreeRoot else {
            flattenedDOMNodes = []
            elementsTableView.reloadData()
            return
        }
        
        flattenedDOMNodes = root.flattenedNodes()
        
        // Apply search filter if needed
        if searchText.isEmpty {
            filteredDOMNodes = flattenedDOMNodes
        } else {
            filteredDOMNodes = flattenedDOMNodes.filter { node in
                node.displayName.lowercased().contains(searchText.lowercased()) ||
                node.tagName.lowercased().contains(searchText.lowercased())
            }
        }
        
        elementsTableView.reloadData()
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
    
    private func selectDOMNode(_ node: DOMNode) {
        selectedDOMNode = node
        selectedElementSelector = node.selector
        elementsTableView.reloadData()
    }
    
    private func expandCollapseDOMNode(_ node: DOMNode) {
        node.toggleExpanded()
        updateDOMDisplay()
    }
    
    
    private func setupNetworkTabLayout() {
        contentContainer.addSubview(networkSearchBar)
        contentContainer.addSubview(networkClearButton)
        contentContainer.addSubview(networkTableView)
        
        NSLayoutConstraint.activate([
            // Search bar
            networkSearchBar.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            networkSearchBar.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            networkSearchBar.trailingAnchor.constraint(equalTo: networkClearButton.leadingAnchor, constant: -8),
            networkSearchBar.heightAnchor.constraint(equalToConstant: 44),
            
            // Clear button
            networkClearButton.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 6),
            networkClearButton.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -20),
            networkClearButton.widthAnchor.constraint(equalToConstant: 80),
            networkClearButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Network table view
            networkTableView.topAnchor.constraint(equalTo: networkSearchBar.bottomAnchor),
            networkTableView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            networkTableView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            networkTableView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
        
        updateNetworkDisplay()
    }
    
    
    @objc private func clearNetworkRequests() {
        networkRequests.removeAll()
        expandedNetworkRequests.removeAll()
        updateNetworkDisplay()
    }
    
    private func updateNetworkDisplay() {
        if networkSearchText.isEmpty {
            filteredNetworkRequests = networkRequests
        } else {
            filteredNetworkRequests = networkRequests.filter { request in
                request.url.lowercased().contains(networkSearchText.lowercased()) ||
                request.method.lowercased().contains(networkSearchText.lowercased()) ||
                String(request.status).contains(networkSearchText)
            }
        }
        networkTableView.reloadData()
    }
    
    private func updateConsoleDisplay() {
        consoleTableView.reloadData()
    }
    
    private func toggleNetworkRequestExpansion(_ request: NetworkRequestModel) {
        if expandedNetworkRequests.contains(request.id) {
            expandedNetworkRequests.remove(request.id)
        } else {
            expandedNetworkRequests.insert(request.id)
        }
        networkTableView.reloadData()
    }
    
    // MARK: - Public Methods
    func updateData(consoleLogs: [String], networkRequests: [NetworkRequestModel], webView: WKWebView) {
        self.consoleLogs = consoleLogs
        self.networkRequests = networkRequests
        self.currentWebView = webView
        
        // Update current tab data without rebuilding UI
        switch currentTab {
        case .network:
            updateNetworkDisplay()
        case .console:
            updateConsoleDisplay()
        case .elements:
            // Elements tab - trigger DOM refresh and reload table
            loadDOMContent()
            elementsTableView.reloadData()
        }
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
        if tableView == elementsTableView {
            return filteredDOMNodes.count
        } else if tableView == consoleTableView {
            return consoleLogs.count
        } else if tableView == networkTableView {
            return filteredNetworkRequests.count
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == elementsTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: DOMTreeTableViewCell.identifier, for: indexPath) as! DOMTreeTableViewCell
            let node = filteredDOMNodes[indexPath.row]
            let isSelected = node === selectedDOMNode
            
            cell.configure(with: node, isSelected: isSelected) { [weak self] node in
                self?.expandCollapseDOMNode(node)
            }
            
            return cell
        } else if tableView == consoleTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "ConsoleCell", for: indexPath)
            cell.textLabel?.text = consoleLogs[indexPath.row]
            cell.textLabel?.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
            cell.textLabel?.numberOfLines = 0
            return cell
        } else if tableView == networkTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: NetworkRequestTableViewCell.identifier, for: indexPath) as! NetworkRequestTableViewCell
            let request = filteredNetworkRequests[indexPath.row]
            let isExpanded = expandedNetworkRequests.contains(request.id)
            
            cell.configure(with: request, isExpanded: isExpanded) { [weak self] request in
                self?.toggleNetworkRequestExpansion(request)
            }
            
            return cell
        }
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if tableView == elementsTableView {
            let node = filteredDOMNodes[indexPath.row]
            selectDOMNode(node)
        }
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
    
    func contextCopyControllerDidRequestNetworkLogs(_ controller: ContextCopyController) -> [NetworkRequestModel] {
        return networkRequests
    }
}

// MARK: - UISearchBarDelegate
extension DevToolsViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if searchBar == elementsSearchBar {
            self.searchText = searchText
            updateDOMDisplay()
        } else if searchBar == networkSearchBar {
            self.networkSearchText = searchText
            updateNetworkDisplay()
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        
        if searchBar == elementsSearchBar {
            self.searchText = ""
            updateDOMDisplay()
        } else if searchBar == networkSearchBar {
            self.networkSearchText = ""
            updateNetworkDisplay()
        }
    }
}

// MARK: - DOM Inspector Methods
extension DevToolsViewController {
    
    @objc private func elementSelectButtonTapped() {
        isElementSelectionMode.toggle()
        elementSelectButton.isSelected = isElementSelectionMode
        
        if isElementSelectionMode {
            browserViewController?.enableElementSelection()
        } else {
            browserViewController?.disableElementSelection()
        }
    }
    
    func updateDOMTree(_ treeData: [String: Any]) {
        domInspector.updateDOMTree(treeData)
        refreshElementsList()
    }
    
    func updateSelectedElement(_ elementData: [String: Any]) {
        domInspector.updateSelectedElement(elementData)
        
        if let selectedElement = domInspector.getSelectedElement() {
            updateElementDetails(selectedElement)
            
            // Disable selection mode after selection
            isElementSelectionMode = false
            elementSelectButton.isSelected = false
        }
    }
    
    private func refreshElementsList() {
        let allElements = domInspector.getFlattenedElements()
        
        // Apply search filter
        let filteredElements = searchText.isEmpty ? 
            allElements : 
            domInspector.searchElements(query: searchText)
        
        // Update table view on main thread
        Task { @MainActor in
            // Convert DOMElement to DOMNode for compatibility with existing table view
            self.flattenedDOMNodes = filteredElements.map { element in
                let node = DOMNode(
                    tagName: element.tagName,
                    attributes: element.attributes,
                    textContent: element.textContent
                )
                node.depth = element.depth
                return node
            }
            self.elementsTableView.reloadData()
        }
    }
    
    private func updateElementDetails(_ element: DOMElement) {
        let details = """
        Element: \(element.tagName)
        Selector: \(element.selector)
        
        Dimensions:
        Size: \(element.dimensions.width) × \(element.dimensions.height)
        Position: (\(element.dimensions.left), \(element.dimensions.top))
        
        Styles:
        Display: \(element.styles.display)
        Position: \(element.styles.position)
        Color: \(element.styles.color)
        Background: \(element.styles.backgroundColor)
        Font: \(element.styles.fontSize) \(element.styles.fontFamily)
        
        Attributes:
        \(element.attributes.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))
        
        Text Content:
        \(element.textContent?.prefix(200) ?? "None")
        """
        
        Task { @MainActor in
            self.elementDetailsLabel.text = details
        }
    }
    
    // Enhanced copy functionality for DOM inspector context
    func copyDOMInspectorContext() {
        var contextToExport = ""
        
        switch currentTab {
        case .elements:
            if let selectedElement = domInspector.getSelectedElement() {
                contextToExport = domInspector.generateBugReportContext(
                    selectedElement: selectedElement,
                    consoleLogs: consoleLogs,
                    networkRequests: networkRequests,
                    currentURL: currentWebView?.url?.absoluteString ?? ""
                )
            } else {
                contextToExport = domInspector.generatePerformanceContext(element: nil)
            }
        case .console:
            contextToExport = """
            # Console Logs Context
            
            ## Recent Console Output
            \(consoleLogs.suffix(20).joined(separator: "\n"))
            
            ## LLM Debugging Prompt
            Analyze these console logs for errors, warnings, and debugging information.
            """
        case .network:
            let failedRequests = networkRequests.filter { $0.status >= 400 || $0.status == 0 }
            contextToExport = """
            # Network Analysis Context
            
            ## Total Requests: \(networkRequests.count)
            ## Failed Requests: \(failedRequests.count)
            
            ### Failed Request Details:
            \(failedRequests.prefix(5).map { "- \($0.method) \($0.url) (\($0.status))" }.joined(separator: "\n"))
            
            ### Recent Successful Requests:
            \(networkRequests.filter { $0.status >= 200 && $0.status < 400 }.suffix(5).map { "- \($0.method) \($0.url) (\($0.status))" }.joined(separator: "\n"))
            
            ## LLM Analysis Prompt
            Review these network requests and identify potential issues or optimization opportunities.
            """
        }
        
        UIPasteboard.general.string = contextToExport
        
        // Show feedback
        let alert = UIAlertController(title: "Copied!", message: "Context copied to clipboard for LLM analysis", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - Public API for BrowserViewController
extension DevToolsViewController {
    
    func setBrowserViewController(_ browser: BrowserViewController) {
        self.browserViewController = browser
    }
}