//
//  BookableService.swift
//  Booking
//
//  Created by Usef Elbedwehy on 01/11/2026.
//

import Foundation

/// What a booking request needs to know about the service (from the catalog card).
public struct BookableService: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public let price: Decimal
    public let providerName: String?

    public init(
        id: String,
        title: String,
        price: Decimal,
        providerName: String?
    ) {
        self.id = id
        self.title = title
        self.price = price
        self.providerName = providerName
    }
}
