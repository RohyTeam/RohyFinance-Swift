//
//  Formatters.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import Foundation

func moneyText(_ value: Double, currency: Currency) -> String {
    String(format: "%@%.2f", currency.symbol, value)
}

func signedMoneyText(_ value: Double, currency: Currency) -> String {
    let sign = value >= 0 ? "+" : "-"
    return "\(sign)\(moneyText(abs(value), currency: currency))"
}

/// Width of one character in "字": CJK (Chinese/Japanese/Korean) counts as 1,
/// anything else (e.g. Latin letters) counts as half — two letters equal one 字.
private func characterWidth(_ character: Character) -> Double {
    let isCJK = character.unicodeScalars.contains { scalar in
        switch scalar.value {
        case 0x1100...0x11FF,   // Hangul Jamo
             0x2E80...0x9FFF,   // CJK radicals, Kana, CJK ideographs (incl. Ext. A)
             0xAC00...0xD7AF,   // Hangul syllables
             0xF900...0xFAFF,   // CJK compatibility ideographs
             0xFF00...0xFF65:   // Fullwidth forms
            return true
        default:
            return false
        }
    }
    return isCJK ? 1 : 0.5
}

/// Length of text in 字 (CJK = 1 per character, others = 0.5).
/// Leading/trailing whitespace is ignored; within the text, spaces are grouped
/// by consecutive runs and each run counts one less (a single space between
/// words costs nothing, so letter languages don't waste length on word gaps).
func characterCount(of text: String) -> Double {
    var count = 0.0
    var spaceRun = 0
    for character in text.trimmingCharacters(in: .whitespaces) {
        if character == " " {
            // The first space of a run is free; every extra space costs 0.5.
            spaceRun += 1
            if spaceRun > 1 { count += 0.5 }
            continue
        }
        spaceRun = 0
        count += characterWidth(character)
    }
    return count
}

/// Truncates text so its length does not exceed the given number of 字.
/// Applies the same whitespace rules as `characterCount(of:)`.
func truncatedToCharacterCount(_ text: String, limit: Int) -> String {
    var count = 0.0
    var spaceRun = 0
    var result = ""
    for character in text.trimmingCharacters(in: .whitespaces) {
        let width: Double
        if character == " " {
            spaceRun += 1
            width = spaceRun > 1 ? 0.5 : 0
        } else {
            spaceRun = 0
            width = characterWidth(character)
        }
        if count + width > Double(limit) { break }
        count += width
        result.append(character)
    }
    return result
}
