//
//  Savings.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import Foundation
import SwiftData

/// A savings goal (攒钱): a named piggy bank with a target amount in one currency.
@Model
final class SavingsGoal {
    var name: String = ""
    /// Custom image imported from the photo library (optional).
    var imageData: Data?
    var currencyRaw: String = Currency.cny.rawValue
    /// The target amount to save.
    var amount: Double = 0

    init(name: String, imageData: Data?, currency: Currency, amount: Double) {
        self.name = name
        self.imageData = imageData
        self.currencyRaw = currency.rawValue
        self.amount = amount
    }

    var currency: Currency {
        Currency(rawValue: currencyRaw) ?? .cny
    }
}

/// A savings plan (攒钱计划): allocates a budget's period leftover to a goal.
@Model
final class SavingsPlan {
    var budget: Budget?
    var goal: SavingsGoal?
    /// Amount to save per period (ignored when allRemaining is on).
    var amount: Double = 0
    /// When on, the whole remaining budget goes to this plan.
    var allRemaining: Bool = false
    var sortOrder: Int = 0

    init(budget: Budget?, goal: SavingsGoal?, amount: Double, allRemaining: Bool, sortOrder: Int) {
        self.budget = budget
        self.goal = goal
        self.amount = amount
        self.allRemaining = allRemaining
        self.sortOrder = sortOrder
    }
}
