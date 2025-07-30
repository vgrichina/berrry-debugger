import UIKit
import WebKit

protocol DevToolsViewControllerDelegate: AnyObject {
    func devToolsDidRequestDOMExtraction(for selector: String, completion: @escaping (String?) -> Void)
    func devToolsDidRequestCSSExtraction(for selector: String, completion: @escaping (String?) -> Void)
}

class DevToolsViewController: UIViewController {
    
    weak var delegate: DevToolsViewControllerDelegate?
    
    // MARK: - UI Components
    private let segmentedControl = UISegmentedControl(items: ["Elements", "Console", "Network", "Context"])
    private let contentContainer = UIView()
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
    private var contextTextView: UITextView?
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
        case context = 3
        
        var title: String {
            switch self {
            case .elements: return "Elements"
            case .console: return "Console"
            case .network: return "Network"
            case .context: return "Context"
            }
        }
        
        var imageName: String {
            switch self {
            case .elements: return "doc.text"
            case .console: return "terminal"
            case .network: return "network"
            case .context: return "doc.on.clipboard"
            }
        }
    }
    
    private var currentTab: Tab = .elements
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        setupSegmentedControl()
        showTab(.elements)
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        // Use visual effect view for native iOS appearance
        let blurEffect = UIBlurEffect(style: .systemMaterial)
        let visualEffectView = UIVisualEffectView(effect: blurEffect)
        visualEffectView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(visualEffectView)
        view.sendSubviewToBack(visualEffectView)
        
        NSLayoutConstraint.activate([
            visualEffectView.topAnchor.constraint(equalTo: view.topAnchor),
            visualEffectView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            visualEffectView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            visualEffectView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        view.backgroundColor = UIColor.clear
        
        // Close Button
        closeButton.setImage(UIImage(systemName: "xmark.circle.fill"), for: .normal)
        closeButton.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(closeButton)
        
        // Segmented Control
        segmentedControl.selectedSegmentIndex = 0
        segmentedControl.addTarget(self, action: #selector(segmentedControlChanged), for: .valueChanged)
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(segmentedControl)
        
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
            
            // Segmented Control
            segmentedControl.topAnchor.constraint(equalTo: closeButton.bottomAnchor, constant: 10),
            segmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            segmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            segmentedControl.heightAnchor.constraint(equalToConstant: 32),
            
            // Content Container
            contentContainer.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 10),
            contentContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            contentContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            contentContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    private func setupSegmentedControl() {
        // Set accessibility identifiers for segments
        for (index, tab) in Tab.allCases.enumerated() {
            segmentedControl.setTitle(tab.title, forSegmentAt: index)
        }
        segmentedControl.selectedSegmentIndex = 0
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
        case .context:
            setupContextTabLayout()
            return // Special handling for context tab
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
        
        // Setup element details view with visual effect
        let detailsBlurEffect = UIBlurEffect(style: .systemThickMaterial)
        let detailsVisualEffectView = UIVisualEffectView(effect: detailsBlurEffect)
        detailsVisualEffectView.layer.cornerRadius = 8
        detailsVisualEffectView.clipsToBounds = true
        elementDetailsView.addSubview(detailsVisualEffectView)
        elementDetailsView.backgroundColor = UIColor.clear
        elementDetailsView.layer.cornerRadius = 8
        elementDetailsView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(elementDetailsView)
        
        detailsVisualEffectView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            detailsVisualEffectView.topAnchor.constraint(equalTo: elementDetailsView.topAnchor),
            detailsVisualEffectView.leadingAnchor.constraint(equalTo: elementDetailsView.leadingAnchor),
            detailsVisualEffectView.trailingAnchor.constraint(equalTo: elementDetailsView.trailingAnchor),
            detailsVisualEffectView.bottomAnchor.constraint(equalTo: elementDetailsView.bottomAnchor)
        ])
        
        elementDetailsLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        elementDetailsLabel.numberOfLines = 0
        elementDetailsLabel.text = "No element selected"
        elementDetailsLabel.translatesAutoresizingMaskIntoConstraints = false
        detailsVisualEffectView.contentView.addSubview(elementDetailsLabel)
        
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
    
    @objc private func segmentedControlChanged() {
        guard let tab = Tab(rawValue: segmentedControl.selectedSegmentIndex) else { return }
        showTab(tab)
    }
    
    
    private func selectDOMNode(_ node: DOMNode) {
        selectedDOMNode = node
        selectedElementSelector = node.selector
        elementsTableView.reloadData()
        
        // Update element details display using simplified format
        updateElementDetailsFromDOMNode(node)
    }
    
    private func updateElementDetailsFromDOMNode(_ node: DOMNode) {
        let details = """
        Element: \(node.tagName.uppercased())
        Selector: \(node.selector)
        
        Attributes:
        \(node.attributes.isEmpty ? "None" : node.attributes.map { "  \($0.key): \($0.value)" }.joined(separator: "\n"))
        
        Text Content:
        \(node.textContent?.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200) ?? "None")
        
        Children: \(node.children.count)
        Depth: \(node.depth)
        
        Note: Select an element on the page for detailed styles and dimensions.
        """
        
        elementDetailsLabel.text = details
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
    
    private func setupContextTabLayout() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(scrollView)
        
        let stackView = UIStackView()
        stackView.axis = .vertical
        stackView.spacing = 20
        stackView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(stackView)
        
        // Title
        let titleLabel = UILabel()
        titleLabel.text = "Context Export Configuration"
        titleLabel.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        titleLabel.textAlignment = .center
        stackView.addArrangedSubview(titleLabel)
        
        // Context Type Selection
        let contextTypeLabel = UILabel()
        contextTypeLabel.text = "Select Context Types:"
        contextTypeLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        stackView.addArrangedSubview(contextTypeLabel)
        
        let contextTypeStack = UIStackView()
        contextTypeStack.axis = .vertical
        contextTypeStack.spacing = 8
        stackView.addArrangedSubview(contextTypeStack)
        
        // Create checkboxes for context types
        let fullDOMCheckbox = createContextCheckbox(title: "Full DOM", isChecked: true)
        let selectedElementCheckbox = createContextCheckbox(title: "Selected Element", isChecked: true)
        let cssCheckbox = createContextCheckbox(title: "CSS Styles", isChecked: false)
        let networkCheckbox = createContextCheckbox(title: "Network Logs", isChecked: false)
        let consoleCheckbox = createContextCheckbox(title: "Console Logs", isChecked: false)
        
        contextTypeStack.addArrangedSubview(fullDOMCheckbox)
        contextTypeStack.addArrangedSubview(selectedElementCheckbox)
        contextTypeStack.addArrangedSubview(cssCheckbox)
        contextTypeStack.addArrangedSubview(networkCheckbox)
        contextTypeStack.addArrangedSubview(consoleCheckbox)
        
        // Format info (always plain text)
        let formatLabel = UILabel()
        formatLabel.text = "Output Format: Plain Text"
        formatLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        formatLabel.textColor = UIColor.secondaryLabel
        stackView.addArrangedSubview(formatLabel)
        
        // Prompt Template
        let promptLabel = UILabel()
        promptLabel.text = "Prompt Template:"
        promptLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        stackView.addArrangedSubview(promptLabel)
        
        let promptTextView = UITextView()
        promptTextView.text = "Debug this: {context}"
        promptTextView.font = UIFont.systemFont(ofSize: 14)
        promptTextView.backgroundColor = UIColor.systemGray6
        promptTextView.layer.cornerRadius = 8
        promptTextView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        promptTextView.translatesAutoresizingMaskIntoConstraints = false
        stackView.addArrangedSubview(promptTextView)
        
        // Action Buttons
        let buttonStack = UIStackView()
        buttonStack.axis = .horizontal
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 12
        stackView.addArrangedSubview(buttonStack)
        
        let previewButton = UIButton(type: .system)
        previewButton.setTitle("Preview", for: .normal)
        previewButton.backgroundColor = UIColor.systemBlue
        previewButton.setTitleColor(.white, for: .normal)
        previewButton.layer.cornerRadius = 8
        previewButton.addTarget(self, action: #selector(previewContext), for: .touchUpInside)
        buttonStack.addArrangedSubview(previewButton)
        
        let copyButton = UIButton(type: .system)
        copyButton.setTitle("Copy", for: .normal)
        copyButton.backgroundColor = UIColor.systemGreen
        copyButton.setTitleColor(.white, for: .normal)
        copyButton.layer.cornerRadius = 8
        copyButton.addTarget(self, action: #selector(copyConfiguredContext), for: .touchUpInside)
        buttonStack.addArrangedSubview(copyButton)
        
        // Context Preview
        let previewLabel = UILabel()
        previewLabel.text = "Context Preview:"
        previewLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        stackView.addArrangedSubview(previewLabel)
        
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        textView.backgroundColor = UIColor.systemGray6
        textView.layer.cornerRadius = 8
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.text = generateCompleteContext()
        contextTextView = textView
        stackView.addArrangedSubview(textView)
        
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentContainer.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor),
            
            stackView.topAnchor.constraint(equalTo: scrollView.topAnchor, constant: 16),
            stackView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor, constant: -16),
            stackView.widthAnchor.constraint(equalTo: scrollView.widthAnchor, constant: -32),
            
            promptTextView.heightAnchor.constraint(equalToConstant: 80),
            previewButton.heightAnchor.constraint(equalToConstant: 44),
            copyButton.heightAnchor.constraint(equalToConstant: 44),
            textView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    
    // MARK: - Context Configuration Methods
    
    private func createContextCheckbox(title: String, isChecked: Bool) -> UIView {
        let containerView = UIView()
        
        let button = UIButton(type: .system)
        button.setTitle(isChecked ? "☑️ \(title)" : "☐ \(title)", for: .normal)
        button.contentHorizontalAlignment = .left
        button.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        button.setTitleColor(UIColor.label, for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(contextTypeToggled(_:)), for: .touchUpInside)
        containerView.addSubview(button)
        
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: containerView.topAnchor),
            button.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
            button.heightAnchor.constraint(equalToConstant: 32)
        ])
        
        return containerView
    }
    
    @objc private func contextTypeToggled(_ sender: UIButton) {
        // Toggle checkbox state
        let currentTitle = sender.title(for: .normal) ?? ""
        let isCurrentlyChecked = currentTitle.hasPrefix("☑️")
        let baseTitle = currentTitle.replacingOccurrences(of: "☑️ ", with: "").replacingOccurrences(of: "☐ ", with: "")
        let newTitle = isCurrentlyChecked ? "☐ \(baseTitle)" : "☑️ \(baseTitle)"
        sender.setTitle(newTitle, for: .normal)
        
        updateContextPreview()
    }
    
    
    @objc private func previewContext() {
        let contextString = generateConfiguredContext()
        
        let alert = UIAlertController(title: "Context Preview", message: String(contextString.prefix(500)) + (contextString.count > 500 ? "..." : ""), preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    @objc private func copyConfiguredContext() {
        let contextString = generateConfiguredContext()
        UIPasteboard.general.string = contextString
        
        let alert = UIAlertController(title: "Copied!", message: "Context copied to clipboard", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func updateContextPreview() {
        contextTextView?.text = generateConfiguredContext()
    }
    
    private func generateConfiguredContext() -> String {
        // For now, return the complete context - this would be enhanced to respect checkbox selections
        return generateCompleteContext()
    }
    
    private func generateCompleteContext() -> String {
        let currentURL = currentWebView?.url?.absoluteString ?? "Unknown URL"
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        
        // Get recent console logs
        let recentConsoleLogs = consoleLogs.suffix(15).joined(separator: "\n")
        
        // Get failed and recent network requests
        let failedRequests = networkRequests.filter { $0.status >= 400 || $0.status == 0 }
        let recentRequests = networkRequests.suffix(10)
        
        // Generate comprehensive context
        let context = """
        # Complete Debug Context Export
        Generated: \(timestamp)
        Current URL: \(currentURL)
        
        ## Page Information
        - Active URL: \(currentURL)
        - Total Network Requests: \(networkRequests.count)
        - Failed Network Requests: \(failedRequests.count)
        - Console Log Entries: \(consoleLogs.count)
        
        ## Console Logs (Last 15 entries)
        \(recentConsoleLogs.isEmpty ? "No console logs available" : recentConsoleLogs)
        
        ## Network Request Summary
        ### Failed Requests (\(failedRequests.count) total):
        \(failedRequests.prefix(8).map { "❌ \($0.method) \($0.url) - Status: \($0.status)" }.joined(separator: "\n"))
        
        ### Recent Successful Requests:
        \(recentRequests.filter { $0.status >= 200 && $0.status < 400 }.map { "✅ \($0.method) \($0.url) - Status: \($0.status)" }.joined(separator: "\n"))
        
        ## Instructions for LLM Analysis:
        This is a complete debugging context from BerrryDebugger iOS app. Please analyze:
        1. Any console errors or warnings that indicate problems
        2. Failed network requests and potential causes
        3. Performance issues based on request patterns
        4. Recommendations for debugging or fixing identified issues
        
        Focus on actionable insights that would help debug web application issues.
        """
        
        return context
    }
    
    private func showCopySuccessAlert(message: String) {
        let alert = UIAlertController(title: "Copied!", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
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
        case .context:
            // Context tab - refresh the context content
            contextTextView?.text = generateCompleteContext()
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
        case .context:
            contextToExport = """
            # Full Context Export
            
            ## Current URL: \(currentWebView?.url?.absoluteString ?? "Unknown")
            
            ## Recent Console Logs:
            \(consoleLogs.suffix(10).joined(separator: "\n"))
            
            ## Network Summary:
            \(networkRequests.suffix(10).map { "- \($0.method) \($0.url) (\($0.status))" }.joined(separator: "\n"))
            
            ## LLM Analysis Prompt
            Analyze this combined context for debugging insights.
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