#if canImport(UIKit)
import SwiftUI
import DesignSystem

/// The photo and video strip at the top of a detail page (as in Lamha Ads): swipe through the
/// items, see "2 / 5" and dots, jump with the thumbnails, and tap to open `MediaViewer`.
public struct MediaGallery: View {
    let items: [GalleryItem]
    let height: CGFloat

    @State private var index = 0
    @State private var viewerOpen = false

    public init(items: [GalleryItem], height: CGFloat = 320) {
        self.items = items
        self.height = height
    }

    public var body: some View {
        VStack(spacing: DSSpacing.xs) {
            ZStack(alignment: .bottom) {
                pager
                if items.count > 1 { indicators }
            }
            .frame(height: height)
            .frame(maxWidth: .infinity)
            .background(Color.dsPrimaryMuted)
            .clipped()

            if items.count > 1 { thumbnails }
        }
        .fullScreenCover(isPresented: $viewerOpen) {
            MediaViewer(items: items, startIndex: index) { index = $0 }
        }
    }

    @ViewBuilder
    private var pager: some View {
        if items.isEmpty {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 44))
                .foregroundStyle(Color.dsPrimary.opacity(0.5))
                .accessibilityLabel(MediaStrings.empty)
        } else {
            TabView(selection: $index) {
                ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                    Button {
                        viewerOpen = true
                    } label: {
                        GalleryTile(item: item, playSize: 64)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(label(item, offset))
                    .accessibilityHint(MediaStrings.openHint)
                    .tag(offset)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .sensoryFeedback(.selection, trigger: index)
        }
    }

    private var indicators: some View {
        HStack {
            counter
            Spacer()
            dots
            Spacer()
            counter.hidden()
        }
        .padding(DSSpacing.md)
        .accessibilityHidden(true)
    }

    private var counter: some View {
        Text(verbatim: "\u{2066}\(index + 1) / \(items.count)\u{2069}")
            .font(.dsCaption.weight(.semibold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, DSSpacing.sm)
            .padding(.vertical, DSSpacing.xxs)
            .background(Capsule().fill(.black.opacity(0.45)))
    }

    private var dots: some View {
        // Long galleries get smaller dots so they still fit.
        let unit: CGFloat = items.count > 12 ? 4 : 6
        return HStack(spacing: unit * 0.8) {
            ForEach(items.indices, id: \.self) { i in
                Capsule()
                    .fill(.white.opacity(i == index ? 1 : 0.45))
                    .frame(width: i == index ? unit * 3 : unit, height: unit)
            }
        }
        .padding(.horizontal, DSSpacing.xs)
        .padding(.vertical, DSSpacing.xxs + 1)
        .background(Capsule().fill(.black.opacity(0.35)))
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: index)
    }

    private var thumbnails: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DSSpacing.xs) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { offset, item in
                        Button {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) { index = offset }
                        } label: {
                            GalleryTile(item: item, playSize: 20)
                                .frame(width: 64, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: DSRadius.control))
                                .overlay {
                                    RoundedRectangle(cornerRadius: DSRadius.control)
                                        .strokeBorder(offset == index ? Color.dsPrimary : .clear, lineWidth: 2)
                                }
                                .opacity(offset == index ? 1 : 0.7)
                        }
                        .buttonStyle(.plain)
                        .id(offset)
                        .accessibilityLabel(label(item, offset))
                        .accessibilityAddTraits(offset == index ? .isSelected : [])
                    }
                }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.vertical, 2)
            }
            .onChange(of: index) { _, newIndex in
                withAnimation(.easeInOut(duration: 0.25)) { proxy.scrollTo(newIndex, anchor: .center) }
            }
        }
    }

    private func label(_ item: GalleryItem, _ offset: Int) -> String {
        switch item {
        case .image: MediaStrings.photo(offset + 1, of: items.count)
        case .video: MediaStrings.video(offset + 1, of: items.count)
        }
    }
}

/// A photo, or a video's poster with a play button and its length (the length shows on large tiles).
public struct GalleryTile: View {
    let item: GalleryItem
    let playSize: CGFloat

    public init(item: GalleryItem, playSize: CGFloat) {
        self.item = item
        self.playSize = playSize
    }

    public var body: some View {
        switch item {
        case .image(let url):
            RemoteImageView(url: url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        case .video(let video):
            ZStack {
                Color.black
                if let poster = video.posterUrl {
                    RemoteImageView(url: poster)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Color.black.opacity(0.25)
                Image(systemName: "play.fill")
                    .font(.system(size: playSize * 0.38))
                    .foregroundStyle(.white)
                    .frame(width: playSize, height: playSize)
                    .background(Circle().fill(.black.opacity(0.55)))
                if playSize > 30, let length = video.durationText {
                    Text(verbatim: length)
                        .font(.dsCaption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                        .padding(.horizontal, DSSpacing.xs)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(.black.opacity(0.55)))
                        .padding(DSSpacing.md)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                }
            }
            .contentShape(Rectangle())
        }
    }
}
#endif
