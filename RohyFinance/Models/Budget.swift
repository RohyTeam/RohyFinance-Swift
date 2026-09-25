//
//  Budget.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import Foundation
import SwiftData

enum BudgetPeriod: String, Codable, CaseIterable, Identifiable {
    case weekly
    case monthly
    case quarterly
    case yearly

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .weekly: return String(localized: "Per Week")
        case .monthly: return String(localized: "Per Month")
        case .quarterly: return String(localized: "Per Quarter")
        case .yearly: return String(localized: "Per Year")
        }
    }

    /// Label of the current period's scope, e.g. 本周 / 本月 / 本季 / 本年.
    var currentScopeName: String {
        switch self {
        case .weekly: return String(localized: "This week")
        case .monthly: return String(localized: "This month")
        case .quarterly: return String(localized: "This quarter")
        case .yearly: return String(localized: "This year")
        }
    }

    /// The interval of the current period containing `now`.
    /// Quarters are fixed calendar quarters: 1-3, 4-6, 7-9, 10-12.
    func currentInterval(now: Date = .now, calendar: Calendar = .current) -> DateInterval? {
        switch self {
        case .weekly:
            return calendar.dateInterval(of: .weekOfYear, for: now)
        case .monthly:
            return calendar.dateInterval(of: .month, for: now)
        case .yearly:
            return calendar.dateInterval(of: .year, for: now)
        case .quarterly:
            let month = calendar.component(.month, from: now)
            let year = calendar.component(.year, from: now)
            let startMonth = ((month - 1) / 3) * 3 + 1
            guard let start = calendar.date(from: DateComponents(year: year, month: startMonth, day: 1)),
                  let end = calendar.date(byAdding: .month, value: 3, to: start) else {
                return nil
            }
            return DateInterval(start: start, end: end)
        }
    }
}

@Model
final class Budget {
    /// SF Symbol name (preset icons from the expense categories).
    var icon: String = ""
    var name: String = ""
    var wallet: Wallet?
    var currencyRaw: String = Currency.cny.rawValue
    var amount: Double = 0
    var periodRaw: String = BudgetPeriod.monthly.rawValue

    init(icon: String, name: String, wallet: Wallet?, currency: Currency, amount: Double, period: BudgetPeriod) {
        self.icon = icon
        self.name = name
        self.wallet = wallet
        self.currencyRaw = currency.rawValue
        self.amount = amount
        self.periodRaw = period.rawValue
    }

    var currency: Currency {
        Currency(rawValue: currencyRaw) ?? .cny
    }

    var period: BudgetPeriod {
        BudgetPeriod(rawValue: periodRaw) ?? .monthly
    }
}
