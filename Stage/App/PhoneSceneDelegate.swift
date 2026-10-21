import SwiftUI
import UIKit

final class PhoneSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var host: PhoneHostController?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let model = StageModel.shared
        let host = PhoneHostController()
        host.overrideUserInterfaceStyle = .dark
        host.view.backgroundColor = ThemeUI.background
        let window = UIWindow(windowScene: windowScene)
        window.overrideUserInterfaceStyle = .dark
        window.rootViewController = host
        window.backgroundColor = ThemeUI.background
        self.window = window
        self.host = host
        window.makeKeyAndVisible()

        model.onPresentationChange = { [weak host] in
            host?.applyOrientation()
        }
        model.start()
        open(connectionOptions.urlContexts.map(\.url))
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        open(URLContexts.map(\.url))
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        StageModel.shared.savePreferences()
        StageModel.shared.library.flush()
    }

    private func open(_ urls: [URL]) {
        for url in urls where url.scheme == "stage" && url.host == "recenter" {
            StageModel.shared.recenter()
        }
    }
}

final class PhoneHostController: UIHostingController<PhoneHosted> {
    init() {
        super.init(rootView: PhoneHosted())
    }

    required init?(coder: NSCoder) {
        fatalError("Stage does not load phone UI from a storyboard")
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        StageModel.shared.prefersLandscape ? .landscape : .portrait
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        .lightContent
    }

    override var prefersStatusBarHidden: Bool {
        StageModel.shared.prefersLandscape
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        StageModel.shared.prefersLandscape
    }

    func applyOrientation() {
        setNeedsUpdateOfSupportedInterfaceOrientations()
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        guard let scene = view.window?.windowScene else { return }
        let mask: UIInterfaceOrientationMask = StageModel.shared.prefersLandscape ? .landscape : .portrait
        scene.requestGeometryUpdate(UIWindowScene.GeometryPreferences.iOS(interfaceOrientations: mask))
    }
}
