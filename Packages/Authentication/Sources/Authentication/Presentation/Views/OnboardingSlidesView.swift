import SwiftUI
import DesignSystem

/// The three intro slides shown once, before the role choice: discover, book, pay. Content is
/// bundled (ar + en). "Skip" and the last slide's button both call `onFinish`.
struct OnboardingSlidesView: View {
    let onFinish: () -> Void

    @State private var page = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private struct Slide {
        let systemImage: String
        let key: String
    }

    private let slides = [
        Slide(systemImage: "sparkles", key: "auth.slides.discover"),
        Slide(systemImage: "calendar.badge.clock", key: "auth.slides.book"),
        Slide(systemImage: "banknote", key: "auth.slides.pay"),
    ]

    private var isLast: Bool { page == slides.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: onFinish) {
                    AuthL10n.text("auth.slides.skip")
                        .font(.dsHeadline)
                        .foregroundStyle(Color.dsPrimary)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .opacity(isLast ? 0 : 1)
                .disabled(isLast)
            }
            .padding(.horizontal, DSSpacing.xl)
            .padding(.top, DSSpacing.sm)

            TabView(selection: $page) {
                ForEach(Array(slides.enumerated()), id: \.offset) { index, slide in
                    slideView(slide).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            HStack(spacing: DSSpacing.xs) {
                ForEach(slides.indices, id: \.self) { index in
                    Capsule()
                        .fill(index == page ? Color.dsPrimary : Color.dsBorder)
                        .frame(width: index == page ? 24 : 8, height: 8)
                }
            }
            .accessibilityHidden(true)
            .padding(.bottom, DSSpacing.lg)

            PrimaryButton(AuthL10n.dsKey(isLast ? "auth.slides.start" : "auth.slides.next")) {
                if isLast {
                    onFinish()
                } else if reduceMotion {
                    page += 1
                } else {
                    withAnimation { page += 1 }
                }
            }
            .padding(.horizontal, DSSpacing.xl)
            .padding(.bottom, DSSpacing.lg)
        }
        .dsScreenBackground()
    }

    private func slideView(_ slide: Slide) -> some View {
        VStack(spacing: DSSpacing.lg) {
            Spacer(minLength: 0)
            ZStack {
                Circle().fill(Color.dsPrimaryMuted)
                Circle().strokeBorder(Color.dsPremiumGold, lineWidth: 1).padding(10)
                Image(systemName: slide.systemImage)
                    .font(.system(size: 72, weight: .light))
                    .foregroundStyle(Color.dsPrimary)
                    .accessibilityHidden(true)
            }
            .frame(width: 220, height: 220)

            VStack(spacing: DSSpacing.sm) {
                Text(verbatim: AuthL10n.string("\(slide.key).title"))
                    .font(.dsTitle1)
                    .foregroundStyle(Color.dsTextPrimary)
                    .multilineTextAlignment(.center)
                Text(verbatim: AuthL10n.string("\(slide.key).body"))
                    .font(.dsBody)
                    .foregroundStyle(Color.dsTextSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DSSpacing.xl)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The auth root: the intro slides on first launch, then the role choice from then on.
struct AuthIntroGate: View {
    let landing: AuthLandingView
    @AppStorage("auth.onboardingSeen") private var seen = false

    var body: some View {
        if seen {
            landing
        } else {
            OnboardingSlidesView { seen = true }
        }
    }
}
