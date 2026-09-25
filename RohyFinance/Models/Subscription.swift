//
//  Subscription.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import Foundation
import SwiftData

enum SubscriptionPeriod: Int, Codable, CaseIterable, Identifiable {
    case monthly = 30
    case quarterly = 90
    case yearly = 365

    var id: Int { rawValue }

    var localizedName: String {
        switch self {
        case .monthly: return String(localized: "Monthly")
        case .quarterly: return String(localized: "Quarterly")
        case .yearly: return String(localized: "Yearly")
        }
    }
}

@Model
final class Subscription {
    var name: String = ""
    /// Custom image picked from the photo library (square-cropped).
    var imageData: Data?
    /// Asset name of a preset icon (used when imageData is nil).
    var presetIcon: String?
    var amount: Double = 0
    var currencyRaw: String = Currency.cny.rawValue
    /// Amount converted to the default currency (nil when currency == default).
    var convertedAmount: Double?
    var wallet: Wallet?
    var startDate: Date = Date.now
    var periodDays: Int = SubscriptionPeriod.monthly.rawValue
    /// Days before the renewal date on which the charge happens (0...5).
    var advanceDays: Int = 0
    var isEnabled: Bool = false
    var lastGeneratedDate: Date?

    init(name: String, imageData: Data?, presetIcon: String?, amount: Double, currency: Currency, convertedAmount: Double?, wallet: Wallet?, startDate: Date, periodDays: Int, advanceDays: Int, isEnabled: Bool = false) {
        self.name = name
        self.imageData = imageData
        self.presetIcon = presetIcon
        self.amount = amount
        self.currencyRaw = currency.rawValue
        self.convertedAmount = convertedAmount
        self.wallet = wallet
        self.startDate = startDate
        self.periodDays = periodDays
        self.advanceDays = advanceDays
        self.isEnabled = isEnabled
    }

    var currency: Currency {
        Currency(rawValue: currencyRaw) ?? .cny
    }

    var period: SubscriptionPeriod {
        SubscriptionPeriod(rawValue: periodDays) ?? .monthly
    }
}
