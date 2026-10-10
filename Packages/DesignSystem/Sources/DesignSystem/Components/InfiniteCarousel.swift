import SwiftUI

extension View {
    /// `.tabViewStyle(.page(indexDisplayMode: .never))` is iOS-only; this no-ops on the macOS
    /// host so the package still builds for `swift test`.
    @ViewBuilder
    fileprivate func pageStyleNoIndex() -> some View {
        #if os(iOS)
        self.tabViewStyle(.page(indexDisplayMode: .never))
        #else
        self
        #endif
    }
}

/// A paged carousel that loops seamlessly (last → first, first → last) and advances on its own
/// on a timer, with a custom pill indicator instead of the native page dots. Manual swipes work
/// as normal; looping is done by padding the real pages with a clone of the last/first item at
/// each end and silently snapping back once the swipe animation lands on a clone.
public struct InfiniteCarousel<Item: Identifiable, Content: View>: View {
    private let items: [Item]
    private let autoScrollInterval: Duration?
    private let indicatorTint: Color
    private let indicatorPadding: CGFloat
    private let showsBuiltInIndicator: Bool
    private let onDisplayedIndexChange: ((Int) -> Void)?
    private let content: (Item) -> Content

    @State private var selection: Int
    @State private var autoScrollTask: Task<Void, Never>?

    public init(
        items: [Item],
        autoScrollInterval: Duration? = .seconds(4),
        indicatorTint: Color = .white,
        indicatorPadding: CGFloat = 12,
        showsBuiltInIndicator: Bool = true,
        onDisplayedIndexChange: ((Int) -> Void)? = nil,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.autoScrollInterval = autoScrollInterval
        self.indicatorTint = indicatorTint
        self.indicatorPadding = indicatorPadding
        self.showsBuiltInIndicator = showsBuiltInIndicator
        self.onDisplayedIndexChange = onDisplayedIndexChange
        self.content = content
        _selection = State(initialValue: items.count > 1 ? 1 : 0)
    }

    /// `[last, item0, item1, …, itemN-1, first]` when looping is possible, else the plain items.
    private var loopItems: [Item] {
        guard items.count > 1, let first = items.first, let last = items.last else { return items }
        return [last] + items + [first]
    }

    /// The real (non-sentinel) index the indicator should reflect for the current `selection`.
    private var displayedIndex: Int {
        guard items.count > 1 else { return 0 }
        if selection <= 0 { return items.count - 1 }
        if selection >= loopItems.count - 1 { return 0 }
        return selection - 1
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selection) {
                ForEach(Array(loopItems.enumerated()), id: \.offset) { index, item in
                    content(item).tag(index)
                }
            }
            .pageStyleNoIndex()
            .onChange(of: selection) { _, newValue in
                snapIfNeeded(newValue)
                onDisplayedIndexChange?(displayedIndex)
            }

            if showsBuiltInIndicator, items.count > 1 {
                CarouselPageIndicator(count: items.count, index: displayedIndex, tint: indicatorTint)
                    .padding(indicatorPadding)
            }
        }
        .onAppear {
            startAutoScroll()
            onDisplayedIndexChange?(displayedIndex)
        }
        .onDisappear {
            autoScrollTask?.cancel()
            autoScrollTask = nil
        }
    }

    /// After the swipe animation lands on a cloned sentinel page, jump to the matching real
    /// page with no animation — since the clone is pixel-identical to that real page, the jump
    /// is invisible and the loop feels continuous.
    private func snapIfNeeded(_ newValue: Int) {
        guard items.count > 1 else { return }
        if newValue == 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                // Only apply the reset if the user (or auto-scroll) hasn't already moved on from
                // this sentinel in the meantime — otherwise this stale write would clobber
                // wherever they swiped to next.
                guard selection == 0 else { return }
                selection = items.count
            }
        } else if newValue == loopItems.count - 1 {
            let sentinelIndex = loopItems.count - 1
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                guard selection == sentinelIndex else { return }
                selection = 1
            }
        }
    }

    private func startAutoScroll() {
        guard items.count > 1, let interval = autoScrollInterval else { return }
        autoScrollTask?.cancel()
        autoScrollTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        selection += 1
                    }
                }
            }
        }
    }
}
