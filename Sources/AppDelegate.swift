import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        window = UIWindow(frame: UIScreen.main.bounds)
        
        // Embed BrowserViewController in UINavigationController for standard iOS navigation
        let browserViewController = BrowserViewController()
        let navigationController = UINavigationController(rootViewController: browserViewController)
        
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()
        
        // Handle URL if app was launched from URL scheme
        if let url = launchOptions?[UIApplication.LaunchOptionsKey.url] as? URL {
            handleIncomingURL(url)
        }
        
        return true
    }
    
    // Handle URL schemes when app is already running
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        handleIncomingURL(url)
        return true
    }
    
    private func handleIncomingURL(_ url: URL) {
        // Get BrowserViewController from navigation controller
        guard let navigationController = window?.rootViewController as? UINavigationController,
              let browserViewController = navigationController.viewControllers.first as? BrowserViewController else {
            return
        }
        
        // Handle custom URL schemes
        if url.scheme == "berrry-debugger" || url.scheme == "berrry" {
            if let targetURL = extractTargetURL(from: url) {
                browserViewController.loadURL(targetURL)
            }
        }
        // Handle direct URLs shared from other apps
        else if url.scheme == "http" || url.scheme == "https" {
            browserViewController.loadURL(url.absoluteString)
        }
    }
    
    private func extractTargetURL(from url: URL) -> String? {
        // Handle formats like:
        // berrry-debugger://open?url=https%3A//example.com (URL encoded)
        // berrry://https://example.com (direct path)
        
        if let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            // Check for query parameter format (automatically URL decoded by URLComponents)
            if let queryItems = urlComponents.queryItems,
               let targetURL = queryItems.first(where: { $0.name == "url" })?.value {
                return targetURL
            }
            
            // Check for path-based format (berrry://https://example.com)
            let path = url.absoluteString.replacingOccurrences(of: "\(url.scheme!)://", with: "")
            if path.hasPrefix("http://") || path.hasPrefix("https://") {
                return path
            }
        }
        
        return nil
    }
}