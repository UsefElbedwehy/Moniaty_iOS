import SwiftUI

/// Custom paging indicator matching the design's pill/dot cluster: the active page renders as
/// a wide rounded bar, inactive pages as small dots. Used instead of the native `TabView` page
/// dots, which read as a plain system control rather than a designed element.
public struct CarouselPageIndicator: View {
    private let count: Int
    private let index: Int
    private let tint: Color

    public init(count: Int, index: Int, tint: Color = .white) {
        self.count = count
        self.index = index
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { page in
                Capsule()
                    .fill(page == index ? tint : tint.opacity(0.55))
                    .frame(width: page == index ? 16 : 5, height: 5)
                    .animation(.easeInOut(duration: 0.25), value: index)
            }
        }
    }
}
