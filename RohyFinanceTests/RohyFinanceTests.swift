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
            for: Wallet.self, BillRecord.self, Subcategory.self, Subscription.self,
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
}
