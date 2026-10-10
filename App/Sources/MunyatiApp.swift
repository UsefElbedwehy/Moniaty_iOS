import SwiftUI
import DesignSystem
import Shared

@main
struct MunyatiApp: App {
    /// Firebase setup and APNs callbacks need a classic app delegate.
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    /// The composition root, created once for the app's lifetime.
    @State private var environment = AppEnvironment()

    init() {
        DSFonts.register()
    }

    var body: some Scene {
        WindowGroup {
            RootView(environment: environment)
                .tint(Color.dsPrimary)
                .environment(\.analytics, environment.analytics)
                .onOpenURL { environment.open(url: $0) }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL { environment.open(url: url) }
                }
                .task {
                    environment.bindPush(appDelegate.pushService)
                    if ProcessInfo.processInfo.environment["UITEST_NO_PUSH"] != "1" {
                        await appDelegate.pushService.requestAuthorizationAndRegister()
                    }
                }
        }
    }
}
