//
//  Category.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI

struct CategoryDef: Identifiable, Hashable {
    /// Localization key into Localizable.xcstrings, also persisted on BillRecord.
    let key: String
    /// SF Symbol name.
    let icon: String

    var id: String { key }

    var name: String {
        String(localized: String.LocalizationValue(key))
    }
}

enum CategoryStore {
    static let expenses: [CategoryDef] = [
        CategoryDef(key: "category.dining", icon: "fork.knife"),
        CategoryDef(key: "category.clothing", icon: "tshirt"),
        CategoryDef(key: "category.transport", icon: "bus"),
        CategoryDef(key: "category.daily", icon: "basket"),
        CategoryDef(key: "category.games", icon: "gamecontroller"),
        CategoryDef(key: "category.vegetables", icon: "carrot"),
        CategoryDef(key: "category.fruits", icon: "leaf"),
        CategoryDef(key: "category.snacks", icon: "popcorn"),
        CategoryDef(key: "category.sports", icon: "figure.run"),
        CategoryDef(key: "category.study", icon: "graduationcap"),
        CategoryDef(key: "category.books", icon: "book"),
        CategoryDef(key: "category.communication", icon: "phone"),
        CategoryDef(key: "category.beauty", icon: "sparkles"),
        CategoryDef(key: "category.subscription", icon: "calendar"),
    ]

    static let incomes: [CategoryDef] = [
        CategoryDef(key: "category.salary", icon: "banknote"),
        CategoryDef(key: "category.lottery", icon: "ticket"),
        CategoryDef(key: "category.luckyMoney", icon: "envelope"),
        CategoryDef(key: "category.scholarship", icon: "medal"),
    ]

    static let all: [CategoryDef] = expenses + incomes

    static func find(_ key: String) -> CategoryDef? {
        all.first { $0.key == key }
    }
}
