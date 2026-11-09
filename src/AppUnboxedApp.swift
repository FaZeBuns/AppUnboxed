import UIKit
import SwiftUI

@main
@objc(AppDelegate)
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // The scene delegate normally builds the UI. Creating a second window
        // here as well made two ContentViews fight over the unfold callback,
        // so this fallback now only runs if no scene ever connects.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self, self.window == nil else { return }
            let hasSceneWindow = application.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .contains { !$0.windows.isEmpty }
            guard !hasSceneWindow else { return }
            let win = UIWindow(frame: UIScreen.main.bounds)
            win.backgroundColor = .black
            win.rootViewController = FullScreenHostingController(rootView: ContentView())
            self.window = win
            win.makeKeyAndVisible()
        }
        return true
    }

    // MARK: - UISceneSession Lifecycle (Modern Dynamic iPad & Duo Dual-Screen)
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

@objc(SceneDelegate)
class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // Use the native windowScene bounds to guarantee 100% full resolution with zero margins
        let win = UIWindow(windowScene: windowScene)
        win.backgroundColor = .black

        let hostingController = FullScreenHostingController(rootView: ContentView())
        win.rootViewController = hostingController
        self.window = win
        win.makeKeyAndVisible()
        DebugHarness.start(window: win)

        // Feed initial scene bounds
        let bounds = windowScene.coordinateSpace.bounds
        DuoHingeSensor.shared.evaluateGeometry(width: bounds.width, height: bounds.height)
    }

    func windowScene(
        _ windowScene: UIWindowScene,
        didUpdate previousCoordinateSpace: UICoordinateSpace,
        interfaceOrientation previousInterfaceOrientation: UIInterfaceOrientation,
        traitCollection previousTraitCollection: UITraitCollection
    ) {
        // Feed live hardware window resize directly to DuoHingeSensor
        let bounds = windowScene.coordinateSpace.bounds
        DuoHingeSensor.shared.evaluateGeometry(width: bounds.width, height: bounds.height)
    }
}

/// Custom UIHostingController that enforces true edge-to-edge rendering across 100% of display
class FullScreenHostingController<Content: View>: UIHostingController<Content> {
    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }

    // No viewDidLayoutSubviews override: feeding the hinge sensor from inside
    // a layout pass re-triggered SwiftUI layout forever (100% CPU, black
    // screen). Geometry reaches the sensor from the scene's didUpdate callback
    // and ContentView's onChange(of: geo.size), both of which run outside layout.
}
