import UIKit

protocol EnhancedContextViewControllerDelegate: AnyObject {
    func enhancedContextViewController(_ controller: EnhancedContextViewController, didSelectContextTypes types: Set<ContextType>, format: ContextFormat, prompt: String)
}

class EnhancedContextViewController: UIViewController {
    
    weak var delegate: EnhancedContextViewControllerDelegate?
    
    // MARK: - UI Components
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    
    // Context Type Selection
    private let contextSelectionLabel = UILabel()
    private let contextStackView = UIStackView()
    private var contextSwitches: [ContextType: UISwitch] = [:]
    
    // Format Selection
    private let formatSelectionLabel = UILabel()
    private let formatSegmentedControl = UISegmentedControl(items: ["JSON", "Plain Text"])
    
    // Prompt Template
    private let promptLabel = UILabel()
    private let promptTextView = UITextView()
    private let promptCharacterLabel = UILabel()
    
    // Preview Section
    private let previewLabel = UILabel()
    private let previewTextView = UITextView()
    private let previewCharacterLabel = UILabel()
    
    // Action Buttons
    private let actionStackView = UIStackView()
    private let previewButton = UIButton(type: .system)
    private let copyButton = UIButton(type: .system)
    private let closeButton = UIButton(type: .system)
    
    // Data
    private var selectedContextTypes: Set<ContextType> = [.selectedElement, .networkLogs, .consoleLogs]
    private var selectedFormat: ContextFormat = .json
    private var promptTemplate: String = "Debug this: {context}"
    private var previewContent: String = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupConstraints()
        loadSettings()
        updatePreview()
    }
    
    // MARK: - UI Setup
    private func setupUI() {
        view.backgroundColor = UIColor.systemBackground
        
        // Scroll View
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        
        // Content View
        contentView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentView)
        
        // Title
        titleLabel.text = "📋 Context for LLM"
        titleLabel.font = UIFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(titleLabel)
        
        // Subtitle
        subtitleLabel.text = "Select what to include in your prompt"
        subtitleLabel.font = UIFont.systemFont(ofSize: 16, weight: .regular)
        subtitleLabel.textColor = UIColor.secondaryLabel
        subtitleLabel.textAlignment = .center
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(subtitleLabel)
        
        setupContextSelection()
        setupFormatSelection()
        setupPromptSection()
        setupPreviewSection()
        setupActionButtons()
    }
    
    private func setupContextSelection() {
        // Section Label
        contextSelectionLabel.text = "📄 Include Data"
        contextSelectionLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        contextSelectionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(contextSelectionLabel)
        
        // Stack View
        contextStackView.axis = .vertical
        contextStackView.spacing = 8
        contextStackView.distribution = .fillEqually
        contextStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(contextStackView)
        
        // Create switches for each context type
        let contextTypes: [(ContextType, String, String)] = [
            (.selectedElement, "🎯 Selected Element", "Currently selected DOM element"),
            (.fullDOM, "🌐 Full DOM", "Complete HTML structure"),
            (.css, "🎨 CSS Styles", "Computed styles for selected element"),
            (.networkLogs, "🌐 Network Requests", "All network activity"),
            (.consoleLogs, "📊 Console Logs", "JavaScript console output")
        ]
        
        for (type, title, subtitle) in contextTypes {
            let switchContainer = createContextSwitchRow(type: type, title: title, subtitle: subtitle)
            contextStackView.addArrangedSubview(switchContainer)
        }
    }
    
    private func createContextSwitchRow(type: ContextType, title: String, subtitle: String) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.systemGray6
        containerView.layer.cornerRadius = 12
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Create labels stack
        let labelsStack = UIStackView()
        labelsStack.axis = .vertical
        labelsStack.spacing = 2
        labelsStack.translatesAutoresizingMaskIntoConstraints = false
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        titleLabel.textColor = UIColor.label
        
        let subtitleLabel = UILabel()
        subtitleLabel.text = subtitle
        subtitleLabel.font = UIFont.systemFont(ofSize: 14, weight: .regular)
        subtitleLabel.textColor = UIColor.secondaryLabel
        subtitleLabel.numberOfLines = 0
        
        labelsStack.addArrangedSubview(titleLabel)
        labelsStack.addArrangedSubview(subtitleLabel)
        
        // Create switch
        let toggle = UISwitch()
        toggle.isOn = selectedContextTypes.contains(type)
        toggle.addTarget(self, action: #selector(contextSwitchToggled(_:)), for: .valueChanged)
        toggle.translatesAutoresizingMaskIntoConstraints = false
        
        // Store switch reference
        contextSwitches[type] = toggle
        
        containerView.addSubview(labelsStack)
        containerView.addSubview(toggle)
        
        NSLayoutConstraint.activate([
            labelsStack.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 12),
            labelsStack.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 16),
            labelsStack.trailingAnchor.constraint(equalTo: toggle.leadingAnchor, constant: -12),
            labelsStack.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -12),
            
            toggle.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
            toggle.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -16),
            
            containerView.heightAnchor.constraint(greaterThanOrEqualToConstant: 60)
        ])
        
        return containerView
    }
    
    private func setupFormatSelection() {
        // Section Label
        formatSelectionLabel.text = "📝 Output Format"
        formatSelectionLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        formatSelectionLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(formatSelectionLabel)
        
        // Segmented Control
        formatSegmentedControl.selectedSegmentIndex = selectedFormat == .json ? 0 : 1
        formatSegmentedControl.addTarget(self, action: #selector(formatChanged(_:)), for: .valueChanged)
        formatSegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(formatSegmentedControl)
    }
    
    private func setupPromptSection() {
        // Section Label
        promptLabel.text = "✏️ Prompt Template"
        promptLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        promptLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(promptLabel)
        
        // Text View
        promptTextView.text = promptTemplate
        promptTextView.font = UIFont.systemFont(ofSize: 16)
        promptTextView.backgroundColor = UIColor.systemGray6
        promptTextView.layer.cornerRadius = 8
        promptTextView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        promptTextView.delegate = self
        promptTextView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(promptTextView)
        
        // Character Count
        promptCharacterLabel.text = "Use {context} as placeholder • \(promptTemplate.count) characters"
        promptCharacterLabel.font = UIFont.systemFont(ofSize: 12)
        promptCharacterLabel.textColor = UIColor.secondaryLabel
        promptCharacterLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(promptCharacterLabel)
    }
    
    private func setupPreviewSection() {
        // Section Label
        previewLabel.text = "👀 Preview"
        previewLabel.font = UIFont.systemFont(ofSize: 18, weight: .semibold)
        previewLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(previewLabel)
        
        // Text View
        previewTextView.isEditable = false
        previewTextView.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        previewTextView.backgroundColor = UIColor.systemGray6
        previewTextView.layer.cornerRadius = 8
        previewTextView.textContainerInset = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
        previewTextView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(previewTextView)
        
        // Character Count
        previewCharacterLabel.text = "0 characters"
        previewCharacterLabel.font = UIFont.systemFont(ofSize: 12)
        previewCharacterLabel.textColor = UIColor.secondaryLabel
        previewCharacterLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(previewCharacterLabel)
    }
    
    private func setupActionButtons() {
        // Stack View
        actionStackView.axis = .horizontal
        actionStackView.spacing = 12
        actionStackView.distribution = .fillEqually
        actionStackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(actionStackView)
        
        // Preview Button
        previewButton.setTitle("🔄 Refresh", for: .normal)
        previewButton.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        previewButton.setTitleColor(UIColor.systemBlue, for: .normal)
        previewButton.layer.cornerRadius = 8
        previewButton.addTarget(self, action: #selector(refreshPreview), for: .touchUpInside)
        
        // Copy Button
        copyButton.setTitle("📋 Copy", for: .normal)
        copyButton.backgroundColor = UIColor.systemGreen
        copyButton.setTitleColor(.white, for: .normal)
        copyButton.layer.cornerRadius = 8
        copyButton.addTarget(self, action: #selector(copyContent), for: .touchUpInside)
        
        // Close Button
        closeButton.setTitle("✕ Close", for: .normal)
        closeButton.backgroundColor = UIColor.systemGray
        closeButton.setTitleColor(.white, for: .normal)
        closeButton.layer.cornerRadius = 8
        closeButton.addTarget(self, action: #selector(closeViewController), for: .touchUpInside)
        
        actionStackView.addArrangedSubview(previewButton)
        actionStackView.addArrangedSubview(copyButton)
        actionStackView.addArrangedSubview(closeButton)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Scroll View
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content View
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Title
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Subtitle
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Context Selection
            contextSelectionLabel.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 24),
            contextSelectionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            contextSelectionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            contextStackView.topAnchor.constraint(equalTo: contextSelectionLabel.bottomAnchor, constant: 12),
            contextStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            contextStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Format Selection
            formatSelectionLabel.topAnchor.constraint(equalTo: contextStackView.bottomAnchor, constant: 24),
            formatSelectionLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            formatSelectionLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            formatSegmentedControl.topAnchor.constraint(equalTo: formatSelectionLabel.bottomAnchor, constant: 12),
            formatSegmentedControl.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            formatSegmentedControl.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            formatSegmentedControl.heightAnchor.constraint(equalToConstant: 32),
            
            // Prompt Section
            promptLabel.topAnchor.constraint(equalTo: formatSegmentedControl.bottomAnchor, constant: 24),
            promptLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            promptLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            promptTextView.topAnchor.constraint(equalTo: promptLabel.bottomAnchor, constant: 12),
            promptTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            promptTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            promptTextView.heightAnchor.constraint(equalToConstant: 80),
            
            promptCharacterLabel.topAnchor.constraint(equalTo: promptTextView.bottomAnchor, constant: 4),
            promptCharacterLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            promptCharacterLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Preview Section
            previewLabel.topAnchor.constraint(equalTo: promptCharacterLabel.bottomAnchor, constant: 24),
            previewLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            previewLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            previewTextView.topAnchor.constraint(equalTo: previewLabel.bottomAnchor, constant: 12),
            previewTextView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            previewTextView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            previewTextView.heightAnchor.constraint(equalToConstant: 120),
            
            previewCharacterLabel.topAnchor.constraint(equalTo: previewTextView.bottomAnchor, constant: 4),
            previewCharacterLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            previewCharacterLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            
            // Action Buttons
            actionStackView.topAnchor.constraint(equalTo: previewCharacterLabel.bottomAnchor, constant: 24),
            actionStackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            actionStackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            actionStackView.heightAnchor.constraint(equalToConstant: 50),
            actionStackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
        
        // Switch containers are sized by their intrinsic content size
    }
    
    // MARK: - Actions
    @objc private func contextSwitchToggled(_ sender: UISwitch) {
        // Find which context type this switch corresponds to
        for (type, switchControl) in contextSwitches {
            if switchControl == sender {
                if sender.isOn {
                    selectedContextTypes.insert(type)
                } else {
                    selectedContextTypes.remove(type)
                }
                break
            }
        }
        
        updatePreview()
    }
    
    @objc private func formatChanged(_ sender: UISegmentedControl) {
        selectedFormat = sender.selectedSegmentIndex == 0 ? .json : .plainText
        updatePreview()
    }
    
    @objc private func refreshPreview() {
        updatePreview()
    }
    
    @objc private func copyContent() {
        let finalContent = promptTextView.text.replacingOccurrences(of: "{context}", with: previewContent)
        UIPasteboard.general.string = finalContent
        
        // Visual feedback
        copyButton.setTitle("✅ Copied!", for: .normal)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            self.copyButton.setTitle("📋 Copy", for: .normal)
        }
        
        // Save settings
        saveSettings()
    }
    
    @objc private func closeViewController() {
        dismiss(animated: true)
    }
    
    // MARK: - Helper Methods
    
    private func updatePreview() {
        // Mock preview content based on selected types
        var mockContent = ""
        
        if selectedContextTypes.contains(.selectedElement) {
            if selectedFormat == .json {
                mockContent += "\"html\": \"<div class=\\\"example\\\">Selected element</div>\""
            } else {
                mockContent += "HTML: <div class=\"example\">Selected element</div>"
            }
        }
        
        if selectedContextTypes.contains(.fullDOM) {
            let separator = selectedFormat == .json ? ", " : "\\n\\n"
            if !mockContent.isEmpty { mockContent += separator }
            if selectedFormat == .json {
                mockContent += "\"fullDOM\": \"<!DOCTYPE html><html>...</html>\""
            } else {
                mockContent += "Full DOM: <!DOCTYPE html><html>...</html>"
            }
        }
        
        if selectedContextTypes.contains(.css) {
            let separator = selectedFormat == .json ? ", " : "\\n\\n"
            if !mockContent.isEmpty { mockContent += separator }
            if selectedFormat == .json {
                mockContent += "\"css\": \"color: blue; font-size: 16px;\""
            } else {
                mockContent += "CSS: color: blue; font-size: 16px;"
            }
        }
        
        if selectedContextTypes.contains(.networkLogs) {
            let separator = selectedFormat == .json ? ", " : "\\n\\n"
            if !mockContent.isEmpty { mockContent += separator }
            if selectedFormat == .json {
                mockContent += "\"network\": [{\"url\": \"https://example.com\", \"status\": 200}]"
            } else {
                mockContent += "Network: GET https://example.com (200)"
            }
        }
        
        if selectedContextTypes.contains(.consoleLogs) {
            let separator = selectedFormat == .json ? ", " : "\\n\\n"
            if !mockContent.isEmpty { mockContent += separator }
            if selectedFormat == .json {
                mockContent += "\"console\": [\"[LOG] Page loaded\"]"
            } else {
                mockContent += "Console: [LOG] Page loaded"
            }
        }
        
        if selectedFormat == .json && !mockContent.isEmpty {
            mockContent = "{" + mockContent + "}"
        }
        
        previewContent = mockContent
        previewTextView.text = mockContent.isEmpty ? "Select context types to see preview..." : mockContent
        previewCharacterLabel.text = "\(mockContent.count) characters"
    }
    
    private func loadSettings() {
        if let savedPrompt = UserDefaults.standard.string(forKey: "PromptTemplate") {
            promptTemplate = savedPrompt
            promptTextView.text = savedPrompt
        }
    }
    
    private func saveSettings() {
        UserDefaults.standard.set(promptTextView.text, forKey: "PromptTemplate")
    }
}

// MARK: - UITextViewDelegate
extension EnhancedContextViewController: UITextViewDelegate {
    func textViewDidChange(_ textView: UITextView) {
        if textView == promptTextView {
            promptTemplate = textView.text
            promptCharacterLabel.text = "Use {context} as placeholder • \(textView.text.count) characters"
        }
    }
}

// MARK: - ContextType Extension
extension ContextType: CaseIterable {
    public static var allCases: [ContextType] {
        return [.selectedElement, .fullDOM, .css, .networkLogs, .consoleLogs]
    }
}