//
//  ConversionMode.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import Foundation

enum ConversionMode: String, CaseIterable, Identifiable {
    case rate
    case value

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .rate: return String(localized: "Rate")
        case .value: return String(localized: "Value")
        }
    }
}
