//
//  BookingRequestScreenView.swift
//  Booking
//
//  Created by Usef Elbedwehy on 01/11/2026.
//

import Catalog
import Core
import DesignSystem
import Shared
import SwiftUI

struct BookingRequestScreenView: View {
    let feature: BookingFeature
    let service: BookableService
    let onCreated: (String) -> Void

    @State private var day = Calendar.current.startOfDay(for: .now)
    /// The provider's mode and her days with a free time (nil until loaded, or if that fails).
    @State private var available: AvailableDays?
    @State private var slots: ViewState<[Date]> = .loading
    @State private var selected: Date?
    @State private var note = ""
    @State private var isSending = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.analytics) private var analytics

    /// The day chips: her listed dates in "dates" mode, otherwise the next three weeks.
    private var days: [Date] {
        if available?.mode == "dates", let list = available?.days {
            return list.compactMap { DateFormatter.day.date(from: $0) }.map {
                Calendar.current.startOfDay(for: $0)
            }
        }
        return (0..<21).compactMap {
            Calendar.current.date(
                byAdding: .day,
                value: $0,
                to: Calendar.current.startOfDay(for: .now)
            )
        }
    }

    /// A day with no free time is shown dimmed (once the free days are known).
    private func isOpen(_ d: Date) -> Bool {
        guard let list = available?.days else { return true }
        return list.contains(DateFormatter.day.string(from: d))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DSSpacing.lg) {
                DSCard {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: service.title).font(.dsHeadline)
                            Text(verbatim: service.providerName ?? "").font(
                                .dsFootnote
                            ).foregroundStyle(Color.dsTextSecondary)
                        }
                        Spacer()
                        Text(verbatim: formatSAR(service.price)).font(
                            .dsHeadline
                        ).foregroundStyle(Color.dsPrimary)
                    }
                }

                if available?.mode == "request" {
                    Label(
                        BookingL10n.string("request.onRequest"),
                        systemImage: "hand.raised"
                    )
                    .font(.dsFootnote)
                    .foregroundStyle(Color.dsTextSecondary)
                }

                BookingL10n.text("request.day").font(.dsHeadline)
                if days.isEmpty {
                    BookingL10n.text("request.noDays").font(.dsFootnote)
                        .foregroundStyle(Color.dsTextSecondary)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DSSpacing.xs) {
                        ForEach(days, id: \.self) { d in
                            let isOn = Calendar.current.isDate(
                                d,
                                inSameDayAs: day
                            )
                            let open = isOpen(d)
                            Button {
                                day = d
                                selected = nil
                            } label: {
                                VStack(spacing: 2) {
                                    Text(
                                        verbatim: d.displayFormatted(
                                            .dateTime.weekday(.abbreviated)
                                        )
                                    ).font(.dsCaption)
                                    Text(
                                        verbatim: d.displayFormatted(
                                            .dateTime.day()
                                        )
                                    ).font(.dsTitle2)
                                    if available?.mode == "dates" {
                                        Text(
                                            verbatim: d.displayFormatted(
                                                .dateTime.month(.abbreviated)
                                            )
                                        ).font(.dsCaption)
                                    }
                                }
                                .frame(
                                    width: 56,
                                    height: available?.mode == "dates" ? 78 : 64
                                )
                                .foregroundStyle(
                                    isOn
                                        ? Color.dsBackground
                                        : Color.dsTextPrimary
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 16).fill(
                                        isOn ? Color.dsPrimary : Color.dsSurface
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .strokeBorder(
                                            isOn ? Color.clear : Color.dsBorder
                                        )
                                )
                                .opacity(open || isOn ? 1 : 0.4)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isOn ? .isSelected : [])
                        }
                    }
                }

                BookingL10n.text("request.time").font(.dsHeadline)
                switch slots {
                case .loading:
                    ProgressView().frame(maxWidth: .infinity)
                case .loaded(let list) where !list.isEmpty:
                    LazyVGrid(
                        columns: Array(
                            repeating: GridItem(
                                .flexible(),
                                spacing: DSSpacing.xs
                            ),
                            count: 4
                        ),
                        spacing: DSSpacing.xs
                    ) {
                        ForEach(list, id: \.self) { slot in
                            let isOn = selected == slot
                            Button {
                                selected = slot
                            } label: {
                                Text(
                                    verbatim: slot.displayFormatted(
                                        .dateTime.hour().minute()
                                    )
                                )
                                .font(.dsSubhead)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .foregroundStyle(
                                    isOn
                                        ? Color.dsBackground
                                        : Color.dsTextPrimary
                                )
                                .background(
                                    RoundedRectangle(cornerRadius: 14).fill(
                                        isOn
                                            ? Color.dsTextPrimary
                                            : Color.dsSurface
                                    )
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .strokeBorder(
                                            isOn ? Color.clear : Color.dsBorder
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(isOn ? .isSelected : [])
                        }
                    }
                case .error(let error):
                    ErrorStateView(error: error) { Task { await loadSlots() } }
                default:
                    BookingL10n.text("request.noSlots").font(.dsFootnote)
                        .foregroundStyle(Color.dsTextSecondary)
                }

                TextField(
                    BookingL10n.string("request.note"),
                    text: $note,
                    axis: .vertical
                )
                .lineLimit(2...4)
                .padding(DSSpacing.sm)
                .background(
                    RoundedRectangle(cornerRadius: 14).fill(Color.dsSurface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14).strokeBorder(
                        Color.dsBorder
                    )
                )

                VStack(alignment: .leading, spacing: DSSpacing.xs) {
                    if let remaining = feature.remainingBudget() {
                        Text(
                            verbatim: BookingL10n.format(
                                "request.budgetAfter",
                                formatSAR(remaining - service.price)
                            )
                        )
                        .font(.dsSubhead)
                    }
                    BookingL10n.text("request.paymentInfo").font(.dsFootnote)
                        .foregroundStyle(Color.dsTextSecondary)
                }
                .padding(DSSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DSRadius.card).fill(
                        Color.dsPrimaryMuted
                    )
                )
            }
            .padding(DSSpacing.lg)
        }
        .dsScreenBackground()
        .safeAreaInset(edge: .bottom) {
            PrimaryButton(
                BookingL10n.key("request.send"),
                isLoading: isSending,
                isEnabled: selected != nil
            ) { send() }
            .padding(.horizontal, DSSpacing.lg)
            .padding(.vertical, DSSpacing.sm)
            .background(.bar)
        }
        .navigationTitle(BookingL10n.string("request.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(BookingL10n.string("common.cancel")) { dismiss() }
            }
        }
        .alert(
            errorMessage ?? "",
            isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )
        ) {
            Button(BookingL10n.string("common.ok"), role: .cancel) {}
        }
        .task { await loadDays() }
        .task(id: day) { await loadSlots() }
        .trackScreen("booking_request")
    }

    /// The provider's mode and free days; starts on the first free day.
    private func loadDays() async {
        guard
            let loaded = try? await feature.repository.availableDays(
                serviceId: service.id
            )
        else { return }
        available = loaded
        if !isOpen(day), let first = days.first(where: isOpen) {
            day = first
            selected = nil
        }
    }

    private func loadSlots() async {
        slots = .loading
        do {
            let list = try await feature.repository.availableSlots(
                serviceId: service.id,
                day: DateFormatter.day.string(from: day)
            )
            slots = list.isEmpty ? .empty : .loaded(list)
        } catch {
            slots = .error(appError(error))
        }
    }

    private func send() {
        guard let selected else { return }
        isSending = true
        Task {
            defer { isSending = false }
            do {
                switch try await feature.repository.createBooking(
                    serviceId: service.id,
                    startsAt: selected,
                    note: note.isEmpty ? nil : note
                ) {
                case .ok(let id):
                    analytics(.bookingSubmitted, service.id)
                    feature.onBookingsChanged()
                    dismiss()
                    if let id { onCreated(id) }
                case .refused(let code):
                    errorMessage = BookingL10n.refusal(code)
                    if code == "slot_unavailable" { await loadSlots() }
                }
            } catch {
                errorMessage = BookingL10n.string("error.generic")
            }
        }
    }
}
