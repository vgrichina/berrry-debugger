import UIKit

class DOMTreeTableViewCell: UITableViewCell {
    static let identifier = "DOMTreeTableViewCell"
    
    private let indentationGuideView = UIView()
    private let expandCollapseButton = UIButton(type: .system)
    private let elementLabel = UILabel()
    private let selectionIndicator = UIView()
    
    private var domNode: DOMNode?
    private var onExpandCollapse: ((DOMNode) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupViews()
        setupConstraints()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        selectionStyle = .none
        backgroundColor = UIColor.systemBackground
        
        // Indentation guide
        indentationGuideView.backgroundColor = UIColor.systemGray5
        indentationGuideView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(indentationGuideView)
        
        // Expand/Collapse button
        expandCollapseButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        expandCollapseButton.setTitleColor(UIColor.systemBlue, for: .normal)
        expandCollapseButton.addTarget(self, action: #selector(expandCollapseButtonTapped), for: .touchUpInside)
        expandCollapseButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(expandCollapseButton)
        
        // Element label
        elementLabel.font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        elementLabel.textColor = UIColor.label
        elementLabel.numberOfLines = 1
        elementLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(elementLabel)
        
        // Selection indicator
        selectionIndicator.backgroundColor = UIColor.systemYellow.withAlphaComponent(0.3)
        selectionIndicator.layer.cornerRadius = 4
        selectionIndicator.isHidden = true
        selectionIndicator.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(selectionIndicator)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Selection indicator (full width background)
            selectionIndicator.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 2),
            selectionIndicator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            selectionIndicator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -4),
            selectionIndicator.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -2),
            
            // Indentation guide
            indentationGuideView.topAnchor.constraint(equalTo: contentView.topAnchor),
            indentationGuideView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            indentationGuideView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            indentationGuideView.widthAnchor.constraint(equalToConstant: 2),
            
            // Expand/Collapse button
            expandCollapseButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            expandCollapseButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            expandCollapseButton.widthAnchor.constraint(equalToConstant: 20),
            expandCollapseButton.heightAnchor.constraint(equalToConstant: 20),
            
            // Element label
            elementLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            elementLabel.leadingAnchor.constraint(equalTo: expandCollapseButton.trailingAnchor, constant: 4),
            elementLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            
            // Content height
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: 32)
        ])
    }
    
    func configure(with node: DOMNode, isSelected: Bool = false, onExpandCollapse: @escaping (DOMNode) -> Void) {
        self.domNode = node
        self.onExpandCollapse = onExpandCollapse
        
        // Update indentation based on depth
        let indentationWidth = CGFloat(node.depth * 16 + 8)
        expandCollapseButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: indentationWidth).isActive = true
        
        // Update indentation guide
        indentationGuideView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: indentationWidth - 2).isActive = true
        indentationGuideView.isHidden = node.depth == 0
        
        // Configure expand/collapse button
        if node.children.isEmpty {
            expandCollapseButton.setTitle("•", for: .normal)
            expandCollapseButton.isEnabled = false
            expandCollapseButton.alpha = 0.5
        } else {
            expandCollapseButton.setTitle(node.isExpanded ? "▼" : "▶", for: .normal)
            expandCollapseButton.isEnabled = true
            expandCollapseButton.alpha = 1.0
        }
        
        // Configure element label with syntax highlighting
        elementLabel.attributedText = createAttributedText(for: node)
        
        // Update selection state
        selectionIndicator.isHidden = !isSelected
        
        // Update background color based on element type
        switch node.tagName.lowercased() {
        case "html", "head", "body":
            backgroundColor = UIColor.systemGray6
        case "div", "section", "article", "main":
            backgroundColor = UIColor.systemBackground
        default:
            backgroundColor = UIColor.systemBackground
        }
    }
    
    private func createAttributedText(for node: DOMNode) -> NSAttributedString {
        let attributedString = NSMutableAttributedString()
        
        // Tag name
        let tagNameText = NSAttributedString(
            string: node.tagName.lowercased(),
            attributes: [
                .foregroundColor: UIColor.systemPurple,
                .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .semibold)
            ]
        )
        attributedString.append(tagNameText)
        
        // ID attribute
        if let id = node.attributes["id"], !id.isEmpty {
            let idText = NSAttributedString(
                string: "#\(id)",
                attributes: [
                    .foregroundColor: UIColor.systemGreen,
                    .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .medium)
                ]
            )
            attributedString.append(idText)
        }
        
        // Class attribute
        if let className = node.attributes["class"], !className.isEmpty {
            let classes = className.split(separator: " ").prefix(2).joined(separator: ".")
            let classText = NSAttributedString(
                string: ".\(classes)",
                attributes: [
                    .foregroundColor: UIColor.systemOrange,
                    .font: UIFont.monospacedSystemFont(ofSize: 13, weight: .medium)
                ]
            )
            attributedString.append(classText)
        }
        
        // Text content
        if let text = node.textContent?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            let truncatedText = text.count > 30 ? String(text.prefix(30)) + "..." : text
            let textContent = NSAttributedString(
                string: ": \"\(truncatedText)\"",
                attributes: [
                    .foregroundColor: UIColor.systemGray,
                    .font: UIFont.monospacedSystemFont(ofSize: 12, weight: .regular)
                ]
            )
            attributedString.append(textContent)
        }
        
        return attributedString
    }
    
    @objc private func expandCollapseButtonTapped() {
        guard let node = domNode else { return }
        onExpandCollapse?(node)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        domNode = nil
        onExpandCollapse = nil
        selectionIndicator.isHidden = true
        backgroundColor = UIColor.systemBackground
        
        // Remove dynamic constraints
        contentView.constraints.forEach { constraint in
            if constraint.firstItem === expandCollapseButton || constraint.firstItem === indentationGuideView {
                constraint.isActive = false
            }
        }
    }
}