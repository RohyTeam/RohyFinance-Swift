//
//  BillDetailView.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI
import UIKit

/// Read-only half-modal showing a record's details.
struct BillDetailView: View {
    @Environment(\.dismiss) private var dismiss
    let record: BillRecord

    private var amountColor: Color {
        switch record.kind {
        case .expense: return .red
        case .income: return .green
        case .transfer: return .secondary
        case .saving: return .blue
        }
    }

    private var amountText: String {
        switch record.kind {
        case .expense: return "-\(moneyText(record.effectiveAmount, currency: record.currency))"
        case .income: return "+\(moneyText(record.effectiveAmount, currency: record.currency))"
        case .transfer, .saving: return moneyText(record.amount, currency: record.currency)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                if let imageData = record.imageData, let image = UIImage(data: imageData) {
                    Section {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .listRowInsets(EdgeInsets())
                    }
                }

                Section("Info") {
                    row("Kind", value: record.kind.localizedName)
                    if let category = CategoryStore.find(record.categoryKey) {
                        HStack {
                            Text("Category")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: category.icon)
                            Text(category.name)
                        }
                        .foregroundStyle(.secondary)
                    }
                    if let subcategory = record.subcategory {
                        row("Subcategory", value: subcategory)
                    }
                    row("Note", value: record.note)
                }

                Section("Amount") {
                    HStack {
                        Text("Amount")
                        Spacer()
                        Text(amountText)
                            .foregroundStyle(amountColor)
                    }
                    if let tax = record.taxAmount {
                        row("Tax amount", value: moneyText(tax, currency: record.currency))
                    }
                    if let discount = record.discountAmount {
                        row("Discount amount", value: moneyText(discount, currency: record.currency))
                    }
                    if let consumptionTax = record.consumptionTaxAmount {
                        row("Consumption Tax", value: moneyText(consumptionTax, currency: record.currency))
                    }
                    if let fee = record.feeAmount {
                        row("Fee amount", value: moneyText(fee, currency: record.currency))
                    }
                }

                Section("Funds") {
                    walletRow("Wallet", wallet: record.wallet)
                    if record.kind == .transfer {
                        walletRow("Target", wallet: record.targetWallet)
                    }
                    if let budget = record.budget {
                        row("Budget", value: budget.name)
                    }
                    if let goal = record.savingsGoal {
                        HStack {
                            Text("Savings Goal")
                                .foregroundStyle(.primary)
                            Spacer()
                            GoalIcon(goal: goal, size: 18)
                            Text(goal.name)
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                Section("Time") {
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(record.date, format: .dateTime.year().month().day())
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Time")
                        Spacer()
                        Text(record.date, format: .dateTime.hour().minute())
                            .foregroundStyle(.secondary)
                    }
                }

                if let app = record.app, let data = app.imageData, let image = UIImage(data: data) {
                    Section("Software") {
                        HStack {
                            Text("Source")
                            Spacer()
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                }
            }
            .navigationTitle("Record Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }

    private func row(_ title: LocalizedStringKey, value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }

    private func walletRow(_ title: LocalizedStringKey, wallet: Wallet?) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)
            Spacer()
            WalletIconView(wallet: wallet, size: 18)
            Text(wallet?.displayName ?? "-")
        }
        .foregroundStyle(.secondary)
    }
}
