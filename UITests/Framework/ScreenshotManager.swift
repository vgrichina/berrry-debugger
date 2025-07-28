import XCTest
import Foundation

class ScreenshotManager {
    private let testResultsPath: String
    
    init() {
        // Create test_results directory in project root
        let projectRoot = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        
        self.testResultsPath = projectRoot.appendingPathComponent("test_results").path
        createTestResultsDirectory()
    }
    
    func takeScreenshot(name: String, testCase: String) {
        let screenshot = XCUIScreen.main.screenshot()
        
        // Add to XCTest attachments (for Xcode test results)
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = "\(testCase)_\(name)"
        attachment.lifetime = .keepAlways
        XCTContext.runActivity(named: "Screenshot: \(name)") { activity in
            activity.add(attachment)
        }
        
        // Save to predictable file path for Claude analysis
        saveToTestResults(screenshot, fileName: "\(testCase)_\(name).png")
        
        print("📸 Screenshot saved: \(testCase)_\(name).png")
    }
    
    private func saveToTestResults(_ screenshot: XCUIScreenshot, fileName: String) {
        let filePath = "\(testResultsPath)/\(fileName)"
        let url = URL(fileURLWithPath: filePath)
        
        do {
            try screenshot.pngRepresentation.write(to: url)
            print("✅ Screenshot saved to: \(filePath)")
        } catch {
            print("❌ Failed to save screenshot: \(error)")
        }
    }
    
    private func createTestResultsDirectory() {
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: testResultsPath) {
            do {
                try fileManager.createDirectory(atPath: testResultsPath, 
                                              withIntermediateDirectories: true, 
                                              attributes: nil)
                print("📁 Created test_results directory: \(testResultsPath)")
            } catch {
                print("❌ Failed to create test_results directory: \(error)")
            }
        }
    }
    
    func listScreenshots() -> [String] {
        let fileManager = FileManager.default
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: testResultsPath)
            return files.filter { $0.hasSuffix(".png") }.sorted()
        } catch {
            print("❌ Failed to list screenshots: \(error)")
            return []
        }
    }
    
    func cleanupOldScreenshots(keepLatest: Int = 50) {
        let fileManager = FileManager.default
        
        do {
            let files = try fileManager.contentsOfDirectory(atPath: testResultsPath)
            let pngFiles = files.filter { $0.hasSuffix(".png") }
            
            if pngFiles.count > keepLatest {
                let filesToDelete = Array(pngFiles.sorted().dropLast(keepLatest))
                
                for file in filesToDelete {
                    let filePath = "\(testResultsPath)/\(file)"
                    try fileManager.removeItem(atPath: filePath)
                }
                
                print("🧹 Cleaned up \(filesToDelete.count) old screenshots")
            }
        } catch {
            print("❌ Failed to cleanup screenshots: \(error)")
        }
    }
    
    func getScreenshotPath(fileName: String) -> String {
        return "\(testResultsPath)/\(fileName)"
    }
}