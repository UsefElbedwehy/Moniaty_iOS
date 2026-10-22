import SwiftUI
import DesignSystem
import Shared
import Core

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
                // Date pickers follow the same Gregorian calendar as every date on screen.
                .environment(\.calendar, .display)
                .onOpenURL { environment.open(url: $0) }
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    if let url = activity.webpageURL { environment.open(url: url) }
                }
                .task {
                    environment.bindPush(appDelegate.pushService)
                    // UI-test hook: `UITEST_OPEN_URL=munyati://s/<id>` opens that link at launch
                    // (no "Open in Munyati?" prompt, which simctl openurl shows).
                    if let raw = ProcessInfo.processInfo.environment["UITEST_OPEN_URL"], let url = URL(string: raw) {
                        environment.open(url: url)
                    }
                    if ProcessInfo.processInfo.environment["UITEST_NO_PUSH"] != "1" {
                        await appDelegate.pushService.requestAuthorizationAndRegister()
                    }
                }
        }
    }
}
