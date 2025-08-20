import UIKit
import WebKit
import os.log

protocol DevToolsViewControllerDelegate: AnyObject {
    func devToolsDidRequestDOMExtraction(for elementId: String, completion: @escaping (String?) -> Void)
    func devToolsDidRequestCSSExtraction(for elementId: String, completion: @escaping (String?) -> Void)
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
    private var selectedElementId: String = ""
    private var contextTextView: UITextView?
    private var filteredDOMElements: [LazyDOMElement] = []
    private var selectedDOMElement: LazyDOMElement?
    private var searchText: String = ""
    private var networkSearchText: String = ""
    
    // Context switches
    private var fullDOMSwitch: UISwitch?
    private var selectedElementSwitch: UISwitch?
    private var cssSwitch: UISwitch?
    private var networkSwitch: UISwitch?
    private var consoleSwitch: UISwitch?
    
    // DOM Inspector
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
        
        // Add a test console message to verify console functionality
        consoleLogs.append("🔍 DevTools initialized - console logging is working")
        
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
        elementsTableView.register(LazyDOMTableViewCell.self, forCellReuseIdentifier: LazyDOMTableViewCell.identifier)
        elementsTableView.separatorStyle = .none
        elementsTableView.backgroundColor = UIColor.systemBackground
        elementsTableView.allowsSelection = false  // Disable selection to prevent interference with buttons
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
        elementsTableView.register(LazyDOMTableViewCell.self, forCellReuseIdentifier: LazyDOMTableViewCell.identifier)
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
        
        // Trigger lazy loading of DOM elements when Elements tab is first opened
        if filteredDOMElements.isEmpty {
            NSLog("🔍 DevToolsViewController: Elements tab opened - triggering lazy DOM load")
            browserViewController?.domInspector?.loadInitialDOM()
        }
        
        // Reload the table with existing data
        elementsTableView.reloadData()
        NSLog("🔍 DevToolsViewController: Elements tab shown, reloaded table with \(filteredDOMElements.count) elements")
        
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
    
    // loadDOMContent() removed - DOM content now provided by BrowserViewController
    
    private func updateDOMDisplay() {
        NSLog("🔍 DevToolsViewController: updateDOMDisplay called - Elements are now provided by BrowserViewController")
        // DOM elements are now provided by BrowserViewController, just reload the table
        elementsTableView.reloadData()
        NSLog("🔍 DevToolsViewController: Reloaded table with \(filteredDOMElements.count) elements")
    }
    
    private func toggleElementExpansion(element: LazyDOMElement) {
        NSLog("🔍 toggleElementExpansion called for element: %@ (elementId: %@)", element.tagName, element.elementId)
        NSLog("🔍 Element isExpanded: %@, hasChildren: %@", element.isExpanded ? "YES" : "NO", element.hasChildren ? "YES" : "NO")
        NSLog("🔍 browserViewController exists: %@", browserViewController != nil ? "YES" : "NO")
        NSLog("🔍 domInspector exists: %@", browserViewController?.domInspector != nil ? "YES" : "NO")
        
        // Element expansion is now handled by BrowserViewController's LazyDOMInspector
        if element.isExpanded {
            NSLog("🔍 Calling collapseElement")
            browserViewController?.domInspector?.collapseElement(elementId: element.elementId)
        } else {
            NSLog("🔍 Calling expandElement")
            browserViewController?.domInspector?.expandElement(elementId: element.elementId)
        }
        
        // Update display immediately
        updateDOMDisplay()
    }
    
    // MARK: - Actions
    @objc private func closeButtonTapped() {
        dismiss(animated: true)
    }
    
    @objc private func segmentedControlChanged() {
        guard let tab = Tab(rawValue: segmentedControl.selectedSegmentIndex) else { return }
        showTab(tab)
    }
    
    
    private func selectDOMElement(_ element: LazyDOMElement) {
        selectedDOMElement = element
        selectedElementId = element.elementId
        elementsTableView.reloadData()
        
        // Update element details display
        updateElementDetailsFromDOMElement(element)
        
        // Select element in inspector for highlighting (now in BrowserViewController)
        browserViewController?.domInspector?.selectElement(elementId: element.elementId)
    }
    
    private func updateElementDetailsFromDOMElement(_ element: LazyDOMElement) {
        let details = """
        Element: \(element.tagName.uppercased())
        Selector: \(element.displaySelector ?? element.elementId)
        
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
        \(element.attributes.isEmpty ? "None" : element.attributes.map { "  \($0.key): \($0.value)" }.joined(separator: "\n"))
        
        Text Content:
        \(element.textContent?.trimmingCharacters(in: .whitespacesAndNewlines).prefix(200) ?? "None")
        
        Children: \(element.childCount) (Has Children: \(element.hasChildren))
        Depth: \(element.depth)
        Loading State: \(element.loadingState)
        """
        
        elementDetailsLabel.text = details
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
        
        // Action Buttons (moved to top)
        let buttonStack = UIStackView()
        buttonStack.axis = .horizontal
        buttonStack.distribution = .fillEqually
        buttonStack.spacing = 12
        stackView.addArrangedSubview(buttonStack)
        
        let copyButton = UIButton(type: .system)
        copyButton.setTitle("📋 Copy", for: .normal)
        copyButton.backgroundColor = UIColor.systemGreen
        copyButton.setTitleColor(.white, for: .normal)
        copyButton.layer.cornerRadius = 8
        copyButton.addTarget(self, action: #selector(copyConfiguredContext), for: .touchUpInside)
        buttonStack.addArrangedSubview(copyButton)
        
        let shareButton = UIButton(type: .system)
        shareButton.setTitle("📤 Share", for: .normal)
        shareButton.backgroundColor = UIColor.systemBlue
        shareButton.setTitleColor(.white, for: .normal)
        shareButton.layer.cornerRadius = 8
        shareButton.addTarget(self, action: #selector(shareContext), for: .touchUpInside)
        buttonStack.addArrangedSubview(shareButton)
        
        // Context Preview (moved to top)
        let previewLabel = UILabel()
        previewLabel.text = "Preview:"
        previewLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        stackView.addArrangedSubview(previewLabel)
        
        let textView = UITextView()
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.isEditable = false
        textView.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        textView.backgroundColor = UIColor.systemGray6
        textView.layer.cornerRadius = 8
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        textView.text = generateConfiguredContext()
        contextTextView = textView
        stackView.addArrangedSubview(textView)
        
        // Context Type Selection (moved down)
        let contextTypeLabel = UILabel()
        contextTypeLabel.text = "Include Data:"
        contextTypeLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        stackView.addArrangedSubview(contextTypeLabel)
        
        let contextTypeStack = UIStackView()
        contextTypeStack.axis = .vertical
        contextTypeStack.spacing = 8
        stackView.addArrangedSubview(contextTypeStack)
        
        // Create switches for context types
        let fullDOMContainer = createContextSwitch(title: "Full DOM", isOn: false, switchRef: &fullDOMSwitch)
        let selectedElementContainer = createContextSwitch(title: "Selected Element", isOn: true, switchRef: &selectedElementSwitch)
        let cssContainer = createContextSwitch(title: "CSS Styles", isOn: false, switchRef: &cssSwitch)
        let networkContainer = createContextSwitch(title: "Network Logs", isOn: true, switchRef: &networkSwitch)
        let consoleContainer = createContextSwitch(title: "Console Logs", isOn: true, switchRef: &consoleSwitch)
        
        contextTypeStack.addArrangedSubview(fullDOMContainer)
        contextTypeStack.addArrangedSubview(selectedElementContainer)
        contextTypeStack.addArrangedSubview(cssContainer)
        contextTypeStack.addArrangedSubview(networkContainer)
        contextTypeStack.addArrangedSubview(consoleContainer)
        
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
            copyButton.heightAnchor.constraint(equalToConstant: 44),
            shareButton.heightAnchor.constraint(equalToConstant: 44),
            textView.heightAnchor.constraint(equalToConstant: 200)
        ])
    }
    
    
    // MARK: - Context Configuration Methods
    
    private func createContextSwitch(title: String, isOn: Bool, switchRef: inout UISwitch?) -> UIView {
        let containerView = UIView()
        
        // Create label
        let label = UILabel()
        label.text = title
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = UIColor.label
        label.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(label)
        
        // Create switch
        let toggle = UISwitch()
        toggle.isOn = isOn
        toggle.addTarget(self, action: #selector(contextSwitchToggled(_:)), for: .valueChanged)
        toggle.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(toggle)
        
        // Store reference
        switchRef = toggle
        
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 6),
            label.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: toggle.leadingAnchor, constant: -12),
            label.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -6),
            
            toggle.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            toggle.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            
            containerView.heightAnchor.constraint(equalToConstant: 44)
        ])
        
        return containerView
    }
    
    @objc private func contextSwitchToggled(_ sender: UISwitch) {
        updateContextPreview()
    }
    
    
    @objc private func shareContext() {
        let contextString = generateConfiguredContext()
        let activityViewController = UIActivityViewController(activityItems: [contextString], applicationActivities: nil)
        
        // Handle iPad presentation
        if let popover = activityViewController.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        present(activityViewController, animated: true)
    }
    
    @objc private func copyConfiguredContext() {
        let contextString = generateConfiguredContext()
        UIPasteboard.general.string = contextString
        
        // Show visual feedback
        let alert = UIAlertController(title: "Copied!", message: "Context copied to clipboard", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    }
    
    private func updateContextPreview() {
        contextTextView?.text = generateConfiguredContext()
    }
    
    private func generateConfiguredContext() -> String {
        let currentURL = currentWebView?.url?.absoluteString ?? "Unknown URL"
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
        
        var contextSections: [String] = []
        
        // Add header
        contextSections.append("""
        # Debug Context Export
        Generated: \(timestamp)
        Current URL: \(currentURL)
        """)
        
        // Add sections based on switch states
        if fullDOMSwitch?.isOn == true {
            contextSections.append("""
            
            ## Full DOM Structure
            [Full DOM would be extracted here - requires JavaScript evaluation]
            """)
        }
        
        if selectedElementSwitch?.isOn == true {
            let elementInfo = selectedDOMElement?.tagName ?? "No element selected"
            contextSections.append("""
            
            ## Selected Element
            Element: \(elementInfo)
            Selector: \(selectedDOMElement?.displaySelector ?? "None")
            """)
        }
        
        if cssSwitch?.isOn == true {
            contextSections.append("""
            
            ## CSS Styles
            [CSS styles would be extracted here - requires JavaScript evaluation]
            """)
        }
        
        if networkSwitch?.isOn == true {
            let failedRequests = networkRequests.filter { $0.status >= 400 || $0.status == 0 }
            let recentRequests = networkRequests.suffix(10)
            
            contextSections.append("""
            
            ## Network Requests (\(networkRequests.count) total)
            ### Failed Requests (\(failedRequests.count)):
            \(failedRequests.prefix(5).map { "❌ \($0.method) \($0.url) - Status: \($0.status)" }.joined(separator: "\n"))
            
            ### Recent Requests:
            \(recentRequests.map { "✅ \($0.method) \($0.url) - Status: \($0.status)" }.joined(separator: "\n"))
            """)
        }
        
        if consoleSwitch?.isOn == true {
            let recentConsoleLogs = consoleLogs.suffix(15).joined(separator: "\n")
            contextSections.append("""
            
            ## Console Logs (Last 15 entries)
            \(recentConsoleLogs.isEmpty ? "No console logs available" : recentConsoleLogs)
            """)
        }
        
        // Add analysis prompt if any sections are included
        if contextSections.count > 1 {
            contextSections.append("""
            
            ## Instructions for LLM Analysis:
            Please analyze the above context for:
            1. Any console errors or warnings that indicate problems
            2. Failed network requests and potential causes
            3. Performance issues based on request patterns
            4. Recommendations for debugging or fixing identified issues
            
            Focus on actionable insights that would help debug web application issues.
            """)
        }
        
        return contextSections.joined(separator: "\n")
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
    func updateData(consoleLogs: [String], networkRequests: [NetworkRequestModel], webView: WKWebView, domElements: [LazyDOMElement]) {
        self.consoleLogs = consoleLogs
        self.networkRequests = networkRequests
        self.currentWebView = webView
        self.filteredDOMElements = domElements
        NSLog("🔍 DevToolsViewController: updateData called with \(domElements.count) DOM elements")
        
        // Update current tab data without rebuilding UI
        switch currentTab {
        case .network:
            updateNetworkDisplay()
        case .console:
            updateConsoleDisplay()
        case .elements:
            // Elements tab - just reload the table with the provided elements
            elementsTableView.reloadData()
            NSLog("🔍 DevToolsViewController: Reloaded elements table with \(domElements.count) elements")
        case .context:
            // Context tab - refresh the context content with switch-based configuration
            updateContextPreview()
        }
        
        // Always update context preview if context tab exists and data has changed
        // This ensures the preview stays current even when not actively viewing the context tab
        if contextTextView != nil {
            updateContextPreview()
        }
    }
    
    // New methods for receiving DOM updates from BrowserViewController
    func updateDOMElements(_ elements: [LazyDOMElement]) {
        NSLog("🔍 DevToolsViewController: updateDOMElements called with \(elements.count) elements")
        self.filteredDOMElements = elements
        if currentTab == .elements {
            elementsTableView.reloadData()
            NSLog("🔍 DevToolsViewController: Reloaded elements table")
        }
    }
    
    func updateDOMChildren(_ children: [LazyDOMElement], for elementId: String) {
        NSLog("✅ DevToolsViewController: updateDOMChildren called with \(children.count) children for elementId: \(elementId)")
        NSLog("🔍 DevToolsViewController: browserViewController exists: %@", browserViewController != nil ? "YES" : "NO")
        
        if let browserVC = browserViewController {
            NSLog("🔍 DevToolsViewController: domInspector exists: %@", browserVC.domInspector != nil ? "YES" : "NO")
        }
        
        // Get updated flattened elements from the DOM inspector
        if let inspector = browserViewController?.domInspector {
            let updatedElements = inspector.getFlattenedVisibleElements()
            NSLog("✅ DevToolsViewController: Got \(updatedElements.count) flattened elements from inspector")
            self.filteredDOMElements = updatedElements
            
            // Reload table if we're on elements tab
            NSLog("🔍 DevToolsViewController: currentTab is: %@", String(describing: currentTab))
            if currentTab == .elements {
                DispatchQueue.main.async {
                    self.elementsTableView.reloadData()
                    NSLog("✅ DevToolsViewController: Reloaded elements table with expanded children")
                }
            } else {
                NSLog("❌ DevToolsViewController: Not reloading table because currentTab is not .elements")
            }
        } else {
            NSLog("❌ DevToolsViewController: Could not get DOM inspector from browserViewController")
        }
    }
    
    func updateSelectedElement(_ element: LazyDOMElement) {
        NSLog("🔍 DevToolsViewController: updateSelectedElement called")
        self.selectedDOMElement = element
        if currentTab == .elements {
            updateElementDetailsFromDOMElement(element)
            elementsTableView.reloadData()
        }
        // Update context preview when selected element changes
        if currentTab == .context {
            updateContextPreview()
        }
    }
}


// MARK: - UITableViewDataSource & UITableViewDelegate
extension DevToolsViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if tableView == elementsTableView {
            return filteredDOMElements.count
        } else if tableView == consoleTableView {
            return consoleLogs.count
        } else if tableView == networkTableView {
            return filteredNetworkRequests.count
        }
        return 0
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == elementsTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: LazyDOMTableViewCell.identifier, for: indexPath) as! LazyDOMTableViewCell
            let element = filteredDOMElements[indexPath.row]
            
            cell.configure(with: element, onExpand: { [weak self] in
                NSLog("🔍 DevToolsViewController: Cell expand callback triggered for \(element.tagName)")
                self?.toggleElementExpansion(element: element)
            }, onSelect: { [weak self] in
                NSLog("🔍 DevToolsViewController: Cell select callback triggered for \(element.tagName)")
                self?.selectDOMElement(element)
            })
            
            // Handle selection state
            if element.elementId == self.selectedDOMElement?.elementId {
                cell.setSelected(element)
            } else {
                cell.setDeselected()
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
        // Only handle selection for non-elements tables since elementsTableView.allowsSelection = false
        tableView.deselectRow(at: indexPath, animated: true)
        
        if tableView != elementsTableView {
            // Handle other table views if needed
        }
    }
}

// MARK: - ContextCopyControllerDelegate
extension DevToolsViewController: ContextCopyControllerDelegate {
    func contextCopyController(_ controller: ContextCopyController, didRequestDOMExtraction completion: @escaping (String?) -> Void) {
        delegate?.devToolsDidRequestDOMExtraction(for: selectedElementId.isEmpty ? "" : selectedElementId, completion: completion)
    }
    
    func contextCopyController(_ controller: ContextCopyController, didRequestCSSExtraction completion: @escaping (String?) -> Void) {
        delegate?.devToolsDidRequestCSSExtraction(for: selectedElementId.isEmpty ? "body" : selectedElementId, completion: completion)
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
        // Legacy method - DOM tree now provided by BrowserViewController
        // No action needed here
    }
    
    func updateSelectedElementFromData(_ elementData: [String: Any]) {
        // Legacy method - now handled by BrowserViewController's LazyDOMInspector
        // Extract elementId from elementData and use it
        if let elementId = elementData["elementId"] as? String {
            browserViewController?.domInspector?.selectElement(elementId: elementId)
        }
        
        // Disable selection mode after selection
        isElementSelectionMode = false
        elementSelectButton.isSelected = false
    }
    
    // Enhanced copy functionality for DOM inspector context
    func copyDOMInspectorContext() {
        var contextToExport = ""
        
        switch currentTab {
        case .elements:
            if let selectedElement = browserViewController?.domInspector?.getSelectedElement() {
                contextToExport = generateElementContext(selectedElement)
            } else {
                contextToExport = generateGeneralElementsContext()
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
    
    private func generateElementContext(_ element: LazyDOMElement) -> String {
        return """
        # Element Analysis Context
        
        ## Selected Element
        Tag: \(element.tagName)
        Selector: \(element.displaySelector ?? element.elementId)
        Dimensions: \(element.dimensions.width) × \(element.dimensions.height)
        Position: (\(element.dimensions.left), \(element.dimensions.top))
        
        ## Attributes
        \(element.attributes.map { "\($0.key): \($0.value)" }.joined(separator: "\n"))
        
        ## Styles
        Display: \(element.styles.display)
        Position: \(element.styles.position)
        Color: \(element.styles.color)
        Background: \(element.styles.backgroundColor)
        
        ## Context
        Text Content: \(element.textContent?.prefix(200) ?? "None")
        Child Count: \(element.childCount)
        Depth: \(element.depth)
        
        ## LLM Analysis Prompt
        Analyze this DOM element for potential issues, accessibility concerns, or styling problems.
        """
    }
    
    private func generateGeneralElementsContext() -> String {
        let totalElements = filteredDOMElements.count
        let selectedElementsInfo = filteredDOMElements.prefix(10).map { element in
            "\(element.tagName.lowercased())\(element.id != nil ? "#\(element.id!)" : "")"
        }.joined(separator: ", ")
        
        return """
        # DOM Elements Overview
        
        ## Current Page Elements
        Total visible elements: \(totalElements)
        Sample elements: \(selectedElementsInfo)
        
        ## LLM Analysis Prompt
        Analyze the DOM structure for potential performance or accessibility issues.
        """
    }
}

// MARK: - Public API for BrowserViewController
extension DevToolsViewController {
    
    func setBrowserViewController(_ browser: BrowserViewController) {
        NSLog("🔍 DevToolsViewController: setBrowserViewController called!")
        NSLog("🔍 DevToolsViewController: Browser has domInspector: %@", browser.domInspector != nil ? "YES" : "NO")
        self.browserViewController = browser
        NSLog("🔍 DevToolsViewController: browserViewController successfully set: %@", self.browserViewController != nil ? "YES" : "NO")
    }
    
    // handleLazyDOMMessage removed - DOM handling now done by BrowserViewController
}

// LazyDOMInspectorDelegate extension removed - 
// DOM handling now done by BrowserViewController