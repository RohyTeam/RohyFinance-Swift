//
//  Item.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import Foundation
import SwiftData
import SwiftUI

enum ItemStatus: String, Codable, CaseIterable, Identifiable {
    case inUse
    case stopped
    case transferred
    case damaged
    case sold

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .inUse: return String(localized: "In Use")
        case .stopped: return String(localized: "Stopped")
        case .transferred: return String(localized: "Transferred")
        case .damaged: return String(localized: "Damaged")
        case .sold: return String(localized: "Sold")
        }
    }

    var color: Color {
        switch self {
        case .inUse: return .green
        case .stopped: return .gray
        case .transferred: return .blue
        case .damaged: return .red
        case .sold: return .yellow
        }
    }
}

/// A physical item (物品), optionally bound to the record of its purchase.
@Model
final class Item {
    var name: String = ""
    var imageData: Data?
    /// The purchase record this item is bound to (optional).
    var record: BillRecord?
    var currencyRaw: String = Currency.cny.rawValue
    var value: Double = 0
    var purchaseDate: Date = Date.now
    var retirementDate: Date?
    var warrantyEndDate: Date?
    var statusRaw: String = ItemStatus.inUse.rawValue

    init(name: String, imageData: Data?, record: BillRecord?, currency: Currency, value: Double, purchaseDate: Date, retirementDate: Date?, warrantyEndDate: Date?, status: ItemStatus) {
        self.name = name
        self.imageData = imageData
        self.record = record
        self.currencyRaw = currency.rawValue
        self.value = value
        self.purchaseDate = purchaseDate
        self.retirementDate = retirementDate
        self.warrantyEndDate = warrantyEndDate
        self.statusRaw = status.rawValue
    }

    var status: ItemStatus {
        ItemStatus(rawValue: statusRaw) ?? .inUse
    }

    var currency: Currency {
        Currency(rawValue: currencyRaw) ?? .cny
    }

    /// Values shown for a bound item always follow the record.
    var displayCurrency: Currency {
        record?.currency ?? currency
    }

    var displayValue: Double {
        record?.effectiveAmount ?? value
    }

    var displayPurchaseDate: Date {
        record?.date ?? purchaseDate
    }

    /// Days since purchase.
    var daysInUse: Int {
        max(0, Calendar.current.dateComponents([.day], from: displayPurchaseDate, to: .now).day ?? 0)
    }
}
