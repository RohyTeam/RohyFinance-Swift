//
//  SavingsSettlement.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import Foundation
import SwiftData

/// Distributes a budget's leftover money to its savings plans when a period ends.
enum SavingsSettlement {
    static func processCompletedPeriods(context: ModelContext, now: Date = .now) {
        guard let budgets = try? context.fetch(FetchDescriptor<Budget>()),
              let plans = try? context.fetch(FetchDescriptor<SavingsPlan>()),
              let records = try? context.fetch(FetchDescriptor<BillRecord>()) else {
            return
        }

        for budget in budgets {
            let budgetPlans = plans
                .filter { $0.budget === budget }
                .sorted { $0.sortOrder < $1.sortOrder }
            guard !budgetPlans.isEmpty, let wallet = budget.wallet else { continue }

            for interval in completedPeriods(for: budget.period, after: budget.lastSavingsProcessed, now: now) {
                // Only periods that end after the budget was created are settled;
                // a new budget starts saving when its current period ends.
                guard interval.end > budget.createdAt else { continue }
                let spent = records
                    .filter { $0.budget === budget && $0.kind == .expense && interval.contains($0.date) }
                    .reduce(0) { $0 + $1.effectiveAmount }
                var remaining = budget.amount - spent

                for plan in budgetPlans {
                    guard remaining > 0.004 else { break }
                    let needed = plan.amount
                    let allocated: Double
                    if plan.allRemaining || remaining < needed {
                        allocated = remaining
                    } else {
                        allocated = needed
                    }
                    guard allocated > 0.004, let goal = plan.goal else { break }

                    let record = BillRecord(
                        kind: .saving,
                        amount: allocated,
                        currency: budget.currency,
                        categoryKey: "",
                        subcategory: nil,
                        note: "\(goal.name)-\(String(localized: "Auto Saving"))",
                        date: interval.end.addingTimeInterval(-60),
                        wallet: wallet,
                        savingsGoal: goal
                    )
                    context.insert(record)
                    remaining -= allocated
                    if plan.allRemaining { break }
                }

                budget.lastSavingsProcessed = interval.end
            }
        }
    }

    /// Completed periods that still need processing, oldest first.
    /// When never processed before, only the latest completed period is handled
    /// (avoids flooding history on first run).
    private static func completedPeriods(for period: BudgetPeriod, after lastProcessed: Date?, now: Date) -> [DateInterval] {
        guard let current = period.currentInterval(now: now) else { return [] }
        var result: [DateInterval] = []
        var end = current.start
        while true {
            let justBefore = end.addingTimeInterval(-1)
            guard let previous = period.currentInterval(now: justBefore), previous.end <= now else { break }
            if let lastProcessed, previous.end <= lastProcessed { break }
            result.insert(previous, at: 0)
            if lastProcessed == nil { break }
            end = previous.start
        }
        return result.sorted { $0.start < $1.start }
    }
}
