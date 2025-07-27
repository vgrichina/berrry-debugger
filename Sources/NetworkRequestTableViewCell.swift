import UIKit

class NetworkRequestTableViewCell: UITableViewCell {
    static let identifier = "NetworkRequestTableViewCell"
    
    private let typeIconLabel = UILabel()
    private let urlLabel = UILabel()
    private let methodLabel = UILabel()
    private let statusLabel = UILabel()
    private let sizeLabel = UILabel()
    private let durationLabel = UILabel()
    private let expandButton = UIButton(type: .system)
    private let detailContainerView = UIView()
    private let detailStackView = UIStackView()
    
    private var networkRequest: NetworkRequestModel?
    private var isExpanded = false
    private var onExpandToggle: ((NetworkRequestModel) -> Void)?
    
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
        
        // Type icon
        typeIconLabel.font = UIFont.systemFont(ofSize: 16)
        typeIconLabel.textAlignment = .center
        typeIconLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(typeIconLabel)
        
        // URL label
        urlLabel.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        urlLabel.textColor = UIColor.label
        urlLabel.numberOfLines = 2
        urlLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(urlLabel)
        
        // Method label
        methodLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        methodLabel.textColor = UIColor.secondaryLabel
        methodLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(methodLabel)
        
        // Status label
        statusLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        statusLabel.textAlignment = .center
        statusLabel.layer.cornerRadius = 8
        statusLabel.layer.masksToBounds = true
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(statusLabel)
        
        // Size label
        sizeLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        sizeLabel.textColor = UIColor.secondaryLabel
        sizeLabel.textAlignment = .right
        sizeLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(sizeLabel)
        
        // Duration label
        durationLabel.font = UIFont.systemFont(ofSize: 11, weight: .regular)
        durationLabel.textColor = UIColor.secondaryLabel
        durationLabel.textAlignment = .right
        durationLabel.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(durationLabel)
        
        // Expand button
        expandButton.titleLabel?.font = UIFont.systemFont(ofSize: 12)
        expandButton.setTitleColor(UIColor.systemBlue, for: .normal)
        expandButton.addTarget(self, action: #selector(expandButtonTapped), for: .touchUpInside)
        expandButton.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(expandButton)
        
        // Detail container
        detailContainerView.backgroundColor = UIColor.systemGray6
        detailContainerView.layer.cornerRadius = 8
        detailContainerView.isHidden = true
        detailContainerView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(detailContainerView)
        
        // Detail stack view
        detailStackView.axis = .vertical
        detailStackView.spacing = 8
        detailStackView.distribution = .fill
        detailStackView.translatesAutoresizingMaskIntoConstraints = false
        detailContainerView.addSubview(detailStackView)
    }
    
    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // Type icon
            typeIconLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            typeIconLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            typeIconLabel.widthAnchor.constraint(equalToConstant: 24),
            typeIconLabel.heightAnchor.constraint(equalToConstant: 20),
            
            // URL label
            urlLabel.leadingAnchor.constraint(equalTo: typeIconLabel.trailingAnchor, constant: 8),
            urlLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            urlLabel.trailingAnchor.constraint(equalTo: statusLabel.leadingAnchor, constant: -8),
            
            // Method label
            methodLabel.leadingAnchor.constraint(equalTo: urlLabel.leadingAnchor),
            methodLabel.topAnchor.constraint(equalTo: urlLabel.bottomAnchor, constant: 2),
            methodLabel.widthAnchor.constraint(equalToConstant: 40),
            
            // Status label
            statusLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            statusLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            statusLabel.widthAnchor.constraint(equalToConstant: 45),
            statusLabel.heightAnchor.constraint(equalToConstant: 20),
            
            // Size label
            sizeLabel.trailingAnchor.constraint(equalTo: statusLabel.trailingAnchor),
            sizeLabel.topAnchor.constraint(equalTo: statusLabel.bottomAnchor, constant: 2),
            sizeLabel.widthAnchor.constraint(equalToConstant: 45),
            
            // Duration label
            durationLabel.trailingAnchor.constraint(equalTo: statusLabel.trailingAnchor),
            durationLabel.topAnchor.constraint(equalTo: sizeLabel.bottomAnchor, constant: 2),
            durationLabel.widthAnchor.constraint(equalToConstant: 45),
            
            // Expand button
            expandButton.leadingAnchor.constraint(equalTo: methodLabel.trailingAnchor, constant: 8),
            expandButton.centerYAnchor.constraint(equalTo: methodLabel.centerYAnchor),
            expandButton.widthAnchor.constraint(equalToConstant: 60),
            
            // Detail container
            detailContainerView.topAnchor.constraint(equalTo: durationLabel.bottomAnchor, constant: 8),
            detailContainerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            detailContainerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            detailContainerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            
            // Detail stack view
            detailStackView.topAnchor.constraint(equalTo: detailContainerView.topAnchor, constant: 12),
            detailStackView.leadingAnchor.constraint(equalTo: detailContainerView.leadingAnchor, constant: 12),
            detailStackView.trailingAnchor.constraint(equalTo: detailContainerView.trailingAnchor, constant: -12),
            detailStackView.bottomAnchor.constraint(equalTo: detailContainerView.bottomAnchor, constant: -12)
        ])
    }
    
    func configure(with request: NetworkRequestModel, isExpanded: Bool, onExpandToggle: @escaping (NetworkRequestModel) -> Void) {
        self.networkRequest = request
        self.isExpanded = isExpanded
        self.onExpandToggle = onExpandToggle
        
        // Configure main content
        typeIconLabel.text = request.resourceType.emoji
        
        // Format URL for display
        let displayURL = formatURLForDisplay(request.url)
        urlLabel.text = displayURL
        
        methodLabel.text = request.method
        
        // Configure status
        statusLabel.text = request.status == 0 ? "..." : "\(request.status)"
        let statusColor = getStatusColor(request.statusColor)
        statusLabel.backgroundColor = statusColor.withAlphaComponent(0.2)
        statusLabel.textColor = statusColor
        
        sizeLabel.text = request.formattedSize
        durationLabel.text = request.formattedDuration
        
        // Configure expand button
        expandButton.setTitle(isExpanded ? "Less ▲" : "More ▼", for: .normal)
        
        // Configure detail view
        detailContainerView.isHidden = !isExpanded
        if isExpanded {
            setupDetailView(for: request)
        }
    }
    
    private func formatURLForDisplay(_ url: String) -> String {
        guard let urlComponents = URLComponents(string: url) else { return url }
        
        let host = urlComponents.host ?? "unknown"
        let path = urlComponents.path
        
        if path.isEmpty || path == "/" {
            return host
        }
        
        // Show last path component for brevity
        let pathComponents = path.split(separator: "/")
        if let lastComponent = pathComponents.last {
            return "\(host)/\(lastComponent)"
        }
        
        return "\(host)\(path)"
    }
    
    private func getStatusColor(_ statusColor: NetworkStatusColor) -> UIColor {
        switch statusColor {
        case .pending: return UIColor.systemGray
        case .success: return UIColor.systemGreen
        case .redirect: return UIColor.systemBlue
        case .clientError: return UIColor.systemOrange
        case .serverError: return UIColor.systemRed
        }
    }
    
    private func setupDetailView(for request: NetworkRequestModel) {
        // Clear existing views
        detailStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        
        // Headers section
        if !request.headers.isEmpty {
            let headersSection = createDetailSection(
                title: "📋 Request Headers",
                content: formatHeaders(request.headers)
            )
            detailStackView.addArrangedSubview(headersSection)
        }
        
        // Response headers section
        if !request.responseHeaders.isEmpty {
            let responseSection = createDetailSection(
                title: "📦 Response Headers", 
                content: formatHeaders(request.responseHeaders)
            )
            detailStackView.addArrangedSubview(responseSection)
        }
        
        // Timing section
        let timingContent = """
        Started: \(formatTimestamp(request.timestamp))
        Duration: \(request.formattedDuration)
        Size: \(request.formattedSize)
        """
        
        let timingSection = createDetailSection(
            title: "⏱️ Timing",
            content: timingContent
        )
        detailStackView.addArrangedSubview(timingSection)
    }
    
    private func createDetailSection(title: String, content: String) -> UIView {
        let container = UIView()
        
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = UIFont.systemFont(ofSize: 12, weight: .semibold)
        titleLabel.textColor = UIColor.label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let contentLabel = UILabel()
        contentLabel.text = content
        contentLabel.font = UIFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        contentLabel.textColor = UIColor.secondaryLabel
        contentLabel.numberOfLines = 0
        contentLabel.translatesAutoresizingMaskIntoConstraints = false
        
        container.addSubview(titleLabel)
        container.addSubview(contentLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            
            contentLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            contentLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            contentLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            contentLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    private func formatHeaders(_ headers: [String: String]) -> String {
        return headers.map { "\($0.key): \($0.value)" }.joined(separator: "\n")
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter.string(from: date)
    }
    
    @objc private func expandButtonTapped() {
        guard let request = networkRequest else { return }
        onExpandToggle?(request)
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        networkRequest = nil
        onExpandToggle = nil
        detailContainerView.isHidden = true
        detailStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
    }
}