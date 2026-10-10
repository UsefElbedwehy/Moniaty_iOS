import SwiftUI

/// A fixed, non-scrolling screen header: a bold title on the left and an optional trailing
/// accessory (a circular icon button, matching the Home location header). Screens use this in
/// place of `navigationTitle`/the native large title bar so every tab shares one clean, custom
/// chrome instead of the system's collapsing title + toolbar.
public struct LargeHeaderBar<Trailing: View>: View {
    private let title: LocalizedStringKey
    private let trailing: Trailing
    /// The bar is screen chrome, not content, so it matches whatever ground its screen painted
    /// rather than staying on the standard surface — otherwise a repainted screen seams against
    /// its own header. Nil on screens that paint their own background directly, which leaves the
    /// bar exactly as it was.
    @Environment(\.dsPaintedGround) private var ground

    public init(_ title: LocalizedStringKey, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.dsTitle1.weight(.bold))
                .foregroundStyle(Color.dsTextPrimary)
            Spacer()
            trailing
        }
        .padding(.horizontal, DSSpacing.md)
        .padding(.top, DSSpacing.xs)
        .padding(.bottom, DSSpacing.sm)
        .background(ground ?? Color.dsSurface)
    }
}

/// A circular icon button matching the Home header's notification-bell style — for header
/// trailing accessories like "add place" or "edit".
public struct HeaderIconButton: View {
    private let systemImage: String
    private let action: () -> Void

    public init(_ systemImage: String, action: @escaping () -> Void) {
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Color.dsTextPrimary)
                .frame(width: 40, height: 40)
                .background(Color.dsSurface, in: Circle())
                .overlay(Circle().strokeBorder(Color.dsBorder, lineWidth: 1))
        }
    }
}
