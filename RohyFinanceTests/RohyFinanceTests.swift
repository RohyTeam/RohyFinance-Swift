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
}
