//
//  BillRecord.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import Foundation
import SwiftData

enum RecordKind: String, Codable, CaseIterable, Identifiable {
    case expense
    case income
    case transfer

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .expense: return String(localized: "Expense")
        case .income: return String(localized: "Income")
        case .transfer: return String(localized: "Transfer")
        }
    }
}

@Model
final class BillRecord {
    var kindRaw: String = RecordKind.expense.rawValue
    var amount: Double = 0
    var currencyRaw: String = Currency.cny.rawValue
    var categoryKey: String = ""
    var subcategory: String?
    var note: String = ""
    var date: Date = Date.now
    var wallet: Wallet?
    var targetWallet: Wallet?
    /// Transfer only: currency the target wallet received.
    var targetCurrencyRaw: String?
    /// Set when the record was auto-created by a subscription renewal.
    var subscription: Subscription?
    /// Income: tax deducted from the pre-tax amount.
    var taxAmount: Double?
    /// Expense: discount deducted from the original price.
    var discountAmount: Double?
    /// Expense: consumption tax paid additionally on top of the price.
    var consumptionTaxAmount: Double?
    /// Transfer: fee charged on top of the transferred amount.
    var feeAmount: Double?
    /// Values converted to the default currency (nil when currency == default).
    var convertedAmount: Double?
    var convertedTaxAmount: Double?
    var convertedDiscountAmount: Double?
    var convertedConsumptionTaxAmount: Double?

    init(kind: RecordKind, amount: Double, currency: Currency, categoryKey: String, subcategory: String?, note: String, date: Date, wallet: Wallet?, targetWallet: Wallet? = nil, targetCurrencyRaw: String? = nil, taxAmount: Double? = nil, discountAmount: Double? = nil, consumptionTaxAmount: Double? = nil, feeAmount: Double? = nil, convertedAmount: Double? = nil, convertedTaxAmount: Double? = nil, convertedDiscountAmount: Double? = nil, convertedConsumptionTaxAmount: Double? = nil) {
        self.kindRaw = kind.rawValue
        self.amount = amount
        self.currencyRaw = currency.rawValue
        self.categoryKey = categoryKey
        self.subcategory = subcategory
        self.note = note
        self.date = date
        self.wallet = wallet
        self.targetWallet = targetWallet
        self.targetCurrencyRaw = targetCurrencyRaw
        self.taxAmount = taxAmount
        self.discountAmount = discountAmount
        self.consumptionTaxAmount = consumptionTaxAmount
        self.feeAmount = feeAmount
        self.convertedAmount = convertedAmount
        self.convertedTaxAmount = convertedTaxAmount
        self.convertedDiscountAmount = convertedDiscountAmount
        self.convertedConsumptionTaxAmount = convertedConsumptionTaxAmount
    }

    var kind: RecordKind {
        RecordKind(rawValue: kindRaw) ?? .expense
    }

    var currency: Currency {
        Currency(rawValue: currencyRaw) ?? .cny
    }

    /// The value that actually affects statistics and wallet balances, in the original currency.
    var effectiveAmount: Double {
        switch kind {
        case .income:
            return amount - (taxAmount ?? 0)
        case .expense:
            return amount - (discountAmount ?? 0) + (consumptionTaxAmount ?? 0)
        case .transfer:
            return amount
        }
    }

    /// The effective value expressed in the given (default) currency.
    func effective(in defaultCurrency: Currency) -> Double {
        if currency == defaultCurrency { return effectiveAmount }
        switch kind {
        case .income:
            return (convertedAmount ?? amount) - (convertedTaxAmount ?? 0)
        case .expense:
            return (convertedAmount ?? amount) - (convertedDiscountAmount ?? 0) + (convertedConsumptionTaxAmount ?? 0)
        case .transfer:
            return convertedAmount ?? amount
        }
    }

    /// Transfer only: currency the target wallet received (defaults to the source currency).
    var targetCurrency: Currency {
        targetCurrencyRaw.flatMap(Currency.init(rawValue:)) ?? currency
    }

    /// Applies this record's effect on wallet balances.
    func applyBalanceEffect() {
        switch kind {
        case .expense:
            wallet?.adjust(currency, by: -effectiveAmount)
        case .income:
            wallet?.adjust(currency, by: effectiveAmount)
        case .transfer:
            wallet?.adjust(currency, by: -(amount + (feeAmount ?? 0)))
            targetWallet?.adjust(targetCurrency, by: convertedAmount ?? amount)
        }
    }

    /// Reverts this record's effect on wallet balances (used before edit/delete).
    func revertBalanceEffect() {
        switch kind {
        case .expense:
            wallet?.adjust(currency, by: effectiveAmount)
        case .income:
            wallet?.adjust(currency, by: -effectiveAmount)
        case .transfer:
            wallet?.adjust(currency, by: amount + (feeAmount ?? 0))
            targetWallet?.adjust(targetCurrency, by: -(convertedAmount ?? amount))
        }
    }

    /// Copies all editable fields from a draft (used when saving an edit).
    func update(from draft: RecordDraft) {
        kindRaw = draft.kind.rawValue
        amount = draft.amount
        currencyRaw = draft.currency.rawValue
        categoryKey = draft.categoryKey
        subcategory = draft.subcategory
        note = draft.note
        date = draft.date
        wallet = draft.wallet
        targetWallet = draft.targetWallet
        targetCurrencyRaw = draft.targetCurrencyRaw
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

/// Value-type snapshot of a record's editable fields.
/// Used instead of instantiating BillRecord directly when editing: assigning a
/// managed wallet to a new @Model's relationship implicitly inserts it into the
/// context, which would duplicate the record being edited.
struct RecordDraft {
    var kind: RecordKind
    var amount: Double
    var currency: Currency
    var categoryKey: String
    var subcategory: String? = nil
    var note: String
    var date: Date
    var wallet: Wallet?
    var targetWallet: Wallet? = nil
    var targetCurrencyRaw: String? = nil
    var taxAmount: Double? = nil
    var discountAmount: Double? = nil
    var consumptionTaxAmount: Double? = nil
    var feeAmount: Double? = nil
    var convertedAmount: Double? = nil
    var convertedTaxAmount: Double? = nil
    var convertedDiscountAmount: Double? = nil
    var convertedConsumptionTaxAmount: Double? = nil

    /// Effective value in the original currency.
    var effectiveAmount: Double {
        switch kind {
        case .income:
            return amount - (taxAmount ?? 0)
        case .expense:
            return amount - (discountAmount ?? 0) + (consumptionTaxAmount ?? 0)
        case .transfer:
            return amount
        }
    }

    var targetCurrency: Currency {
        targetCurrencyRaw.flatMap(Currency.init(rawValue:)) ?? currency
    }

    /// Applies the draft's effect on wallet balances.
    func applyBalanceEffect() {
        switch kind {
        case .expense:
            wallet?.adjust(currency, by: -effectiveAmount)
        case .income:
            wallet?.adjust(currency, by: effectiveAmount)
        case .transfer:
            wallet?.adjust(currency, by: -(amount + (feeAmount ?? 0)))
            targetWallet?.adjust(targetCurrency, by: convertedAmount ?? amount)
        }
    }

    /// Creates a new record from the draft.
    func makeRecord() -> BillRecord {
        BillRecord(
            kind: kind,
            amount: amount,
            currency: currency,
            categoryKey: categoryKey,
            subcategory: subcategory,
            note: note,
            date: date,
            wallet: wallet,
            targetWallet: targetWallet,
            targetCurrencyRaw: targetCurrencyRaw,
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
}
