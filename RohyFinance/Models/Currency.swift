//
//  Currency.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import Foundation

enum Currency: String, Codable, CaseIterable, Identifiable {
    case cny
    case usd
    case gbp
    case jpy
    case krw
    case inr
    case chf
    case hkd
    case twd

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .cny: return "￥"
        case .usd: return "$"
        case .gbp: return "£"
        case .jpy: return "JP¥"
        case .krw: return "₩"
        case .inr: return "₹"
        case .chf: return "₣"
        case .hkd: return "HK$"
        case .twd: return "NT$"
        }
    }

    var localizedName: String {
        switch self {
        case .cny: return String(localized: "Renminbi")
        case .usd: return String(localized: "US Dollar")
        case .gbp: return String(localized: "British Pound")
        case .jpy: return String(localized: "Japanese Yen")
        case .krw: return String(localized: "South Korean Won")
        case .inr: return String(localized: "Indian Rupee")
        case .chf: return String(localized: "Swiss Franc")
        case .hkd: return String(localized: "Hong Kong Dollar")
        case .twd: return String(localized: "New Taiwan Dollar")
        }
    }

    /// Default currency inferred from the system region; USD when unsupported.
    static func defaultForLocale(_ locale: Locale = .current) -> Currency {
        switch locale.region?.identifier {
        case "CN": return .cny
        case "GB": return .gbp
        case "JP": return .jpy
        case "KR": return .krw
        case "IN": return .inr
        case "CH": return .chf
        case "HK": return .hkd
        case "TW": return .twd
        default: return .usd
        }
    }
}

/// A balance in one currency held by a wallet.
struct Holding: Codable, Hashable {
    var currencyRaw: String
    var amount: Double

    var currency: Currency {
        Currency(rawValue: currencyRaw) ?? .cny
    }
}
