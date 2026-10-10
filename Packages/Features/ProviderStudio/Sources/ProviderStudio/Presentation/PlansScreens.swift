import SwiftUI
import AuthenticationServices
import Core
import DesignSystem
import Shared
import Catalog

// MARK: - Subscription card (studio home)

/// Trial countdown, current plan, or "your services are hidden" (docs/PLAN.md §4.7).
struct SubscriptionCard: View {
    let subscription: SubscriptionOverview

    private var entitlement: Entitlement { subscription.entitlement }

    var body: some View {
        let days = entitlement.daysLeft()
        let urgent = entitlement.state == .expired || (days.map { $0 <= 14 } ?? false) && entitlement.nextPlanId == nil
        DSCard {
            VStack(alignment: .leading, spacing: DSSpacing.sm) {
                HStack {
                    Image(systemName: icon)
                        .foregroundStyle(entitlement.state == .expired ? Color.dsError : Color.dsPrimary)
                    Text(verbatim: title).font(.dsHeadline)
                    Spacer()
                    if entitlement.state == .subscribed, let plan = subscription.currentPlan {
                        StatusBadge(kind: plan.isFeatured ? .featured : .live, text: LocalizedStringKey(plan.name))
                    }
                }
                Text(verbatim: message(days: days))
                    .font(.dsSubhead)
                    .foregroundStyle(Color.dsTextSecondary)
                if let next = subscription.nextPlan, let start = entitlement.nextStartsAt {
                    Text(verbatim: StudioL10n.format("plan.card.next", next.name, start.formatted(date: .abbreviated, time: .omitted)))
                        .font(.dsFootnote)
                        .foregroundStyle(Color.dsTextSecondary)
                }
                if urgent {
                    NavigationLink(value: StudioRoute.plans) {
                        PlanLinkLabel(title: StudioL10n.string(entitlement.state == .subscribed ? "plan.card.renew" : "plan.card.choose"))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var icon: String {
        switch entitlement.state {
        case .trial: "gift"
        case .subscribed: "crown"
        case .expired: "eye.slash"
        case .pending: "hourglass"
        }
    }

    private var title: String {
        switch entitlement.state {
        case .trial: StudioL10n.string("plan.card.trial")
        case .subscribed: StudioL10n.string("plan.card.subscribed")
        case .expired: StudioL10n.string("plan.card.expired")
        case .pending: ""
        }
    }

    private func message(days: Int?) -> String {
        switch entitlement.state {
        case .trial, .subscribed:
            guard let days, let end = entitlement.listedUntil else { return "" }
            return StudioL10n.format("plan.card.until", end.formatted(date: .abbreviated, time: .omitted), days)
        case .expired:
            return StudioL10n.string("plan.card.expired.message")
        case .pending:
            return ""
        }
    }
}

// MARK: - Plans / paywall (mockup "Paywall")

struct PlansScreen: View {
    let feature: StudioFeature
    /// Why the paywall opened, e.g. "Your plan allows 1 service" (nil from the studio row).
    let reason: String?

    @State private var selectedId: String?
    @State private var isPaying = false
    @State private var alert: PlanAlert?
    @Environment(\.webAuthenticationSession) private var webAuthenticationSession
    @Environment(\.analytics) private var analytics
    @Environment(\.openURL) private var openURL

    private var store: StudioStore { feature.store }

    private struct PlanAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String?
    }

    var body: some View {
        Group {
            if let subscription = store.subscription {
                content(subscription)
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .dsScreenBackground()
        .navigationTitle(StudioL10n.string("plans.title"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(item: $alert) { alert in
            Alert(title: Text(verbatim: alert.title), message: alert.message.map { Text(verbatim: $0) },
                  dismissButton: .default(Text(verbatim: StudioL10n.string("common.ok"))))
        }
        .task {
            await store.reload()
            analytics(.paywallView, nil, context: reason == nil ? "studio" : "limit")
        }
        .trackScreen("paywall")
    }

    @ViewBuilder
    private func content(_ subscription: SubscriptionOverview) -> some View {
        let selected = subscription.plan(selectedId ?? defaultSelection(subscription))
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    StudioL10n.text("plans.headline").font(.dsTitle1)
                    Text(verbatim: headline(subscription)).font(.dsSubhead).foregroundStyle(Color.dsTextSecondary)
                }
                if let reason {
                    Label { Text(verbatim: reason) } icon: { Image(systemName: "exclamationmark.circle") }
                        .font(.dsSubhead)
                        .padding(DSSpacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.dsPendingBackground))
                }
                ForEach(subscription.plans) { plan in
                    PlanCardView(plan: plan,
                                 isSelected: plan.id == selected?.id,
                                 isCurrent: subscription.entitlement.state == .subscribed && plan.id == subscription.entitlement.planId)
                        .onTapGesture { selectedId = plan.id }
                }
                disclosure
                if !subscription.payments.isEmpty {
                    paymentsSection(subscription)
                }
            }
            .padding(DSSpacing.lg)
        }
        .safeAreaInset(edge: .bottom) {
            if let selected {
                PrimaryButton(LocalizedStringKey(ctaTitle(selected, subscription)), isLoading: isPaying,
                              isEnabled: subscription.entitlement.state != .pending) {
                    pay(selected)
                }
                .padding(.horizontal, DSSpacing.lg)
                .padding(.vertical, DSSpacing.sm)
                .background(.bar)
            }
        }
    }

    private var disclosure: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            StudioL10n.text("plans.disclosure").font(.dsFootnote).foregroundStyle(Color.dsTextSecondary)
            HStack(spacing: DSSpacing.md) {
                Button(StudioL10n.string("plans.terms")) { openURL(URL(string: "https://munyati.co/terms")!) }
                Button(StudioL10n.string("plans.privacy")) { openURL(URL(string: "https://munyati.co/privacy")!) }
            }
            .font(.dsFootnote)
            .tint(Color.dsPrimary)
        }
    }

    private func paymentsSection(_ subscription: SubscriptionOverview) -> some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            StudioL10n.text("plans.payments").font(.dsHeadline)
            ForEach(subscription.payments) { payment in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: subscription.plan(payment.planId)?.name ?? payment.planId).font(.dsSubhead)
                        Text(verbatim: payment.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.dsCaption).foregroundStyle(Color.dsTextSecondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(verbatim: formatSAR(payment.amount)).font(.dsSubhead)
                        Text(verbatim: StudioL10n.string("plans.payment.\(payment.status.rawValue)"))
                            .font(.dsCaption)
                            .foregroundStyle(payment.status == .captured ? Color.dsSuccess : Color.dsTextSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func defaultSelection(_ subscription: SubscriptionOverview) -> String {
        if subscription.entitlement.state == .subscribed, let id = subscription.entitlement.planId { return id }
        return subscription.plans.first(where: \.isRecommended)?.id ?? subscription.plans.first?.id ?? ""
    }

    private func headline(_ subscription: SubscriptionOverview) -> String {
        let e = subscription.entitlement
        switch e.state {
        case .pending:
            return StudioL10n.string("plans.sub.pending")
        case .trial:
            let end = (e.trialEndsAt ?? .now).formatted(date: .abbreviated, time: .omitted)
            return StudioL10n.format("plans.sub.trial", end)
        case .subscribed:
            let end = (e.paidUntil ?? e.periodEndsAt ?? .now).formatted(date: .abbreviated, time: .omitted)
            return StudioL10n.format("plans.sub.subscribed", subscription.currentPlan?.name ?? "", end)
        case .expired:
            return StudioL10n.string("plans.sub.expired")
        }
    }

    private func ctaTitle(_ plan: SubscriptionPlan, _ subscription: SubscriptionOverview) -> String {
        let e = subscription.entitlement
        if e.state == .subscribed, plan.id == e.planId {
            return StudioL10n.format("plans.cta.renew", formatSAR(plan.priceSar))
        }
        if e.state == .subscribed, let current = subscription.currentPlan, plan.rank > current.rank {
            return StudioL10n.format("plans.cta.upgrade", plan.name, formatSAR(plan.priceSar))
        }
        return StudioL10n.format("plans.cta.subscribe", plan.name, formatSAR(plan.priceSar))
    }

    // Tap hosted checkout → back to the app → confirm with the server (the browser closing is
    // not proof of payment).
    private func pay(_ plan: SubscriptionPlan) {
        isPaying = true
        analytics(.planPurchaseStarted, plan.id)
        Task {
            defer { isPaying = false }
            do {
                let paymentId: String
                switch try await feature.checkout.start(planId: plan.id) {
                case .refused(let code):
                    alert = PlanAlert(title: StudioL10n.string("plans.error.\(code)"), message: nil)
                    return
                case .completed(let id):
                    paymentId = id
                case .open(let id, let url):
                    paymentId = id
                    // Cancelling the sheet throws; the payment may still have gone through.
                    _ = try? await webAuthenticationSession.authenticate(using: url, callbackURLScheme: "munyati")
                }
                let status = await confirm(paymentId)
                await store.reload()
                switch status {
                case .captured:
                    alert = PlanAlert(title: StudioL10n.string("plans.result.captured"),
                                      message: StudioL10n.format("plans.result.captured.message", plan.name))
                case .failed:
                    alert = PlanAlert(title: StudioL10n.string("plans.result.failed"), message: nil)
                case .review:
                    alert = PlanAlert(title: StudioL10n.string("plans.result.review"), message: nil)
                case .initiated:
                    break // Closed before paying, or still processing: the card updates when it settles.
                }
            } catch {
                alert = PlanAlert(title: StudioL10n.string("plans.error.generic"), message: nil)
            }
        }
    }

    /// Polls the server a few times while Tap settles the charge.
    private func confirm(_ paymentId: String) async -> PlanPaymentStatus {
        var status: PlanPaymentStatus = .initiated
        for attempt in 0..<5 {
            if let fresh = try? await feature.checkout.status(paymentId: paymentId) { status = fresh }
            if status != .initiated { break }
            try? await Task.sleep(for: .seconds(attempt == 0 ? 1 : 2))
        }
        return status
    }
}

struct PlanCardView: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let isCurrent: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: plan.name).font(.dsTitle2)
                if plan.isRecommended {
                    StatusBadge(kind: .featured, text: StudioL10n.key("plans.recommended"))
                }
                if isCurrent {
                    StatusBadge(kind: .live, text: StudioL10n.key("plans.current"))
                }
                Spacer()
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(isSelected ? Color.dsPrimary : Color.dsDisabled)
            }
            Text(verbatim: StudioL10n.format("plans.price", formatSAR(plan.priceSar)))
                .font(.dsHeadline)
                .foregroundStyle(Color.dsPrimary)
            ForEach(plan.features, id: \.self) { feature in
                Label { Text(verbatim: feature) } icon: {
                    Image(systemName: "checkmark").foregroundStyle(Color.dsPrimary)
                }
                .font(.dsSubhead)
            }
        }
        .padding(DSSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DSRadius.card).fill(Color.dsSurface))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.card)
            .strokeBorder(isSelected ? Color.dsPrimary : Color.dsBorder, lineWidth: isSelected ? 2 : 1))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Insights

struct InsightsScreen: View {
    let feature: StudioFeature
    @State private var days = 30
    @State private var state: ViewState<Insights> = .loading

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.md) {
                Picker("", selection: $days) {
                    Text(verbatim: StudioL10n.format("insights.days", 7)).tag(7)
                    Text(verbatim: StudioL10n.format("insights.days", 30)).tag(30)
                    Text(verbatim: StudioL10n.format("insights.days", 90)).tag(90)
                }
                .pickerStyle(.segmented)

                switch state {
                case .loading:
                    ProgressView().frame(maxWidth: .infinity, minHeight: 200)
                case .error(let error):
                    ErrorStateView(error: error) { Task { await load() } }
                case .loaded(let insights), .refreshing(let insights):
                    content(insights)
                case .empty, .offline:
                    ErrorStateView(error: .offline) { Task { await load() } }
                }
            }
            .padding(DSSpacing.lg)
        }
        .dsScreenBackground()
        .navigationTitle(StudioL10n.string("insights.title"))
        .task(id: days) { await load() }
        .refreshable { await load() }
        .trackScreen("studio_insights")
    }

    @ViewBuilder
    private func content(_ insights: Insights) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: DSSpacing.sm), GridItem(.flexible())], spacing: DSSpacing.sm) {
            StatTile(title: StudioL10n.string("insights.profileViews"), value: "\(insights.profileViews)", systemImage: "person.crop.square")
            StatTile(title: StudioL10n.string("insights.serviceViews"), value: "\(insights.serviceViews)", systemImage: "eye")
            StatTile(title: StudioL10n.string("insights.requests"), value: "\(insights.requests)", systemImage: "calendar.badge.plus")
            if let taps = insights.contactTaps {
                StatTile(title: StudioL10n.string("insights.contacts"), value: "\(taps)", systemImage: "bubble.left.and.bubble.right")
            }
            if let favorites = insights.favorites {
                StatTile(title: StudioL10n.string("insights.favorites"), value: "\(favorites)", systemImage: "heart")
            }
            if let revenue = insights.revenue {
                StatTile(title: StudioL10n.string("insights.revenue"), value: formatSAR(revenue), systemImage: "banknote")
            }
        }

        if insights.isFull {
            DSCard {
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    StudioL10n.text("insights.funnel").font(.dsHeadline)
                    FunnelRow(title: StudioL10n.string("insights.serviceViews"), value: insights.serviceViews, of: insights.serviceViews)
                    FunnelRow(title: StudioL10n.string("insights.requests"), value: insights.requests, of: insights.serviceViews)
                    FunnelRow(title: StudioL10n.string("insights.approved"), value: insights.approved ?? 0, of: insights.serviceViews)
                    FunnelRow(title: StudioL10n.string("insights.completed"), value: insights.completed ?? 0, of: insights.serviceViews)
                }
            }
            if let rows = insights.services, !rows.isEmpty {
                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    StudioL10n.text("insights.byService").font(.dsHeadline)
                    ForEach(rows) { row in
                        HStack {
                            Text(verbatim: row.title).font(.dsSubhead).lineLimit(1)
                            Spacer()
                            Label("\(row.views)", systemImage: "eye").font(.dsFootnote)
                            Label("\(row.requests)", systemImage: "calendar").font(.dsFootnote)
                        }
                        .foregroundStyle(Color.dsTextPrimary)
                        .padding(.vertical, 4)
                    }
                }
            }
        } else {
            DSCard {
                VStack(alignment: .leading, spacing: DSSpacing.sm) {
                    StudioL10n.text("insights.upsell").font(.dsSubhead)
                    NavigationLink(value: StudioRoute.plans) {
                        PlanLinkLabel(title: StudioL10n.string("insights.upsell.cta"))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func load() async {
        do {
            state = .loaded(try await feature.store.repository.insights(days: days))
        } catch {
            if state.value == nil { state = .error((error as? AppError) ?? .unknown(message: error.localizedDescription)) }
        }
    }
}

private struct StatTile: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: DSSpacing.xs) {
            Image(systemName: systemImage).foregroundStyle(Color.dsPrimary)
            Text(verbatim: value).font(.dsTitle2).foregroundStyle(Color.dsTextPrimary)
            Text(verbatim: title).font(.dsFootnote).foregroundStyle(Color.dsTextSecondary).lineLimit(2)
        }
        .padding(DSSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DSRadius.card).fill(Color.dsSurface))
        .overlay(RoundedRectangle(cornerRadius: DSRadius.card).strokeBorder(Color.dsBorder))
        .accessibilityElement(children: .combine)
    }
}

private struct FunnelRow: View {
    let title: String
    let value: Int
    let of: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(verbatim: title).font(.dsSubhead)
                Spacer()
                Text(verbatim: "\(value)").font(.dsSubhead).foregroundStyle(Color.dsPrimary)
            }
            GeometryReader { proxy in
                Capsule().fill(Color.dsPrimaryMuted)
                    .overlay(alignment: .leading) {
                        Capsule().fill(Color.dsPrimary)
                            .frame(width: of > 0 ? proxy.size.width * CGFloat(min(value, of)) / CGFloat(of) : 0)
                    }
            }
            .frame(height: 6)
        }
    }
}

/// A full-width burgundy label for navigation links that look like the primary button.
private struct PlanLinkLabel: View {
    let title: String

    var body: some View {
        Text(verbatim: title)
            .font(.dsHeadline)
            .foregroundStyle(Color.dsBackground)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(Capsule().fill(Color.dsPrimary))
    }
}
