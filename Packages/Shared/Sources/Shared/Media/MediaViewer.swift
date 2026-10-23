#if canImport(UIKit)
import AVFoundation
import AVKit
import SwiftUI
import UIKit
import DesignSystem

/// Full-screen photo and video viewer (the Lamha Ads viewer): swipe between items, pinch or
/// double-tap to zoom a photo, drag down to close, tap to hide the controls. Exactly one video
/// plays: the one on screen.
///
/// Paging uses `UIPageViewController` (the Photos engine) rather than a SwiftUI `TabView`: its
/// pan cooperates with the zoom scroll view and the drag-to-close gesture, where `TabView`
/// fights them and swiping feels sticky.
public struct MediaViewer: View {
    let items: [GalleryItem]
    let onIndexChange: (Int) -> Void

    @State private var index: Int
    @State private var showChrome = true
    @State private var players = PlayerPool()
    @Environment(\.dismiss) private var dismiss

    public init(items: [GalleryItem], startIndex: Int, onIndexChange: @escaping (Int) -> Void = { _ in }) {
        self.items = items
        self.onIndexChange = onIndexChange
        _index = State(initialValue: min(max(0, startIndex), max(0, items.count - 1)))
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            MediaPager(items: items, index: $index, showChrome: $showChrome, players: players,
                       onDismiss: { dismiss() })
                .ignoresSafeArea()
            if showChrome {
                chrome.transition(.opacity)
            }
        }
        .statusBarHidden(true)
        .animation(.easeInOut(duration: 0.2), value: showChrome)
        .onAppear { syncPlayback() }
        .onDisappear { players.pauseAll() }
        .onChange(of: index) { _, newIndex in
            syncPlayback()
            onIndexChange(newIndex)
        }
        .sensoryFeedback(.selection, trigger: index)
        .environment(\.colorScheme, .dark)
    }

    private func syncPlayback() {
        guard items.indices.contains(index), case .video(let video) = items[index] else {
            players.pauseAll()
            return
        }
        players.pauseAll(except: video.url)
        players.play(video.url)
    }

    private var chrome: some View {
        HStack {
            ViewerButton(systemImage: "xmark", label: MediaStrings.close) { dismiss() }
            Spacer()
            if items.count > 1 {
                // Isolated left-to-right so "2 / 5" reads the same in Arabic.
                Text(verbatim: "\u{2066}\(index + 1) / \(items.count)\u{2069}")
                    .font(.dsSubhead.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, DSSpacing.md)
                    .padding(.vertical, DSSpacing.xs)
                    .background(Capsule().fill(.black.opacity(0.45)))
            }
            Spacer()
            ViewerButton(systemImage: "square.and.arrow.up", label: MediaStrings.share) { share() }
        }
        .padding(.horizontal, DSSpacing.lg)
        .padding(.top, DSSpacing.sm)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    private func share() {
        guard items.indices.contains(index) else { return }
        switch items[index] {
        case .image(let url):
            Task {
                let image = await RemoteImageLoading.uiImage(for: url)
                presentShareSheet([image ?? url as Any])
            }
        case .video(let video):
            presentShareSheet([video.url])
        }
    }
}

private struct ViewerButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.dsHeadline)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Circle().fill(.black.opacity(0.45)))
        }
        .accessibilityLabel(label)
    }
}

@MainActor
private func presentShareSheet(_ items: [Any]) {
    let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        .first { $0.activationState == .foregroundActive }
    guard var top = scene?.keyWindow?.rootViewController else { return }
    while let presented = top.presentedViewController { top = presented }
    let sheet = UIActivityViewController(activityItems: items, applicationActivities: nil)
    sheet.popoverPresentationController?.sourceView = top.view
    sheet.popoverPresentationController?.sourceRect = CGRect(x: top.view.bounds.midX, y: 60, width: 1, height: 1)
    top.present(sheet, animated: true)
}

// MARK: - Players

/// One `AVPlayer` per video for the viewer's lifetime. A reference type on purpose: the page
/// controller asks for pages mid-update, and a `@State` dictionary read back stale there would
/// hand out a second player for the same video (sound from one, a frozen frame on the other).
@MainActor
final class PlayerPool {
    private var players: [URL: AVPlayer] = [:]

    func player(for url: URL) -> AVPlayer {
        if let existing = players[url] { return existing }
        let player = AVPlayer(url: url)
        players[url] = player
        return player
    }

    func pauseAll(except url: URL? = nil) {
        for (key, player) in players where key != url { player.pause() }
    }

    /// Plays from the start when the video already finished (`play()` would do nothing).
    func play(_ url: URL) {
        let player = player(for: url)
        if let duration = player.currentItem?.duration, duration.isNumeric,
           player.currentTime() >= CMTimeSubtract(duration, CMTime(seconds: 0.3, preferredTimescale: 600)) {
            player.seek(to: .zero)
        }
        player.play()
    }
}

// MARK: - Pager

private struct MediaPager: UIViewControllerRepresentable {
    let items: [GalleryItem]
    @Binding var index: Int
    @Binding var showChrome: Bool
    let players: PlayerPool
    let onDismiss: () -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pager = UIPageViewController(transitionStyle: .scroll, navigationOrientation: .horizontal,
                                         options: [.interPageSpacing: 16])
        pager.dataSource = context.coordinator
        pager.delegate = context.coordinator
        pager.view.backgroundColor = .black
        if let first = context.coordinator.page(at: index) {
            pager.setViewControllers([first], direction: .forward, animated: false)
        }
        return pager
    }

    func updateUIViewController(_ pager: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        // Only jump when the index changed from outside, not on every redraw.
        guard let current = pager.viewControllers?.first as? MediaPageController, current.index != index,
              let target = context.coordinator.page(at: index) else { return }
        pager.setViewControllers([target], direction: index > current.index ? .forward : .reverse, animated: true)
    }

    @MainActor
    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: MediaPager

        init(parent: MediaPager) { self.parent = parent }

        func page(at index: Int) -> MediaPageController? {
            guard parent.items.indices.contains(index) else { return nil }
            let item = parent.items[index]
            var player: AVPlayer?
            if case .video(let video) = item { player = parent.players.player(for: video.url) }
            return MediaPageController(
                index: index, item: item, player: player,
                onTap: { [weak self] in self?.parent.showChrome.toggle() },
                onDismiss: { [weak self] in self?.parent.onDismiss() })
        }

        func pageViewController(_ pager: UIPageViewController, viewControllerBefore vc: UIViewController) -> UIViewController? {
            (vc as? MediaPageController).flatMap { page(at: $0.index - 1) }
        }

        func pageViewController(_ pager: UIPageViewController, viewControllerAfter vc: UIViewController) -> UIViewController? {
            (vc as? MediaPageController).flatMap { page(at: $0.index + 1) }
        }

        func pageViewController(_ pager: UIPageViewController, didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
            guard completed, let current = pager.viewControllers?.first as? MediaPageController else { return }
            parent.index = current.index
        }
    }
}

// MARK: - Pages

/// One page: a zoomable photo or a video player.
private final class MediaPageController: UIViewController {
    let index: Int
    private let item: GalleryItem
    private let player: AVPlayer?
    private let onTap: () -> Void
    private let onDismiss: () -> Void
    private var playerController: AVPlayerViewController?

    init(index: Int, item: GalleryItem, player: AVPlayer?, onTap: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.index = index
        self.item = item
        self.player = player
        self.onTap = onTap
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        switch item {
        case .image(let url):
            embed(ZoomableImageController(url: url, onTap: onTap, onDismiss: onDismiss))
        case .video:
            let controller = AVPlayerViewController()
            controller.showsPlaybackControls = true
            controller.videoGravity = .resizeAspect
            controller.view.backgroundColor = .black
            embed(controller)
            playerController = controller
            // Drag down closes video pages too (the player's own controls take taps).
            let pan = UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:)))
            pan.delegate = self
            view.addGestureRecognizer(pan)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Attached on appearance, not at build time: an AVPlayer draws into only the controller
        // it was given last, and the pager builds neighbouring pages ahead of time.
        if let player { playerController?.player = player }
    }

    private func embed(_ child: UIViewController) {
        addChild(child)
        view.addSubview(child.view)
        child.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            child.view.topAnchor.constraint(equalTo: view.topAnchor),
            child.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            child.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            child.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        child.didMove(toParent: self)
    }

    @objc private func handleDismissPan(_ pan: UIPanGestureRecognizer) {
        DismissDrag.handle(pan, on: view, onDismiss: onDismiss)
    }
}

extension MediaPageController: UIGestureRecognizerDelegate {
    func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        guard let pan = gesture as? UIPanGestureRecognizer else { return true }
        let velocity = pan.velocity(in: view)
        return velocity.y > abs(velocity.x)
    }
}

/// Drag-to-close shared by photo and video pages: the page follows the finger and fades; a long
/// or fast drag closes, a short one springs back.
@MainActor
private enum DismissDrag {
    static func handle(_ pan: UIPanGestureRecognizer, on view: UIView, onDismiss: () -> Void) {
        let translation = pan.translation(in: view)
        switch pan.state {
        case .changed:
            let progress = min(abs(translation.y) / 300, 1)
            view.transform = CGAffineTransform(translationX: 0, y: translation.y)
            view.alpha = 1 - progress * 0.4
        case .ended, .cancelled:
            if abs(translation.y) > 100 || abs(pan.velocity(in: view).y) > 800 {
                onDismiss()
            } else {
                UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.75, initialSpringVelocity: 0) {
                    view.transform = .identity
                    view.alpha = 1
                }
            }
        default:
            break
        }
    }
}

/// Pinch and double-tap zoom in a `UIScrollView`, like Photos.
private final class ZoomableImageController: UIViewController, UIScrollViewDelegate {
    private let url: URL
    private let onTap: () -> Void
    private let onDismiss: () -> Void
    private let scrollView = UIScrollView()
    private let imageView = UIImageView()
    private let spinner = UIActivityIndicatorView(style: .large)
    private var dismissPan: UIPanGestureRecognizer!

    init(url: URL, onTap: @escaping () -> Void, onDismiss: @escaping () -> Void) {
        self.url = url
        self.onTap = onTap
        self.onDismiss = onDismiss
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { nil }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        scrollView.delegate = self
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 4
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.frame = view.bounds
        scrollView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scrollView)

        imageView.contentMode = .scaleAspectFit
        imageView.isAccessibilityElement = true
        imageView.accessibilityTraits = .image
        scrollView.addSubview(imageView)

        spinner.color = .white
        spinner.center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        spinner.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin, .flexibleTopMargin, .flexibleBottomMargin]
        spinner.startAnimating()
        view.addSubview(spinner)

        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        view.addGestureRecognizer(doubleTap)
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap))
        singleTap.require(toFail: doubleTap)
        view.addGestureRecognizer(singleTap)
        dismissPan = UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:)))
        dismissPan.delegate = self
        view.addGestureRecognizer(dismissPan)

        Task { [weak self, url] in
            let image = await RemoteImageLoading.uiImage(for: url)
            guard let self else { return }
            self.spinner.stopAnimating()
            self.imageView.image = image
            self.layoutImage()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        layoutImage()
    }

    /// Fits the photo to the screen at zoom 1 and centres it.
    private func layoutImage() {
        guard let image = imageView.image, image.size.width > 0, image.size.height > 0 else { return }
        let bounds = scrollView.bounds.size
        guard bounds.width > 0, bounds.height > 0 else { return }
        scrollView.zoomScale = 1
        let scale = min(bounds.width / image.size.width, bounds.height / image.size.height)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        imageView.frame = CGRect(origin: .zero, size: size)
        scrollView.contentSize = size
        centerImage()
    }

    private func centerImage() {
        let bounds = scrollView.bounds.size
        let x = max(0, (bounds.width - imageView.frame.width) / 2)
        let y = max(0, (bounds.height - imageView.frame.height) / 2)
        scrollView.contentInset = UIEdgeInsets(top: y, left: x, bottom: y, right: x)
    }

    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { centerImage() }

    @objc private func handleSingleTap() { onTap() }

    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        if scrollView.zoomScale > 1 {
            scrollView.setZoomScale(1, animated: true)
        } else {
            let point = gesture.location(in: imageView)
            let size = CGSize(width: imageView.bounds.width / 3, height: imageView.bounds.height / 3)
            scrollView.zoom(to: CGRect(x: point.x - size.width / 2, y: point.y - size.height / 2,
                                       width: size.width, height: size.height), animated: true)
        }
    }

    @objc private func handleDismissPan(_ pan: UIPanGestureRecognizer) {
        guard scrollView.zoomScale <= 1.01 else { return }
        DismissDrag.handle(pan, on: view, onDismiss: onDismiss)
    }
}

extension ZoomableImageController: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gesture: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }

    /// Drag-to-close starts only for clearly vertical drags at zoom 1; horizontal ones go to the pager.
    func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
        guard gesture === dismissPan else { return true }
        guard scrollView.zoomScale <= 1.01 else { return false }
        let velocity = dismissPan.velocity(in: view)
        return abs(velocity.y) > abs(velocity.x)
    }
}

// MARK: - Strings

/// Labels for photo and video galleries (also used by features showing their own thumbnails).
public enum MediaStrings {
    public static var close: String { String(localized: "media.close", bundle: .module) }
    public static var share: String { String(localized: "media.share", bundle: .module) }
    public static var openHint: String { String(localized: "media.openHint", bundle: .module) }
    public static var empty: String { String(localized: "media.empty", bundle: .module) }

    public static func photo(_ index: Int, of count: Int) -> String {
        String(format: String(localized: "media.photo", bundle: .module), locale: .current, index, count)
    }

    public static func video(_ index: Int, of count: Int) -> String {
        String(format: String(localized: "media.video", bundle: .module), locale: .current, index, count)
    }
}
#endif
