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
    private let consoleTableView = UITableView()
    private let networkTableView = UITableView()
    private let networkFilterScrollView = UIScrollView()
    private let networkFilterStackView = UIStackView()
    private let networkClearButton = UIButton(type: .system)
    
    // Data
    private var consoleLogs: [String] = []
    private var networkRequests: [NetworkRequestModel] = []
    private var filteredNetworkRequests: [NetworkRequestModel] = []
    private var expandedNetworkRequests: Set<UUID> = []
    private var selectedNetworkFilter: NetworkResourceType = .all
    private var currentWebView: WKWebView?
    private var selectedElementSelector: String = ""
    private var domTreeRoot: DOMNode?
    private var flattenedDOMNodes: [DOMNode] = []
    private var filteredDOMNodes: [DOMNode] = []
    private var selectedDOMNode: DOMNode?
    private var searchText: String = ""
    
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
        
        // Network Table View
        networkTableView.delegate = self
        networkTableView.dataSource = self
        networkTableView.register(NetworkRequestTableViewCell.self, forCellReuseIdentifier: NetworkRequestTableViewCell.identifier)
        networkTableView.separatorStyle = .none
        networkTableView.translatesAutoresizingMaskIntoConstraints = false
        
        // Network Filter Components
        setupNetworkFilterComponents()
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
        contentContainer.addSubview(elementsSearchBar)
        contentContainer.addSubview(elementsTableView)
        
        NSLayoutConstraint.activate([
            // Search bar
            elementsSearchBar.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            elementsSearchBar.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            elementsSearchBar.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            elementsSearchBar.heightAnchor.constraint(equalToConstant: 44),
            
            // Table view
            elementsTableView.topAnchor.constraint(equalTo: elementsSearchBar.bottomAnchor),
            elementsTableView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            elementsTableView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            elementsTableView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
        
        loadDOMContent()
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
    
    private func setupNetworkFilterComponents() {
        // Filter scroll view
        networkFilterScrollView.showsHorizontalScrollIndicator = false
        networkFilterScrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // Filter stack view
        networkFilterStackView.axis = .horizontal
        networkFilterStackView.spacing = 8
        networkFilterStackView.distribution = .fill
        networkFilterStackView.translatesAutoresizingMaskIntoConstraints = false
        networkFilterScrollView.addSubview(networkFilterStackView)
        
        // Create filter buttons
        for resourceType in NetworkResourceType.allCases {
            let button = createFilterButton(for: resourceType)
            networkFilterStackView.addArrangedSubview(button)
        }
        
        // Clear button
        networkClearButton.setTitle("🗑️ Clear", for: .normal)
        networkClearButton.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        networkClearButton.setTitleColor(UIColor.systemRed, for: .normal)
        networkClearButton.backgroundColor = UIColor.systemRed.withAlphaComponent(0.1)
        networkClearButton.layer.cornerRadius = 6
        networkClearButton.addTarget(self, action: #selector(clearNetworkRequests), for: .touchUpInside)
        networkClearButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Constraints for filter scroll view content
        NSLayoutConstraint.activate([
            networkFilterStackView.topAnchor.constraint(equalTo: networkFilterScrollView.topAnchor),
            networkFilterStackView.leadingAnchor.constraint(equalTo: networkFilterScrollView.leadingAnchor, constant: 12),
            networkFilterStackView.trailingAnchor.constraint(equalTo: networkFilterScrollView.trailingAnchor, constant: -12),
            networkFilterStackView.bottomAnchor.constraint(equalTo: networkFilterScrollView.bottomAnchor),
            networkFilterStackView.heightAnchor.constraint(equalTo: networkFilterScrollView.heightAnchor)
        ])
    }
    
    private func createFilterButton(for resourceType: NetworkResourceType) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle("\\(resourceType.emoji) \\(resourceType.rawValue)", for: .normal)
        button.titleLabel?.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        button.backgroundColor = resourceType == .all ? UIColor.systemBlue.withAlphaComponent(0.2) : UIColor.systemGray6
        button.setTitleColor(resourceType == .all ? UIColor.systemBlue : UIColor.label, for: .normal)
        button.layer.cornerRadius = 6
        button.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        button.tag = NetworkResourceType.allCases.firstIndex(of: resourceType) ?? 0
        button.addTarget(self, action: #selector(networkFilterButtonTapped(_:)), for: .touchUpInside)
        return button
    }
    
    private func setupNetworkTabLayout() {
        contentContainer.addSubview(networkFilterScrollView)
        contentContainer.addSubview(networkClearButton)
        contentContainer.addSubview(networkTableView)
        
        NSLayoutConstraint.activate([
            // Filter scroll view
            networkFilterScrollView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            networkFilterScrollView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            networkFilterScrollView.trailingAnchor.constraint(equalTo: networkClearButton.leadingAnchor, constant: -8),
            networkFilterScrollView.heightAnchor.constraint(equalToConstant: 40),
            
            // Clear button
            networkClearButton.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 4),
            networkClearButton.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor, constant: -12),
            networkClearButton.widthAnchor.constraint(equalToConstant: 70),
            networkClearButton.heightAnchor.constraint(equalToConstant: 32),
            
            // Network table view
            networkTableView.topAnchor.constraint(equalTo: networkFilterScrollView.bottomAnchor, constant: 8),
            networkTableView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            networkTableView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            networkTableView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
        ])
        
        updateNetworkDisplay()
    }
    
    private func updateNetworkDisplay() {
        // Apply filter
        if selectedNetworkFilter == .all {
            filteredNetworkRequests = networkRequests
        } else {
            filteredNetworkRequests = networkRequests.filter { $0.resourceType == selectedNetworkFilter }
        }
        
        networkTableView.reloadData()
        updateFilterButtonStates()
    }
    
    private func updateFilterButtonStates() {
        for (index, resourceType) in NetworkResourceType.allCases.enumerated() {
            if let button = networkFilterStackView.arrangedSubviews[index] as? UIButton {
                let isSelected = resourceType == selectedNetworkFilter
                button.backgroundColor = isSelected ? UIColor.systemBlue.withAlphaComponent(0.2) : UIColor.systemGray6
                button.setTitleColor(isSelected ? UIColor.systemBlue : UIColor.label, for: .normal)
            }
        }
    }
    
    @objc private func networkFilterButtonTapped(_ sender: UIButton) {
        let resourceType = NetworkResourceType.allCases[sender.tag]
        selectedNetworkFilter = resourceType
        updateNetworkDisplay()
    }
    
    @objc private func clearNetworkRequests() {
        networkRequests.removeAll()
        filteredNetworkRequests.removeAll()
        expandedNetworkRequests.removeAll()
        networkTableView.reloadData()
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
        
        // Update network display if on network tab
        if currentTab == .network {
            updateNetworkDisplay()
        }
        
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
        self.searchText = searchText
        updateDOMDisplay()
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.resignFirstResponder()
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.text = ""
        searchBar.resignFirstResponder()
        self.searchText = ""
        updateDOMDisplay()
    }
}