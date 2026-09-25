//
//  WalletsView.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI
import SwiftData

struct WalletsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var wallets: [Wallet]
    @Query private var records: [BillRecord]
    @Query private var budgets: [Budget]
    @State private var showAddWallet = false
    @State private var showAddBudget = false
    @State private var showSavingsComingSoon = false
    @State private var editingWallet: Wallet?
    @State private var editingBudget: Budget?
    @State private var errorMessage: String?

    private var sortedWallets: [Wallet] {
        wallets.sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            List {
                Section("Wallets") {
                    ForEach(sortedWallets) { wallet in
                        HStack(spacing: 12) {
                            WalletIconView(wallet: wallet, size: 32)
                            Text(wallet.displayName)
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                ForEach(wallet.holdings, id: \.currencyRaw) { holding in
                                    Text(moneyText(holding.amount, currency: holding.currency))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                delete(wallet)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                editingWallet = wallet
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                    }
                }

                if !budgets.isEmpty {
                    Section("Budgets") {
                        ForEach(budgets) { budget in
                            HStack(spacing: 12) {
                                Image(systemName: budget.icon)
                                    .frame(width: 32, height: 32)
                                Text(budget.name)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(moneyText(budget.amount, currency: budget.currency))
                                        .foregroundStyle(.secondary)
                                    HStack(spacing: 4) {
                                        WalletIconView(wallet: budget.wallet, size: 12)
                                        Text("\(budget.wallet?.displayName ?? "-") · \(budget.period.localizedName)")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    modelContext.delete(budget)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    editingBudget = budget
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.orange)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Assets")
            .overlay {
                if wallets.isEmpty {
                    Text("No wallets yet")
                        .foregroundStyle(.secondary)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showAddWallet = true
                        } label: {
                            Label("Add Wallet", systemImage: "wallet.pass")
                        }
                        Button {
                            showAddBudget = true
                        } label: {
                            Label("Add Budget", systemImage: "chart.pie")
                        }
                        Button {
                            showSavingsComingSoon = true
                        } label: {
                            Label("Add Savings Goal", systemImage: "chart.line.uptrend.xyaxis")
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddWallet) {
                WalletFormView()
                    .presentationDetents([.large])
            }
            .sheet(isPresented: $showAddBudget) {
                BudgetFormView()
                    .presentationDetents([.large])
            }
            .sheet(item: $editingBudget) { budget in
                BudgetFormView(budget: budget)
                    .presentationDetents([.large])
            }
            .alert("Notice", isPresented: $showSavingsComingSoon) {
                Button("OK") {}
            } message: {
                Text("Coming Soon")
            }
            .sheet(item: $editingWallet) { wallet in
                WalletFormView(wallet: wallet)
                    .presentationDetents([.large])
            }
            .alert("Notice", isPresented: errorPresented) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func delete(_ wallet: Wallet) {
        let hasRecords = records.contains { $0.wallet === wallet || $0.targetWallet === wallet }
        if hasRecords {
            errorMessage = String(localized: "This wallet has records and cannot be deleted")
        } else {
            modelContext.delete(wallet)
        }
    }
}

private enum WalletMode: String, CaseIterable, Identifiable {
    case single
    case multi

    var id: String { rawValue }

    var localizedName: String {
        switch self {
        case .single: return String(localized: "Single Currency")
        case .multi: return String(localized: "Multi-Currency")
        }
    }
}

/// Form for adding a new wallet or editing an existing one.
struct WalletFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var wallets: [Wallet]
    @AppStorage("defaultCurrency") private var defaultCurrencyRaw = Currency.defaultForLocale().rawValue

    /// nil means adding a new wallet.
    let wallet: Wallet?

    @State private var source: WalletSource?
    @State private var name = ""
    @State private var mode: WalletMode = .single
    // Single-currency amount.
    @State private var singleCurrency: Currency?
    @State private var intPart = ""
    @State private var fracPart = ""
    // Multi-currency rows.
    @State private var rows: [HoldingRow] = [HoldingRow()]
    @State private var errorMessage: String?

    private var defaultCurrency: Currency {
        Currency(rawValue: defaultCurrencyRaw) ?? .usd
    }

    struct HoldingRow: Identifiable {
        let id = UUID()
        var currency: Currency?
        var intPart = ""
        var fracPart = ""

        init(currency: Currency? = nil, amount: Double = 0) {
            self.currency = currency
            let cents = Int((amount * 100).rounded())
            if cents != 0 {
                intPart = String(abs(cents) / 100)
                fracPart = String(format: "%02d", abs(cents) % 100)
            }
        }
    }

    init(wallet: Wallet? = nil) {
        self.wallet = wallet
        if let wallet {
            _source = State(initialValue: wallet.source)
            _name = State(initialValue: wallet.name)
            let holdings = wallet.holdings
            if holdings.count > 1 {
                _mode = State(initialValue: .multi)
                _rows = State(initialValue: holdings.map { HoldingRow(currency: $0.currency, amount: $0.amount) })
            } else if let holding = holdings.first {
                _singleCurrency = State(initialValue: holding.currency)
                let cents = Int((holding.amount * 100).rounded())
                if cents != 0 {
                    _intPart = State(initialValue: String(abs(cents) / 100))
                    _fracPart = State(initialValue: String(format: "%02d", abs(cents) % 100))
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker(selection: $source) {
                    Text("Select").tag(WalletSource?.none)
                    ForEach(WalletSource.addable) { source in
                        Label {
                            Text(source.localizedName)
                        } icon: {
                            SourceIconView(source: source, size: 20)
                        }
                        .tag(WalletSource?.some(source))
                    }
                } label: {
                    Text("Source")
                }
                .pickerStyle(.menu)

                HStack {
                    Text("Name")
                    TextField("Enter name", text: $name)
                }

                HStack {
                    Text("Type")
                    Spacer()
                    Picker("Type", selection: $mode) {
                        ForEach(WalletMode.allCases) { mode in
                            Text(mode.localizedName).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 180)
                }

                if mode == .single {
                    Section("Savings") {
                        Picker(selection: $singleCurrency) {
                            Text("Select").tag(Currency?.none)
                            ForEach(Currency.allCases) { currency in
                                Text("\(currency.symbol) \(currency.localizedName)")
                                    .tag(Currency?.some(currency))
                            }
                        } label: {
                            Text("Currency")
                        }
                        .pickerStyle(.menu)

                        HStack {
                            Text("Amount")
                            AmountField(intPart: $intPart, fracPart: $fracPart)
                        }
                    }
                } else {
                    Section {
                        ForEach($rows) { $row in
                            HStack {
                                Picker(selection: $row.currency) {
                                    Text("Select").tag(Currency?.none)
                                    ForEach(Currency.allCases) { currency in
                                        Text("\(currency.symbol) \(currency.localizedName)")
                                            .tag(Currency?.some(currency))
                                    }
                                } label: {
                                    Text("Currency")
                                }
                                .pickerStyle(.menu)
                                AmountField(intPart: $row.intPart, fracPart: $row.fracPart)
                            }
                            .swipeActions {
                                if rows.count > 1 {
                                    Button(role: .destructive) {
                                        rows.removeAll { $0.id == row.id }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text("Savings")
                            Spacer()
                            Button {
                                rows.append(HoldingRow())
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                    }
                }
            }
            .navigationTitle(wallet == nil ? "Add Wallet" : "Edit Wallet")
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
            .onAppear {
                if wallet == nil && singleCurrency == nil {
                    singleCurrency = defaultCurrency
                }
            }
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func amountValue(_ intPart: String, _ fracPart: String) -> Double {
        (Double(intPart) ?? 0) + (Double(fracPart) ?? 0) / 100
    }

    private func confirm() {
        guard let source else {
            errorMessage = String(localized: "Please select a source")
            return
        }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = String(localized: "Please enter a wallet name")
            return
        }
        let nameTaken = wallets.contains { other in
            other.name == trimmed && other !== wallet
        }
        guard !nameTaken else {
            errorMessage = String(localized: "Wallet name already exists")
            return
        }

        let holdings: [Holding]
        switch mode {
        case .single:
            guard let singleCurrency else {
                errorMessage = String(localized: "Please select a currency")
                return
            }
            holdings = [Holding(currencyRaw: singleCurrency.rawValue, amount: amountValue(intPart, fracPart))]
        case .multi:
            let valid = rows.compactMap { row -> Holding? in
                guard let currency = row.currency else { return nil }
                return Holding(currencyRaw: currency.rawValue, amount: amountValue(row.intPart, row.fracPart))
            }
            guard !valid.isEmpty else {
                errorMessage = String(localized: "At least one currency is required")
                return
            }
            holdings = valid
        }

        if let wallet {
            wallet.sourceRaw = source.rawValue
            wallet.name = trimmed
            wallet.holdings = holdings
        } else {
            modelContext.insert(Wallet(name: trimmed, source: source, holdings: holdings))
        }
        dismiss()
    }
}

#Preview {
    WalletsView()
        .modelContainer(for: [Wallet.self, BillRecord.self, Subcategory.self, Subscription.self, Budget.self], inMemory: true)
}
