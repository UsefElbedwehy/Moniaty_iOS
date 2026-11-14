//
//  BookableService.swift
//  Booking
//
//  Created by Usef Elbedwehy on 01/11/2026.
//

import Catalog
import Foundation

/// What a booking request needs to know about the service (from the catalog card).
public struct BookableService: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    /// Nil when the provider hides the price (on request).
    public let price: Decimal?
    public let priceMode: PriceMode
    public let providerName: String?

    public init(
        id: String,
        title: String,
        price: Decimal?,
        priceMode: PriceMode = .fixed,
        providerName: String?
    ) {
        self.id = id
        self.title = title
        self.price = price
        self.priceMode = priceMode
        self.providerName = providerName
    }
}
