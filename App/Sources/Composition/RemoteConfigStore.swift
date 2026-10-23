import Foundation
import Observation
import Core

/// The app-wide backend-driven config, fetched once at launch (alongside session restore, so
/// there's never a flash of a flag's old/default state before the real value resolves).
@MainActor
@Observable
final class RemoteConfigStore {
    private(set) var config: RemoteConfig?


    /// Fail-closed by design (unlike `isPostAdEnabled`): before the config has loaded — or if the
    /// admin hasn't set `forceUpdate`/a minimum version — this is `false`, so a fresh launch or a
    /// transient fetch failure never blocks the app. Only an explicit, resolved admin decision
    /// ("this build is too old") ever shows the update screen. Same version-compare Lamha Ads used.
    var forceUpdateRequired: Bool {
        guard let update = config?.update,
              update.forceUpdate,
              let minVersion = update.minRequiredVersion,
              let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        else { return false }
        return currentVersion.compare(minVersion, options: .numeric) == .orderedAscending
    }



    /// Admin switch that puts the app in maintenance mode (shows the update/maintenance screen).
    /// Fail-open: an unresolved config never blocks the app.
    var isMaintenanceMode: Bool {
        config?.isFeatureEnabled("maintenanceMode") ?? false
    }

    func update(_ config: RemoteConfig) {
        self.config = config
    }
}
