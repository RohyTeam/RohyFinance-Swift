//
//  Wallet.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import Foundation
import SwiftData

enum WalletSource: String, Codable, CaseIterable, Identifiable {
    case cash
    case wechatPay
    case alipay
    case boc
    case icbc
    case cmb

    var id: String { rawValue }

    /// Sources the user can pick when adding a wallet.
    static let addable: [WalletSource] = [.wechatPay, .alipay, .boc, .icbc, .cmb]

    var assetName: String? {
        switch self {
        case .cash: return nil
        case .wechatPay: return "wechat_pay"
        case .alipay: return "alipay"
        case .boc: return "boc"
        case .icbc: return "icbc"
        case .cmb: return "cmb"
        }
    }

    var emoji: String? {
        self == .cash ? "💰" : nil
    }

    var localizedName: String {
        switch self {
        case .cash: return String(localized: "Cash")
        case .wechatPay: return String(localized: "WeChat Wallet")
        case .alipay: return String(localized: "Alipay Wallet")
        case .boc: return String(localized: "Bank of China")
        case .icbc: return String(localized: "ICBC")
        case .cmb: return String(localized: "China Merchants Bank")
        }
    }
}

@Model
final class Wallet {
    var name: String = ""
    var sourceRaw: String = WalletSource.cash.rawValue
    var holdings: [Holding] = []
    var isDefault: Bool = false

    init(name: String, source: WalletSource, holdings: [Holding], isDefault: Bool = false) {
        self.name = name
        self.sourceRaw = source.rawValue
        self.holdings = holdings
        self.isDefault = isDefault
    }

    var source: WalletSource {
        WalletSource(rawValue: sourceRaw) ?? .cash
    }

    var displayName: String {
        name
    }

    /// The wallet's default currency: the first holding's currency
    /// (for a single-currency wallet, simply its only currency).
    var defaultCurrency: Currency? {
        holdings.first?.currency
    }

    func supports(_ currency: Currency) -> Bool {
        holdings.contains { $0.currencyRaw == currency.rawValue }
    }

    func adjust(_ currency: Currency, by delta: Double) {
        if let index = holdings.firstIndex(where: { $0.currencyRaw == currency.rawValue }) {
            holdings[index].amount += delta
        } else {
            holdings.append(Holding(currencyRaw: currency.rawValue, amount: delta))
        }
    }
}
