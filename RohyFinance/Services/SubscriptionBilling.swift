//
//  SubscriptionBilling.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import Foundation
import SwiftData

/// Creates due renewal bills for enabled subscriptions.
enum SubscriptionBilling {
    static func generateDueBills(context: ModelContext, now: Date = .now) {
        guard let subscriptions = try? context.fetch(FetchDescriptor<Subscription>()) else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        for subscription in subscriptions where subscription.isEnabled {
            guard let wallet = subscription.wallet else { continue }
            let startDay = calendar.startOfDay(for: subscription.startDate)

            var offset = 0
            var latestGenerated: Date?
            while true {
                guard let renewal = calendar.date(byAdding: .day, value: offset * subscription.periodDays, to: startDay),
                      let charge = calendar.date(byAdding: .day, value: -subscription.advanceDays, to: renewal) else {
                    break
                }
                offset += 1
                let chargeDay = calendar.startOfDay(for: charge)
                if chargeDay > today { break }
                if chargeDay < startDay { continue }
                if let last = subscription.lastGeneratedDate,
                   chargeDay <= calendar.startOfDay(for: last) {
                    continue
                }

                let record = BillRecord(
                    kind: .expense,
                    amount: subscription.amount,
                    currency: subscription.currency,
                    categoryKey: "category.subscription",
                    subcategory: nil,
                    note: "\(subscription.name)-\(String(localized: "Auto Renewal"))",
                    date: charge,
                    wallet: wallet,
                    convertedAmount: subscription.convertedAmount
                )
                record.subscription = subscription
                wallet.adjust(subscription.currency, by: -subscription.amount)
                context.insert(record)
                latestGenerated = charge
            }
            if let latestGenerated {
                subscription.lastGeneratedDate = latestGenerated
            }
        }
    }
}
