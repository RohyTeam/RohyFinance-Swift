//
//  QuickRecord.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import Foundation
import SwiftData

/// A quick record (快捷记账): a template that creates a bill with one tap.
@Model
final class QuickRecord {
    var imageData: Data?
    var kindRaw: String = RecordKind.expense.rawValue
    var amount: Double = 0
    var currencyRaw: String = Currency.cny.rawValue
    var categoryKey: String = ""
    var subcategory: String?
    var note: String = ""
    var wallet: Wallet?
    var targetWallet: Wallet?
    var targetCurrencyRaw: String?
    var budget: Budget?
    var savingsGoal: SavingsGoal?
    var taxAmount: Double?
    var discountAmount: Double?
    var consumptionTaxAmount: Double?
    var feeAmount: Double?
    var convertedAmount: Double?
    var convertedTaxAmount: Double?
    var convertedDiscountAmount: Double?
    var convertedConsumptionTaxAmount: Double?
    var sortOrder: Int = 0

    init(draft: RecordDraft, imageData: Data?, sortOrder: Int) {
        self.imageData = imageData
        self.sortOrder = sortOrder
        update(from: draft, imageData: imageData)
    }

    var kind: RecordKind {
        RecordKind(rawValue: kindRaw) ?? .expense
    }

    var currency: Currency {
        Currency(rawValue: currencyRaw) ?? .cny
    }

    /// A draft for the current moment, ready to materialize as a BillRecord.
    var draft: RecordDraft {
        RecordDraft(
            kind: kind,
            amount: amount,
            currency: currency,
            categoryKey: categoryKey,
            subcategory: subcategory,
            note: note,
            date: .now,
            wallet: wallet,
            targetWallet: targetWallet,
            targetCurrencyRaw: targetCurrencyRaw,
            budget: budget,
            savingsGoal: savingsGoal,
            taxAmount: taxAmount,
            discountAmount: discountAmount,
            consumptionTaxAmount: consumptionTaxAmount,
            feeAmount: feeAmount,
            convertedAmount: convertedAmount,
            convertedTaxAmount: convertedTaxAmount,
            convertedDiscountAmount: convertedDiscountAmount,
            convertedConsumptionTaxAmount: convertedConsumptionTaxAmount
        )
    }

    /// Creates the bill, applies its balance effect, and inserts it.
    @discardableResult
    func makeRecord(context: ModelContext) -> BillRecord {
        let record = draft.makeRecord()
        draft.applyBalanceEffect()
        context.insert(record)
        return record
    }

    func update(from draft: RecordDraft, imageData: Data?) {
        self.imageData = imageData
        kindRaw = draft.kind.rawValue
        amount = draft.amount
        currencyRaw = draft.currency.rawValue
        categoryKey = draft.categoryKey
        subcategory = draft.subcategory
        note = draft.note
        wallet = draft.wallet
        targetWallet = draft.targetWallet
        targetCurrencyRaw = draft.targetCurrencyRaw
        budget = draft.budget
        savingsGoal = draft.savingsGoal
        taxAmount = draft.taxAmount
        discountAmount = draft.discountAmount
        consumptionTaxAmount = draft.consumptionTaxAmount
        feeAmount = draft.feeAmount
        convertedAmount = draft.convertedAmount
        convertedTaxAmount = draft.convertedTaxAmount
        convertedDiscountAmount = draft.convertedDiscountAmount
        convertedConsumptionTaxAmount = draft.convertedConsumptionTaxAmount
    }
}
