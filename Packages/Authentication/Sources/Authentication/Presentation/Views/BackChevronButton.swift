import SwiftUI
import DesignSystem

/// The circular back chevron used by the phone and OTP screens (design: a 40pt pill on a muted
/// surface). A real 44pt hit target, VoiceOver-labelled, and mirrors automatically in RTL via
/// SwiftUI's `chevron.backward` semantic image.
struct BackChevronButton: View {
    @Environment(\.dsRaisedSurface) private var raisedSurface

    let action: () -> Void

    private let circleSize: CGFloat = 40
    private let hitTarget: CGFloat = 44

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.backward")
                .font(.dsHeadline)
                .foregroundStyle(Color.dsPrimary)
                .frame(width: circleSize, height: circleSize)
                .background(raisedSurface ?? Color.dsElevated, in: Circle())
                .frame(width: hitTarget, height: hitTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(AuthL10n.string("auth.common.back"))
    }
}
