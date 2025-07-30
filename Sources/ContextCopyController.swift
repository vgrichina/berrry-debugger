import UIKit

protocol ContextCopyControllerDelegate: AnyObject {
    func contextCopyController(_ controller: ContextCopyController, didRequestDOMExtraction completion: @escaping (String?) -> Void)
    func contextCopyController(_ controller: ContextCopyController, didRequestCSSExtraction completion: @escaping (String?) -> Void)
    func contextCopyControllerDidRequestConsoleLogs(_ controller: ContextCopyController) -> [String]
    func contextCopyControllerDidRequestNetworkLogs(_ controller: ContextCopyController) -> [NetworkRequestModel]
}

class ContextCopyController: NSObject {
    
    weak var delegate: ContextCopyControllerDelegate?
    
    private var selectedContextTypes: Set<ContextType> = [.selectedElement]
    private var selectedFormat: ContextFormat = .json
    private var promptTemplate: String = "Debug this: {context}"
    
    func showContextCopyOptions(from viewController: UIViewController) {
        // Show the sophisticated alert-based interface with checkboxes and options
        showLegacyContextSelector(from: viewController)
    }
    
    private func showLegacyContextSelector(from viewController: UIViewController) {
        let alertController = UIAlertController(
            title: "Select Context to Copy",
            message: nil,
            preferredStyle: .actionSheet
        )
        
        // Context Type Selection
        let fullDOMAction = UIAlertAction(title: "Full DOM", style: .default) { [weak self] _ in
            self?.toggleContextType(.fullDOM)
            self?.showLegacyContextSelector(from: viewController)
        }
        fullDOMAction.setValue(selectedContextTypes.contains(.fullDOM), forKey: "checked")
        
        let selectedElementAction = UIAlertAction(title: "Selected Element", style: .default) { [weak self] _ in
            self?.toggleContextType(.selectedElement)
            self?.showLegacyContextSelector(from: viewController)
        }
        selectedElementAction.setValue(selectedContextTypes.contains(.selectedElement), forKey: "checked")
        
        let cssAction = UIAlertAction(title: "CSS", style: .default) { [weak self] _ in
            self?.toggleContextType(.css)
            self?.showLegacyContextSelector(from: viewController)
        }
        cssAction.setValue(selectedContextTypes.contains(.css), forKey: "checked")
        
        let networkAction = UIAlertAction(title: "Network Logs", style: .default) { [weak self] _ in
            self?.toggleContextType(.networkLogs)
            self?.showLegacyContextSelector(from: viewController)
        }
        networkAction.setValue(selectedContextTypes.contains(.networkLogs), forKey: "checked")
        
        let consoleAction = UIAlertAction(title: "Console Logs", style: .default) { [weak self] _ in
            self?.toggleContextType(.consoleLogs)
            self?.showLegacyContextSelector(from: viewController)
        }
        consoleAction.setValue(selectedContextTypes.contains(.consoleLogs), forKey: "checked")
        
        alertController.addAction(fullDOMAction)
        alertController.addAction(selectedElementAction)
        alertController.addAction(cssAction)
        alertController.addAction(networkAction)
        alertController.addAction(consoleAction)
        
        // Format Selection
        let formatAction = UIAlertAction(title: "Format: \(selectedFormat == .json ? "JSON" : "Plain Text")", style: .default) { [weak self] _ in
            self?.toggleFormat()
            self?.showContextCopyOptions(from: viewController)
        }
        alertController.addAction(formatAction)
        
        // Prompt Template
        let promptAction = UIAlertAction(title: "Edit Prompt Template", style: .default) { [weak self] _ in
            self?.showPromptEditor(from: viewController)
        }
        alertController.addAction(promptAction)
        
        // Actions
        let previewAction = UIAlertAction(title: "Preview", style: .default) { [weak self] _ in
            self?.showPreview(from: viewController)
        }
        
        let copyAction = UIAlertAction(title: "Copy", style: .default) { [weak self] _ in
            self?.copyContext(from: viewController)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alertController.addAction(previewAction)
        alertController.addAction(copyAction)
        alertController.addAction(cancelAction)
        
        // Handle iPad presentation
        if let popover = alertController.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(x: viewController.view.bounds.midX, y: viewController.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        viewController.present(alertController, animated: true)
    }
    
    private func toggleContextType(_ type: ContextType) {
        if selectedContextTypes.contains(type) {
            selectedContextTypes.remove(type)
        } else {
            selectedContextTypes.insert(type)
        }
    }
    
    private func toggleFormat() {
        selectedFormat = selectedFormat == .json ? .plainText : .json
    }
    
    private func showPromptEditor(from viewController: UIViewController) {
        let alertController = UIAlertController(
            title: "Edit Prompt Template",
            message: "Use {context} placeholder for the extracted data",
            preferredStyle: .alert
        )
        
        alertController.addTextField { textField in
            textField.text = self.promptTemplate
            textField.placeholder = "Debug this: {context}"
        }
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            if let text = alertController.textFields?.first?.text, !text.isEmpty {
                self?.promptTemplate = text
                
                // Save to UserDefaults
                UserDefaults.standard.set(text, forKey: "PromptTemplate")
            }
            self?.showContextCopyOptions(from: viewController)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel) { [weak self] _ in
            self?.showContextCopyOptions(from: viewController)
        }
        
        alertController.addAction(saveAction)
        alertController.addAction(cancelAction)
        
        viewController.present(alertController, animated: true)
    }
    
    private func showPreview(from viewController: UIViewController) {
        extractContext { [weak self] contextData in
            DispatchQueue.main.async {
                let content = self?.selectedFormat == .json ? contextData.toJSON() : contextData.toPlainText()
                let finalContent = self?.promptTemplate.replacingOccurrences(of: "{context}", with: content) ?? content
                
                let alertController = UIAlertController(
                    title: "Context Preview",
                    message: String(finalContent.prefix(500)) + (finalContent.count > 500 ? "..." : ""),
                    preferredStyle: .alert
                )
                
                let backAction = UIAlertAction(title: "Back", style: .default) { _ in
                    self?.showContextCopyOptions(from: viewController)
                }
                
                let copyAction = UIAlertAction(title: "Copy", style: .default) { _ in
                    UIPasteboard.general.string = finalContent
                    self?.showSuccessAlert(from: viewController)
                }
                
                alertController.addAction(backAction)
                alertController.addAction(copyAction)
                
                viewController.present(alertController, animated: true)
            }
        }
    }
    
    private func copyContext(from viewController: UIViewController) {
        extractContext { [weak self] contextData in
            DispatchQueue.main.async {
                let content = self?.selectedFormat == .json ? contextData.toJSON() : contextData.toPlainText()
                let finalContent = self?.promptTemplate.replacingOccurrences(of: "{context}", with: content) ?? content
                
                // Limit to 100KB to avoid clipboard issues
                let limitedContent = String(finalContent.prefix(100_000))
                UIPasteboard.general.string = limitedContent
                
                self?.showSuccessAlert(from: viewController)
            }
        }
    }
    
    private func extractContext(completion: @escaping (ContextData) -> Void) {
        var contextData = ContextData(html: nil, css: nil, networkLogs: [], consoleLogs: [])
        
        let dispatchGroup = DispatchGroup()
        
        // Extract HTML if needed
        if selectedContextTypes.contains(.fullDOM) || selectedContextTypes.contains(.selectedElement) {
            dispatchGroup.enter()
            delegate?.contextCopyController(self, didRequestDOMExtraction: { html in
                contextData = ContextData(
                    html: html,
                    css: contextData.css,
                    networkLogs: contextData.networkLogs,
                    consoleLogs: contextData.consoleLogs
                )
                dispatchGroup.leave()
            })
        }
        
        // Extract CSS if needed
        if selectedContextTypes.contains(.css) {
            dispatchGroup.enter()
            delegate?.contextCopyController(self, didRequestCSSExtraction: { css in
                contextData = ContextData(
                    html: contextData.html,
                    css: css,
                    networkLogs: contextData.networkLogs,
                    consoleLogs: contextData.consoleLogs
                )
                dispatchGroup.leave()
            })
        }
        
        // Add console logs if needed
        if selectedContextTypes.contains(.consoleLogs) {
            let logs = delegate?.contextCopyControllerDidRequestConsoleLogs(self) ?? []
            contextData = ContextData(
                html: contextData.html,
                css: contextData.css,
                networkLogs: contextData.networkLogs,
                consoleLogs: logs
            )
        }
        
        // Add network logs if needed
        if selectedContextTypes.contains(.networkLogs) {
            let requests = delegate?.contextCopyControllerDidRequestNetworkLogs(self) ?? []
            contextData = ContextData(
                html: contextData.html,
                css: contextData.css,
                networkLogs: requests,
                consoleLogs: contextData.consoleLogs
            )
        }
        
        dispatchGroup.notify(queue: .main) {
            completion(contextData)
        }
    }
    
    private func showSuccessAlert(from viewController: UIViewController) {
        let alertController = UIAlertController(
            title: "Copied!",
            message: "Context has been copied to clipboard. You can now paste it into your LLM (e.g., Grok at x.ai/grok)",
            preferredStyle: .alert
        )
        
        let okAction = UIAlertAction(title: "OK", style: .default)
        alertController.addAction(okAction)
        
        viewController.present(alertController, animated: true)
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        loadSettings()
    }
    
    private func loadSettings() {
        if let savedPrompt = UserDefaults.standard.string(forKey: "PromptTemplate") {
            promptTemplate = savedPrompt
        }
    }
}