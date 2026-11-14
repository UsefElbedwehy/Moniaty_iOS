//
//  BookingTrustViews.swift
//  Booking
//
//  Created by Usef Elbedwehy on 01/11/2026.
//

import SwiftUI

/// Views supplied by the App from the Trust feature, so Booking doesn't depend on it.
public struct BookingTrustViews {
    let review: (String, BookingRole) -> AnyView
    let moreMenu: (String) -> AnyView
    let helpSheet: (String) -> AnyView

    public init(
        review: @escaping (String, BookingRole) -> AnyView,
        moreMenu: @escaping (String) -> AnyView,
        helpSheet: @escaping (String) -> AnyView
    ) {
        self.review = review
        self.moreMenu = moreMenu
        self.helpSheet = helpSheet
    }
}
