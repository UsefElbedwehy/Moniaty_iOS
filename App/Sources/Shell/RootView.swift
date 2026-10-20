import SwiftUI
import DesignSystem
import Authentication

/// Picks what the whole window shows: splash while restoring, the landing (role choice) when
/// signed out, then the bride or provider tab shell. Also hosts the force-update gate and the
/// sign-in sheet a guest sees when she taps something that needs an account.
struct RootView: View {
    let environment: AppEnvironment
    /// Light, dark or follow the system, chosen in Profile.
    @AppStorage(Appearance.storageKey) private var appearance: Appearance = .system

    var body: some View {
        @Bindable var session = environment.session
        Group {
            if environment.remoteConfig.forceUpdateRequired || environment.remoteConfig.isMaintenanceMode {
                ForceUpdateView(
                    message: environment.remoteConfig.config?.update.updateMessage,
                    storeURL: environment.remoteConfig.config?.update.storeURL
                )
            } else {
                switch session.state {
                case .checking:
                    SplashView()
                case .signedOut:
                    AuthHost(environment: environment)
                case .signedIn(let user):
                    if user.role == .provider {
                        ProviderShell(environment: environment)
                    } else if user.role == .bride || user.isAnonymous {
                        BrideShell(environment: environment)
                    } else {
                        // Role not known yet (profile still loading).
                        SplashView()
                    }
                }
            }
        }
        .sheet(isPresented: $session.isPresentingAuth) {
            AuthHost(environment: environment)
        }
        .preferredColorScheme(appearance.colorScheme)
        .task {
            async let config: Void = environment.loadRemoteConfig()
            async let strings: Void = environment.loadRemoteStrings()
            async let cities: Void = environment.loadCities()
            _ = await (config, strings, cities)
            await environment.restoreSession()
            environment.analytics(.appOpen)
        }
    }
}

/// The app's color scheme setting (Profile → Appearance).
enum Appearance: String, CaseIterable {
    case system, light, dark

    static let storageKey = "appearance"

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    var titleKey: String { "profile.appearance.\(rawValue)" }
}

/// Owns one `AuthenticationFeature` for as long as it is on screen, so its navigation stack
/// survives re-renders of the parent.
private struct AuthHost: View {
    @State private var feature: AuthenticationFeature

    init(environment: AppEnvironment) {
        _feature = State(initialValue: environment.makeAuthFeature { state in
            Task { @MainActor in await environment.authFinished(state) }
        })
    }

    var body: some View {
        feature.rootView()
    }
}

/// Brief branded screen while the session is restored.
struct SplashView: View {
    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            DSBrand.wordmark
                .resizable()
                .scaledToFit()
                .frame(height: 160)
                .accessibilityLabel(L10n.string("app.name"))
            ProgressView()
                .tint(Color.dsPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dsScreenBackground()
    }
}
