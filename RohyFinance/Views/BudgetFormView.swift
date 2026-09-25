//
//  BudgetFormView.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI
import SwiftData

/// Form for adding or editing a budget.
struct BudgetFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var wallets: [Wallet]

    /// Non-nil when editing an existing budget.
    let budget: Budget?

    @State private var icon: String?
    @State private var name = ""
    @State private var wallet: Wallet?
    @State private var currency: Currency?
    @State private var intPart = ""
    @State private var fracPart = ""
    @State private var period: BudgetPeriod = .monthly
    @State private var errorMessage: String?

    /// Preset icons: the expense category symbols.
    private let presetSymbols = CategoryStore.expenses.map(\.icon)

    init(budget: Budget? = nil) {
        self.budget = budget
        if let budget {
            _icon = State(initialValue: budget.icon)
            _name = State(initialValue: budget.name)
            _wallet = State(initialValue: budget.wallet)
            _currency = State(initialValue: budget.currency)
            _period = State(initialValue: budget.period)
            let cents = Int((budget.amount * 100).rounded())
            if cents != 0 {
                _intPart = State(initialValue: String(cents / 100))
                _fracPart = State(initialValue: String(format: "%02d", cents % 100))
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    IconGrid(symbols: presetSymbols, selection: $icon)
                    HStack {
                        Text("Name")
                        TextField("Enter name", text: $name)
                    }
                }

                Section("Budget") {
                    walletPicker

                    currencyPicker

                    HStack {
                        Text("Amount")
                        AmountField(intPart: $intPart, fracPart: $fracPart)
                    }

                    Picker(selection: $period) {
                        ForEach(BudgetPeriod.allCases) { period in
                            Text(period.localizedName).tag(period)
                        }
                    } label: {
                        Text("Period")
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle(budget == nil ? String(localized: "Add Budget") : String(localized: "Edit Budget"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        confirm()
                    } label: {
                        Label("Done", systemImage: "checkmark")
                    }
                }
            }
            .alert("Notice", isPresented: errorPresented) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onChange(of: wallet) { _, newValue in
                guard let newValue else {
                    currency = nil
                    return
                }
                if let currency, newValue.supports(currency) {
                    return
                }
                currency = newValue.defaultCurrency
            }
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private var walletPicker: some View {
        Picker(selection: $wallet) {
            Text("Select").tag(Wallet?.none)
            ForEach(wallets) { wallet in
                walletMenuLabel(wallet)
                    .tag(Wallet?.some(wallet))
            }
        } label: {
            Text("Wallet")
        }
        .pickerStyle(.menu)
    }

    private var currencyPicker: some View {
        Picker(selection: $currency) {
            Text("Select").tag(Currency?.none)
            ForEach(wallet?.holdings.map(\.currency) ?? []) { currency in
                Text("\(currency.symbol) \(currency.localizedName)")
                    .tag(Currency?.some(currency))
            }
        } label: {
            Text("Currency")
        }
        .pickerStyle(.menu)
        .disabled(wallet == nil || (wallet?.holdings.count ?? 0) <= 1)
    }

    @ViewBuilder
    private func walletMenuLabel(_ wallet: Wallet) -> some View {
        if wallet.source.assetName != nil {
            Label {
                Text(wallet.displayName)
            } icon: {
                SourceIconView(source: wallet.source, size: 20)
            }
        } else {
            Text("\(wallet.source.emoji ?? "") \(wallet.displayName)")
        }
    }

    private func confirm() {
        guard let icon else {
            return fail(String(localized: "Please select an icon"))
        }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return fail(String(localized: "Please enter a name"))
        }
        guard let wallet else {
            return fail(String(localized: "Please select a wallet"))
        }
        guard let currency else {
            return fail(String(localized: "Please select a currency"))
        }
        let amount = (Double(intPart) ?? 0) + (Double(fracPart) ?? 0) / 100
        guard amount > 0 else {
            return fail(String(localized: "Please enter an amount"))
        }

        if let budget {
            budget.icon = icon
            budget.name = trimmed
            budget.wallet = wallet
            budget.currencyRaw = currency.rawValue
            budget.amount = amount
            budget.periodRaw = period.rawValue
            // Editing a budget unlinks all records that counted towards it.
            let linked = (try? modelContext.fetch(FetchDescriptor<BillRecord>())) ?? []
            for record in linked where record.budget === budget {
                record.budget = nil
            }
        } else {
            modelContext.insert(Budget(
                icon: icon,
                name: trimmed,
                wallet: wallet,
                currency: currency,
                amount: amount,
                period: period
            ))
        }
        dismiss()
    }

    private func fail(_ message: String) {
        errorMessage = message
    }
}

#Preview {
    BudgetFormView()
        .modelContainer(for: [Wallet.self, BillRecord.self, Subcategory.self, Subscription.self, Budget.self], inMemory: true)
}
