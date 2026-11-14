//
//  BookingRoute.swift
//  Booking
//
//  Created by Usef Elbedwehy on 01/11/2026.
//

/// Destinations inside the booking feature (registered on the App's NavigationStacks).
public enum BookingRoute: Hashable, Sendable {
    case detail(id: String)
    case availability
    case paymentMethods
}
