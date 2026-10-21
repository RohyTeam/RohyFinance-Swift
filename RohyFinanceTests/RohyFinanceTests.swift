//
//  RohyFinanceTests.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import Testing
import Foundation
import SwiftData
@testable import RohyFinance

struct RohyFinanceTests {

    @MainActor
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(
            for: Wallet.self, BillRecord.self, Subcategory.self, Subscription.self, Budget.self, SavingsGoal.self, SavingsPlan.self, Item.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        return ModelContext(container)
    }

    /// Reproduces the edit-save path: editing a record must not create a duplicate.
    @MainActor
    @Test func editingRecordDoesNotDuplicate() throws {
        let context = try makeContext()
        let wallet = Wallet(name: "A", source: .alipay, holdings: [Holding(currencyRaw: "cny", amount: 100)])
        context.insert(wallet)
        let original = BillRecord(kind: .expense, amount: 10, currency: .cny, categoryKey: "category.dining", subcategory: nil, note: "a", date: .now, wallet: wallet)
        context.insert(original)
        try context.save()

        // Simulate what RecordEntryView.save does when editing.
        let draft = RecordDraft(kind: .expense, amount: 20, currency: .cny, categoryKey: "category.dining", note: "b", date: .now, wallet: wallet)
        original.revertBalanceEffect()
        original.update(from: draft)
        draft.applyBalanceEffect()
        try context.save()

        let records = try context.fetch(FetchDescriptor<BillRecord>())
        #expect(records.count == 1, "record count was \(records.count), notes: \(records.map(\.note))")
        #expect(original.note == "b")
        // Balance: 100 + 10 (revert) - 20 (apply) = 90
        #expect(wallet.holdings.first?.amount == 90, "balance was \(wallet.holdings.first?.amount ?? -999)")
    }

    /// Quarterly periods are fixed calendar quarters (1-3, 4-6, 7-9, 10-12).
    @Test func quarterlyPeriodInterval() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!

        // September belongs to Q3: 7/1 - 10/1
        let september = calendar.date(from: DateComponents(year: 2026, month: 9, day: 25))!
        let q3 = BudgetPeriod.quarterly.currentInterval(now: september, calendar: calendar)
        #expect(q3?.start == calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!)
        #expect(q3?.end == calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!)

        // January belongs to Q1: 1/1 - 4/1
        let january = calendar.date(from: DateComponents(year: 2026, month: 1, day: 10))!
        let q1 = BudgetPeriod.quarterly.currentInterval(now: january, calendar: calendar)
        #expect(q1?.start == calendar.date(from: DateComponents(year: 2026, month: 1, day: 1))!)
        #expect(q1?.end == calendar.date(from: DateComponents(year: 2026, month: 4, day: 1))!)

        // December belongs to Q4: 10/1 - next year's 1/1
        let december = calendar.date(from: DateComponents(year: 2026, month: 12, day: 31))!
        let q4 = BudgetPeriod.quarterly.currentInterval(now: december, calendar: calendar)
        #expect(q4?.start == calendar.date(from: DateComponents(year: 2026, month: 10, day: 1))!)
        #expect(q4?.end == calendar.date(from: DateComponents(year: 2027, month: 1, day: 1))!)
    }

    /// Editing a budget unlinks all records that counted towards it;
    /// the records themselves are kept (no data loss).
    @MainActor
    @Test func editingBudgetClearsRecordLinks() throws {
        let context = try makeContext()
        let wallet = Wallet(name: "A", source: .alipay, holdings: [Holding(currencyRaw: "cny", amount: 1000)])
        context.insert(wallet)
        let budget = Budget(icon: "fork.knife", name: "餐饮预算", wallet: wallet, currency: .cny, amount: 500, period: .monthly)
        context.insert(budget)
        let record = BillRecord(kind: .expense, amount: 100, currency: .cny, categoryKey: "category.dining", subcategory: nil, note: "午餐", date: .now, wallet: wallet, budget: budget)
        context.insert(record)
        record.applyBalanceEffect()
        try context.save()

        // Simulate what BudgetFormView.confirm does when editing.
        budget.name = "改名"
        budget.amount = 600
        let linked = try context.fetch(FetchDescriptor<BillRecord>())
        for item in linked where item.budget === budget {
            item.budget = nil
        }
        try context.save()

        let budgets = try context.fetch(FetchDescriptor<Budget>())
        #expect(budgets.count == 1)
        let records = try context.fetch(FetchDescriptor<BillRecord>())
        #expect(records.count == 1)
        #expect(record.budget == nil)
        // The record keeps its own data and balance effect.
        #expect(record.note == "午餐")
        #expect(wallet.holdings.first?.amount == 900)
    }

    /// When a monthly budget period ends, the leftover is distributed to
    /// savings plans in order: full amounts while possible, then the remainder
    /// goes to the first plan that doesn't fit (or has allRemaining on).
    @MainActor
    @Test func savingsSettlementDistributesLeftover() throws {
        let context = try makeContext()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!

        let wallet = Wallet(name: "A", source: .alipay, holdings: [Holding(currencyRaw: "cny", amount: 1000)])
        context.insert(wallet)
        let budget = Budget(icon: "fork.knife", name: "预算", wallet: wallet, currency: .cny, amount: 500, period: .monthly)
        budget.createdAt = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        context.insert(budget)
        let goalA = SavingsGoal(name: "旅行", imageData: nil, currency: .cny, amount: 3000)
        let goalB = SavingsGoal(name: "买电脑", imageData: nil, currency: .cny, amount: 8000)
        context.insert(goalA)
        context.insert(goalB)
        // Plan A needs 100, plan B needs 500.
        context.insert(SavingsPlan(budget: budget, goal: goalA, amount: 100, allRemaining: false, sortOrder: 0))
        context.insert(SavingsPlan(budget: budget, goal: goalB, amount: 500, allRemaining: false, sortOrder: 1))

        // 200 spent in the previous month → leftover 300.
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10))!
        let spentDate = calendar.date(from: DateComponents(year: 2026, month: 8, day: 15))!
        let expense = BillRecord(kind: .expense, amount: 200, currency: .cny, categoryKey: "category.dining", subcategory: nil, note: "吃饭", date: spentDate, wallet: wallet, budget: budget)
        context.insert(expense)
        expense.applyBalanceEffect()
        try context.save()

        SavingsSettlement.processCompletedPeriods(context: context, now: now)
        try context.save()

        let savings = try context.fetch(FetchDescriptor<BillRecord>())
            .filter { $0.kind == .saving }
            .sorted { $0.amount < $1.amount }
        // A gets 100 (full), B gets the remaining 200 (300 - 100 < 500).
        #expect(savings.count == 2)
        #expect(savings[0].amount == 100)
        #expect(savings[0].savingsGoal === goalA)
        #expect(savings[1].amount == 200)
        #expect(savings[1].savingsGoal === goalB)
        #expect(savings[0].note == "旅行-自动攒钱")
        // Wallet: 1000 - 200 (expense); savings do not touch wallet balances.
        #expect(wallet.holdings.first?.amount == 800)
        // Budget marked as processed; running again creates nothing new.
        #expect(budget.lastSavingsProcessed != nil)
        SavingsSettlement.processCompletedPeriods(context: context, now: now)
        #expect(try context.fetch(FetchDescriptor<BillRecord>()).filter { $0.kind == .saving }.count == 2)
    }

    /// A plan with allRemaining on receives the entire leftover.
    @MainActor
    @Test func savingsSettlementAllRemaining() throws {
        let context = try makeContext()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!

        let wallet = Wallet(name: "A", source: .alipay, holdings: [Holding(currencyRaw: "cny", amount: 1000)])
        context.insert(wallet)
        let budget = Budget(icon: "fork.knife", name: "预算", wallet: wallet, currency: .cny, amount: 500, period: .monthly)
        budget.createdAt = calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))!
        context.insert(budget)
        let goal = SavingsGoal(name: "应急", imageData: nil, currency: .cny, amount: 1000)
        context.insert(goal)
        context.insert(SavingsPlan(budget: budget, goal: goal, amount: 0, allRemaining: true, sortOrder: 0))
        try context.save()

        // Nothing spent → full 500 leftover goes to the allRemaining plan.
        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10))!
        SavingsSettlement.processCompletedPeriods(context: context, now: now)

        let savings = try context.fetch(FetchDescriptor<BillRecord>()).filter { $0.kind == .saving }
        #expect(savings.count == 1)
        #expect(savings[0].amount == 500)
        #expect(wallet.holdings.first?.amount == 1000)
    }

    /// A subscription whose lastGeneratedDate is set at creation
    /// (auto backfill off) produces no records for the elapsed period.
    @MainActor
    @Test func subscriptionBackfillSkipped() throws {
        let context = try makeContext()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!

        let wallet = Wallet(name: "A", source: .alipay, holdings: [Holding(currencyRaw: "cny", amount: 1000)])
        context.insert(wallet)

        let start = calendar.date(byAdding: .month, value: -3, to: .now)!
        // Backfill on: nil lastGeneratedDate → past renewals are generated.
        let backfilled = Subscription(name: "A", imageData: nil, presetIcon: nil, amount: 10, currency: .cny, convertedAmount: nil, wallet: wallet, startDate: start, periodDays: 30, advanceDays: 0, isEnabled: true)
        // Backfill off: lastGeneratedDate = now → nothing for the elapsed period.
        let skipped = Subscription(name: "B", imageData: nil, presetIcon: nil, amount: 10, currency: .cny, convertedAmount: nil, wallet: wallet, startDate: start, periodDays: 30, advanceDays: 0, isEnabled: true)
        skipped.lastGeneratedDate = .now
        context.insert(backfilled)
        context.insert(skipped)
        try context.save()

        SubscriptionBilling.generateDueBills(context: context)

        let recordsA = try context.fetch(FetchDescriptor<BillRecord>()).filter { $0.subscription === backfilled }
        let recordsB = try context.fetch(FetchDescriptor<BillRecord>()).filter { $0.subscription === skipped }
        #expect(recordsA.count >= 3)
        #expect(recordsB.isEmpty)
    }

    /// A budget created mid-period must not settle the previous period;
    /// saving starts when its first own period ends.
    @MainActor
    @Test func newBudgetDoesNotSettlePreviousPeriod() throws {
        let context = try makeContext()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai")!

        let wallet = Wallet(name: "A", source: .alipay, holdings: [Holding(currencyRaw: "cny", amount: 1000)])
        context.insert(wallet)
        let goal = SavingsGoal(name: "旅行", imageData: nil, currency: .cny, amount: 3000)
        context.insert(goal)

        // Budget created on 2026-09-10; "now" is 2026-09-20 — the August period
        // completed before the budget existed and must not be settled.
        let budget = Budget(icon: "fork.knife", name: "预算", wallet: wallet, currency: .cny, amount: 500, period: .monthly)
        budget.createdAt = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10))!
        context.insert(budget)
        context.insert(SavingsPlan(budget: budget, goal: goal, amount: 100, allRemaining: false, sortOrder: 0))
        try context.save()

        let now = calendar.date(from: DateComponents(year: 2026, month: 9, day: 20))!
        SavingsSettlement.processCompletedPeriods(context: context, now: now)

        let savings = try context.fetch(FetchDescriptor<BillRecord>()).filter { $0.kind == .saving }
        #expect(savings.isEmpty)
        #expect(budget.lastSavingsProcessed == nil)
    }
}
