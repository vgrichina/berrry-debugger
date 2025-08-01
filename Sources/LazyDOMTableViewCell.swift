import UIKit

class LazyDOMTableViewCell: UITableViewCell {
    
    static let identifier = "LazyDOMTableViewCell"
    
    // UI Components
    private let indentView = UIView()
    private let expandButton = UIButton(type: .system)
    private let tagLabel = UILabel()
    private let attributesLabel = UILabel()
    private let loadingIndicator = UIActivityIndicatorView(style: .medium)
    private let childCountLabel = UILabel()
    
    // Expand callback
    private var onExpand: (() -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        // Cell styling
        selectionStyle = .none
        backgroundColor = UIColor.systemBackground
        
        // Indent view for depth visualization
        indentView.backgroundColor = UIColor.clear
        indentView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(indentView)
        
        // Expand button
        expandButton.titleLabel?.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        expandButton.setTitleColor(UIColor.systemBlue, for: .normal)
        expandButton.addTarget(self, action: #selector(expandButtonTapped), for: .touchUpInside)
        expandButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(expandButton)
        
        // Tag label
        tagLabel.font = UIFont.monospacedSystemFont(ofSize: 14, weight: .medium)
        tagLabel.textColor = UIColor.label
        tagLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(tagLabel)
        
        // Attributes label
        attributesLabel.font = UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        attributesLabel.textColor = UIColor.secondaryLabel
        attributesLabel.numberOfLines = 1
        attributesLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(attributesLabel)
        
        // Loading indicator
        loadingIndicator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(loadingIndicator)
        
        // Child count label
        childCountLabel.font = UIFont.systemFont(ofSize: 10, weight: .medium)
        childCountLabel.textColor = UIColor.tertiaryLabel
        childCountLabel.backgroundColor = UIColor.systemGray5
        childCountLabel.layer.cornerRadius = 8
        childCountLabel.textAlignment = .center
        childCountLabel.clipsToBounds = true
        childCountLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(childCountLabel)
        
        setupConstraints()
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Indent view
            indentView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            indentView.topAnchor.constraint(equalTo: contentView.topAnchor),
            indentView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            indentView.widthAnchor.constraint(equalToConstant: 0), // Will be updated dynamically
            
            // Expand button
            expandButton.leadingAnchor.constraint(equalTo: indentView.trailingAnchor, constant: 4),
            expandButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            expandButton.widthAnchor.constraint(equalToConstant: 20),
            expandButton.heightAnchor.constraint(equalToConstant: 20),
            
            // Loading indicator (same position as expand button)
            loadingIndicator.centerXAnchor.constraint(equalTo: expandButton.centerXAnchor),
            loadingIndicator.centerYAnchor.constraint(equalTo: expandButton.centerYAnchor),
            
            // Tag label
            tagLabel.leadingAnchor.constraint(equalTo: expandButton.trailingAnchor, constant: 8),
            tagLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            tagLabel.trailingAnchor.constraint(lessThanOrEqualTo: childCountLabel.leadingAnchor, constant: -8),
            
            // Attributes label
            attributesLabel.leadingAnchor.constraint(equalTo: tagLabel.leadingAnchor),
            attributesLabel.topAnchor.constraint(equalTo: tagLabel.bottomAnchor, constant: 2),
            attributesLabel.trailingAnchor.constraint(lessThanOrEqualTo: childCountLabel.leadingAnchor, constant: -8),
            attributesLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),
            
            // Child count label
            childCountLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            childCountLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            childCountLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 16),
            childCountLabel.heightAnchor.constraint(equalToConstant: 16)
        ])
    }
    
    func configure(with element: LazyDOMElement, onExpand: @escaping () -> Void) {
        self.onExpand = onExpand
        
        // Update indent based on depth
        let indentWidth = CGFloat(element.depth * 16)
        // Remove existing width constraints first
        indentView.constraints.forEach { constraint in
            if constraint.firstAttribute == .width {
                constraint.isActive = false
                indentView.removeConstraint(constraint)
            }
        }
        // Add new width constraint
        indentView.widthAnchor.constraint(equalToConstant: indentWidth).isActive = true
        
        // Configure expand button
        if element.hasChildren {
            expandButton.isHidden = false
            loadingIndicator.isHidden = true
            
            switch element.loadingState {
            case .loading:
                expandButton.isHidden = true
                loadingIndicator.isHidden = false
                loadingIndicator.startAnimating()
                
            case .loaded where element.isExpanded:
                expandButton.setTitle("▼", for: .normal)
                loadingIndicator.stopAnimating()
                
            case .notLoaded, .loaded:
                expandButton.setTitle("▶", for: .normal)
                loadingIndicator.stopAnimating()
                
            case .error(let message):
                expandButton.setTitle("⚠️", for: .normal)
                expandButton.setTitleColor(UIColor.systemRed, for: .normal)
                loadingIndicator.stopAnimating()
                print("DOM loading error: \(message)")
            }
        } else {
            expandButton.isHidden = true
            loadingIndicator.isHidden = true
            loadingIndicator.stopAnimating()
        }
        
        // Configure tag label
        var tagText = element.tagName.lowercased()
        
        // Add ID if present
        if let id = element.id, !id.isEmpty {
            tagText += "#\(id)"
        }
        
        // Add classes if present
        if let className = element.className, !className.isEmpty {
            let classes = className.split(separator: " ").prefix(2).joined(separator: " ")
            tagText += ".\(classes.replacingOccurrences(of: " ", with: "."))"
        }
        
        tagLabel.text = tagText
        
        // Configure attributes label
        var attributesText = ""
        
        // Add key attributes
        let keyAttributes = ["src", "href", "type", "value", "placeholder", "alt", "title"]
        let displayAttributes = element.attributes.filter { keyAttributes.contains($0.key) }
        
        if !displayAttributes.isEmpty {
            attributesText = displayAttributes.map { "\($0.key)=\"\($0.value.prefix(20))\"" }.joined(separator: " ")
        } else if let textContent = element.textContent, !textContent.isEmpty && textContent.count < 50 {
            attributesText = "\"\(textContent.trimmingCharacters(in: .whitespacesAndNewlines))\""
        }
        
        attributesLabel.text = attributesText
        attributesLabel.isHidden = attributesText.isEmpty
        
        // Configure child count label
        if element.hasChildren && element.childCount > 0 {
            childCountLabel.text = "\(element.childCount)"
            childCountLabel.isHidden = false
        } else {
            childCountLabel.isHidden = true
        }
        
        // Visual feedback for selected state
        if element.selector == (backgroundColor as? UIColor) {
            backgroundColor = UIColor.systemBlue.withAlphaComponent(0.1)
        } else {
            backgroundColor = UIColor.systemBackground
        }
    }
    
    func setSelected(_ element: LazyDOMElement) {
        backgroundColor = UIColor.systemBlue.withAlphaComponent(0.2)
    }
    
    func setDeselected() {
        backgroundColor = UIColor.systemBackground
    }
    
    @objc private func expandButtonTapped() {
        onExpand?()
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        // Reset state
        expandButton.isHidden = false
        expandButton.setTitle("▶", for: .normal)
        expandButton.setTitleColor(UIColor.systemBlue, for: .normal)
        loadingIndicator.stopAnimating()
        loadingIndicator.isHidden = true
        tagLabel.text = ""
        attributesLabel.text = ""
        attributesLabel.isHidden = false
        childCountLabel.text = ""
        childCountLabel.isHidden = true
        backgroundColor = UIColor.systemBackground
        onExpand = nil
        
        // Reset indent constraint
        indentView.constraints.forEach { constraint in
            if constraint.firstAttribute == .width {
                constraint.isActive = false
            }
        }
    }
}