import SwiftUI
import Core

/// Centered error placeholder driven by a `Core.AppError`, with an optional retry action.
public struct ErrorStateView: View {
    private let error: AppError
    private let retryAction: (() -> Void)?

    public init(error: AppError, retryAction: (() -> Void)? = nil) {
        self.error = error
        self.retryAction = retryAction
    }

    private var isOffline: Bool {
        if case .offline = error { return true }
        if case .network(.noConnection) = error { return true }
        return false
    }

    private var iconName: String { isOffline ? "wifi.slash" : "exclamationmark.triangle" }
    private var titleKey: LocalizedStringKey { isOffline ? "common.error.offline.title" : "common.error.generic.title" }
    private var message: String { error.errorDescription ?? "" }

    public var body: some View {
        VStack(spacing: DSSpacing.md) {
            Image(systemName: iconName)
                .font(.system(size: 34, weight: .regular))
                .foregroundStyle(Color.dsError)
                .frame(width: 88, height: 88)
                .background(Color.dsError.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(spacing: DSSpacing.xxs) {
                Text(titleKey, bundle: .module)
                    .font(.dsTitle2)
                    .foregroundStyle(Color.dsTextPrimary)
                    .multilineTextAlignment(.center)
                Text(message)
                    .font(.dsSubhead)
                    .foregroundStyle(Color.dsTextSecondary)
                    .multilineTextAlignment(.center)
            }

            if let retryAction {
                Button(action: retryAction) {
                    Label { Text("common.tryAgain", bundle: .module) } icon: { Image(systemName: "arrow.clockwise") }
                        .font(.dsHeadline)
                        .foregroundStyle(.white)
                        .frame(height: 50)
                        .padding(.horizontal, DSSpacing.xl)
                        .background(Color.dsPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: DSRadius.button, style: .continuous))
                }
                .accessibilityLabel(Text("common.tryAgain", bundle: .module))
                .accessibilityAddTraits(.isButton)
                .padding(.top, DSSpacing.xs)
            }
        }
        .padding(DSSpacing.xl)
        .accessibilityElement(children: .contain)
    }
}
