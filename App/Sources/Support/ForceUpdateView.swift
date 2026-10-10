import SwiftUI
import DesignSystem
import Core

/// Full-screen, undismissable overlay shown whenever `RemoteConfigStore.forceUpdateRequired` is
/// true — the admin has marked the running build too old to keep using. No back button, no way
/// to reach the tab shell underneath; the only action is opening the App Store listing. Same
/// mechanism previously shipped in the Lamha Ads iOS app, restyled to this app's design system.
struct ForceUpdateView: View {
    let message: String?
    let storeURL: URL?
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: DSSpacing.lg) {
            Spacer(minLength: DSSpacing.xl)

            Circle()
                .fill(Color.dsPrimaryMuted)
                .overlay(
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(Color.dsPrimary)
                )
                .frame(width: 88, height: 88)
                .accessibilityHidden(true)

            VStack(spacing: DSSpacing.xxs) {
                Text(LocalizedStringKey("forceUpdate.title"))
                    .font(.dsTitle2)
                    .foregroundStyle(Color.dsTextPrimary)
                    .multilineTextAlignment(.center)
                Text(message ?? String(localized: "forceUpdate.message"))
                    .font(.dsSubhead)
                    .foregroundStyle(Color.dsTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DSSpacing.xl)

            if let storeURL {
                PrimaryButton(LocalizedStringKey("forceUpdate.action"), systemImage: "arrow.down.circle") {
                    openURL(storeURL)
                }
                .padding(.horizontal, DSSpacing.md)
            }

            Spacer(minLength: DSSpacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.dsBackground)
        .ignoresSafeArea()
    }
}
