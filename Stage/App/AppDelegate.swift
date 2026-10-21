import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        true
    }

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        if connectingSceneSession.role == .windowExternalDisplayNonInteractive {
            let configuration = UISceneConfiguration(name: "Glasses", sessionRole: connectingSceneSession.role)
            configuration.delegateClass = GlassesSceneDelegate.self
            return configuration
        }
        let configuration = UISceneConfiguration(name: "Phone", sessionRole: connectingSceneSession.role)
        configuration.delegateClass = PhoneSceneDelegate.self
        return configuration
    }
}
