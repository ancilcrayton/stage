import UIKit

final class GlassesSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let controller = TheaterViewController()
        controller.isExternalDisplay = true
        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = controller
        window.backgroundColor = .black
        self.window = window
        window.makeKeyAndVisible()
        StageModel.shared.setGlassesConnected(true)
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        StageModel.shared.setGlassesConnected(false)
    }
}
