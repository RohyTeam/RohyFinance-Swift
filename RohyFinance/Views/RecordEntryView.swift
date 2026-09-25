//
//  RecordEntryView.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI
import SwiftData

/// The "记账" sheet: expense / income / transfer entry.
struct RecordEntryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var wallets: [Wallet]
    @Query private var subcategories: [Subcategory]
    @Query private var budgets: [Budget]
    @AppStorage("defaultCurrency") private var defaultCurrencyRaw = Currency.defaultForLocale().rawValue

    @State private var kind: RecordKind = .expense
    @State private var category: CategoryDef?
    @State private var subcategory: Subcategory?
    @State private var note = ""
    @State private var currency: Currency?
    @State private var budget: Budget?
    @State private var intPart = ""
    @State private var fracPart = ""
    @State private var wallet: Wallet?
    @State private var targetWallet: Wallet?
    @State private var date = Date.now
    // Conversion (when currency != default currency).
    @State private var conversionMode: ConversionMode = .rate
    @State private var rateText = ""
    @State private var convAmountInt = ""
    @State private var convAmountFrac = ""
    @State private var convTaxInt = ""
    @State private var convTaxFrac = ""
    @State private var convDiscountInt = ""
    @State private var convDiscountFrac = ""
    @State private var convConsumptionTaxInt = ""
    @State private var convConsumptionTaxFrac = ""
    // Income: pre-tax toggle + tax amount
    @State private var isPretax = false
    @State private var taxInt = ""
    @State private var taxFrac = ""
    // Expense: discount toggle + discount amount
    @State private var hasDiscount = false
    @State private var discountInt = ""
    @State private var discountFrac = ""
    // Expense: consumption tax toggle + tax amount
    @State private var excludesConsumptionTax = false
    @State private var consumptionTaxInt = ""
    @State private var consumptionTaxFrac = ""
    // Transfer: fee toggle + fee amount
    @State private var needsFee = false
    @State private var feeInt = ""
    @State private var feeFrac = ""

    // Transfer: per-wallet currency selection
    @State private var sourceCurrency: Currency?
    @State private var targetCurrency: Currency?

    @State private var errorMessage: String?

    /// Non-nil when editing an existing record.
    let record: BillRecord?

    init(record: BillRecord? = nil) {
        self.record = record
        guard let record else { return }
        _kind = State(initialValue: record.kind)
        _category = State(initialValue: CategoryStore.find(record.categoryKey))
        _note = State(initialValue: record.note)
        _currency = State(initialValue: record.currency)
        _budget = State(initialValue: record.budget)
        (_intPart, _fracPart) = Self.amountStates(record.amount)
        _wallet = State(initialValue: record.wallet)
        _targetWallet = State(initialValue: record.targetWallet)
        _date = State(initialValue: record.date)
        if let tax = record.taxAmount {
            _isPretax = State(initialValue: true)
            (_taxInt, _taxFrac) = Self.amountStates(tax)
        }
        if let discount = record.discountAmount {
            _hasDiscount = State(initialValue: true)
            (_discountInt, _discountFrac) = Self.amountStates(discount)
        }
        if let consumptionTax = record.consumptionTaxAmount {
            _excludesConsumptionTax = State(initialValue: true)
            (_consumptionTaxInt, _consumptionTaxFrac) = Self.amountStates(consumptionTax)
        }
        if let fee = record.feeAmount {
            _needsFee = State(initialValue: true)
            (_feeInt, _feeFrac) = Self.amountStates(fee)
        }
        if let convertedAmount = record.convertedAmount {
            _conversionMode = State(initialValue: .value)
            (_convAmountInt, _convAmountFrac) = Self.amountStates(convertedAmount)
            if let convertedTax = record.convertedTaxAmount {
                (_convTaxInt, _convTaxFrac) = Self.amountStates(convertedTax)
            }
            if let convertedDiscount = record.convertedDiscountAmount {
                (_convDiscountInt, _convDiscountFrac) = Self.amountStates(convertedDiscount)
            }
            if let convertedConsumptionTax = record.convertedConsumptionTaxAmount {
                (_convConsumptionTaxInt, _convConsumptionTaxFrac) = Self.amountStates(convertedConsumptionTax)
            }
        }
        if record.kind == .transfer {
            _sourceCurrency = State(initialValue: record.currency)
            _targetCurrency = State(initialValue: record.targetCurrencyRaw.flatMap(Currency.init(rawValue:)))
        }
    }

    private static func amountStates(_ amount: Double) -> (State<String>, State<String>) {
        let cents = Int((amount * 100).rounded())
        return (State(initialValue: String(cents / 100)), State(initialValue: String(format: "%02d", cents % 100)))
    }

    private var defaultCurrency: Currency {
        Currency(rawValue: defaultCurrencyRaw) ?? .usd
    }

    private var needsConversion: Bool {
        guard let currency else { return false }
        return currency != defaultCurrency
    }

    private var categories: [CategoryDef] {
        kind == .income ? CategoryStore.incomes : CategoryStore.expenses
    }

    private var availableSubcategories: [Subcategory] {
        guard let category else { return [] }
        return subcategories.filter { $0.categoryKey == category.key }
    }

    /// All wallets can be picked; the currency choice is filtered afterwards.
    private var availableWallets: [Wallet] {
        wallets
    }

    private var resolvedSourceCurrency: Currency? {
        guard let wallet else { return nil }
        if wallet.holdings.count > 1 { return sourceCurrency }
        return wallet.holdings.first?.currency
    }

    private var resolvedTargetCurrency: Currency? {
        guard let targetWallet else { return nil }
        if targetWallet.holdings.count > 1 { return targetCurrency }
        return targetWallet.holdings.first?.currency
    }

    /// Cross-currency transfer needs a conversion method.
    private var transferNeedsConversion: Bool {
        guard let source = resolvedSourceCurrency, let target = resolvedTargetCurrency else { return false }
        return source != target
    }

    var body: some View {
        NavigationStack {
            Form {
                if kind == .transfer {
                    Section {
                        HStack {
                            Text("Note")
                            TextField("Enter bill note", text: $note)
                        }
                    }

                    Section("Time") {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                        DatePicker("Time", selection: $date, displayedComponents: .hourAndMinute)
                    }

                    Section("Source") {
                        walletPicker("Wallet", selection: $wallet)
                        if let wallet, wallet.holdings.count > 1 {
                            holdingCurrencyPicker(currencies: wallet.holdings.map(\.currency), selection: $sourceCurrency)
                        }
                        amountRow(Text("Amount"), intPart: $intPart, fracPart: $fracPart)
                    }

                    Section("Target") {
                        walletPicker("Wallet", selection: $targetWallet)
                        if let targetWallet, targetWallet.holdings.count > 1 {
                            holdingCurrencyPicker(currencies: targetWallet.holdings.map(\.currency), selection: $targetCurrency)
                        }
                        if transferNeedsConversion {
                            conversionRow
                            switch conversionMode {
                            case .rate:
                                rateRow(fromSymbol: resolvedSourceCurrency?.symbol ?? "", toSymbol: resolvedTargetCurrency?.symbol ?? "")
                            case .value:
                                amountRow(convertedTitle(resolvedTargetCurrency?.symbol ?? "", String(localized: "Amount")), intPart: $convAmountInt, fracPart: $convAmountFrac)
                            }
                        }
                    }
                } else {
                    Section("Category") {
                        CategoryGrid(categories: categories, selection: $category)
                        subcategoryPicker
                    }

                    Section {
                        HStack {
                            Text("Note")
                            TextField("Enter bill note", text: $note)
                        }
                    }

                    Section("Time") {
                        DatePicker("Date", selection: $date, displayedComponents: .date)
                        DatePicker("Time", selection: $date, displayedComponents: .hourAndMinute)
                    }

                    Section("Bills") {
                        walletPicker("Wallet", selection: $wallet)

                        holdingCurrencyPicker(currencies: wallet?.holdings.map(\.currency) ?? [], selection: $currency)
                            .disabled(wallet == nil || (wallet?.holdings.count ?? 0) <= 1)

                        budgetPicker

                        amountRow(Text("Amount"), intPart: $intPart, fracPart: $fracPart)

                        if needsConversion {
                            conversionRow
                            switch conversionMode {
                            case .rate:
                                rateRow(fromSymbol: currency?.symbol ?? "", toSymbol: defaultCurrency.symbol)
                            case .value:
                                amountRow(convertedTitle(defaultCurrency.symbol, String(localized: "Amount")), intPart: $convAmountInt, fracPart: $convAmountFrac)
                            }
                        }
                    }
                }

                switch kind {
                case .income:
                    Section("Tax") {
                        Toggle("Pre-tax", isOn: $isPretax)
                        if isPretax {
                            amountRow(Text("Tax amount"), intPart: $taxInt, fracPart: $taxFrac)
                            if needsConversion && conversionMode == .value {
                                amountRow(convertedTitle(defaultCurrency.symbol, String(localized: "Tax amount")), intPart: $convTaxInt, fracPart: $convTaxFrac)
                            }
                        }
                    }
                case .expense:
                    Section("Discount") {
                        Toggle("Includes discount", isOn: $hasDiscount)
                        if hasDiscount {
                            amountRow(Text("Discount amount"), intPart: $discountInt, fracPart: $discountFrac)
                            if needsConversion && conversionMode == .value {
                                amountRow(convertedTitle(defaultCurrency.symbol, String(localized: "Discount amount")), intPart: $convDiscountInt, fracPart: $convDiscountFrac)
                            }
                        }
                    }
                    Section("Consumption Tax") {
                        Toggle("Excludes consumption tax", isOn: $excludesConsumptionTax)
                        if excludesConsumptionTax {
                            amountRow(Text("Tax amount"), intPart: $consumptionTaxInt, fracPart: $consumptionTaxFrac)
                            if needsConversion && conversionMode == .value {
                                amountRow(convertedTitle(defaultCurrency.symbol, String(localized: "Tax amount")), intPart: $convConsumptionTaxInt, fracPart: $convConsumptionTaxFrac)
                            }
                        }
                    }
                case .transfer:
                    Section("Fee") {
                        Toggle("Requires fee", isOn: $needsFee)
                        if needsFee {
                            amountRow(Text("Fee amount"), intPart: $feeInt, fracPart: $feeFrac)
                        }
                    }
                }
            }
            .navigationTitle(record == nil ? String(localized: "Record") : String(localized: "Edit Record"))
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
            .safeAreaBar(edge: .top) {
                Picker("Kind", selection: $kind) {
                    ForEach(RecordKind.allCases) { kind in
                        Text(kind.localizedName).tag(kind)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
            }
            .alert("Notice", isPresented: errorPresented) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onChange(of: kind) { _, _ in
                category = nil
                subcategory = nil
                currency = nil
                wallet = nil
                targetWallet = nil
                sourceCurrency = nil
                targetCurrency = nil
                budget = nil
                applyDefaultWallet()
            }
            .onChange(of: category) { _, _ in
                subcategory = nil
            }
            .onChange(of: wallet) { _, newValue in
                if kind == .transfer {
                    sourceCurrency = resolveCurrency(for: newValue, current: sourceCurrency)
                } else {
                    currency = resolveCurrency(for: newValue, current: currency)
                }
                budget = nil
            }
            .onChange(of: currency) { _, _ in
                budget = nil
            }
            .onChange(of: targetWallet) { _, newValue in
                targetCurrency = resolveCurrency(for: newValue, current: targetCurrency)
            }
            .onChange(of: note) { _, value in
                if characterCount(of: value) > 16 {
                    note = truncatedToCharacterCount(value, limit: 16)
                }
            }
            .onAppear {
                applyDefaultWallet()
                if subcategory == nil, let existingSubcategory = record?.subcategory {
                    subcategory = subcategories.first {
                        $0.name == existingSubcategory && $0.categoryKey == record?.categoryKey
                    }
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

    private var subcategoryPicker: some View {
        Picker(selection: $subcategory) {
            Text("None").tag(Subcategory?.none)
            ForEach(availableSubcategories) { subcategory in
                Text(subcategory.name)
                    .tag(Subcategory?.some(subcategory))
            }
        } label: {
            Text("Subcategory")
        }
        .pickerStyle(.menu)
        .disabled(category == nil)
    }

    /// Preselects the default wallet (and its default currency) when creating
    /// a new expense/income record.
    private func applyDefaultWallet() {
        guard record == nil, kind != .transfer, wallet == nil,
              let defaultWallet = wallets.first(where: { $0.isDefault }) else { return }
        wallet = defaultWallet
        currency = defaultWallet.defaultCurrency
    }

    /// Keeps the current currency if the wallet supports it,
    /// otherwise falls back to the wallet's default currency.
    private func resolveCurrency(for wallet: Wallet?, current: Currency?) -> Currency? {
        guard let wallet else { return nil }
        if let current, wallet.supports(current) { return current }
        return wallet.defaultCurrency
    }

    /// Budgets matching the selected wallet and currency.
    private var availableBudgets: [Budget] {
        guard let wallet, let currency else { return [] }
        return budgets.filter { $0.wallet === wallet && $0.currencyRaw == currency.rawValue }
    }

    /// Optional budget picker: budgets of the selected wallet + currency.
    private var budgetPicker: some View {
        Picker(selection: $budget) {
            Text("None").tag(Budget?.none)
            ForEach(availableBudgets) { budget in
                Label {
                    Text(budget.name)
                } icon: {
                    Image(systemName: budget.icon)
                }
                .tag(Budget?.some(budget))
            }
        } label: {
            Text("Budget")
        }
        .pickerStyle(.menu)
        .disabled(wallet == nil || currency == nil)
    }

    /// Segmented "汇率 / 值" picker for the conversion method.
    private var conversionRow: some View {
        HStack {
            Text("Conversion")
            Spacer()
            Picker("Conversion", selection: $conversionMode) {
                ForEach(ConversionMode.allCases) { mode in
                    Text(mode.localizedName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 160)
        }
    }

    /// Rate mode: "1.00 [from] = X [to]".
    private func rateRow(fromSymbol: String, toSymbol: String) -> some View {
        HStack(spacing: 12) {
            HStack {
                Text(fromSymbol)
                TextField("1.00", text: .constant(""))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .disabled(true)
            }
            .frame(maxWidth: .infinity)
            Text(":")
            HStack {
                Text(toSymbol)
                TextField("0.00", text: $rateText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Label like "$ 金额" for converted-amount inputs.
    private func convertedTitle(_ symbol: String, _ localizedName: String) -> Text {
        Text("\(symbol) \(localizedName)")
    }

    /// Currency picker limited to a wallet's holdings (multi-currency transfer rows).
    private func holdingCurrencyPicker(currencies: [Currency], selection: Binding<Currency?>) -> some View {
        Picker(selection: selection) {
            Text("Select").tag(Currency?.none)
            ForEach(currencies) { currency in
                Text("\(currency.symbol) \(currency.localizedName)")
                    .tag(Currency?.some(currency))
            }
        } label: {
            Text("Currency")
        }
        .pickerStyle(.menu)
    }

    private func amountRow(_ title: Text, intPart: Binding<String>, fracPart: Binding<String>) -> some View {
        HStack {
            title
            AmountField(intPart: intPart, fracPart: fracPart)
        }
    }

    private func walletPicker(_ title: LocalizedStringKey, selection: Binding<Wallet?>) -> some View {
        Picker(selection: selection) {
            Text("Select").tag(Wallet?.none)
            ForEach(availableWallets) { wallet in
                walletMenuLabel(wallet)
                    .tag(Wallet?.some(wallet))
            }
        } label: {
            Text(title)
        }
        .pickerStyle(.menu)
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

    private func amountValue(_ intPart: String, _ fracPart: String) -> Double {
        (Double(intPart) ?? 0) + (Double(fracPart) ?? 0) / 100
    }

    private func confirm() {
        let trimmedNote = note.trimmingCharacters(in: .whitespaces)
        let amount = amountValue(intPart, fracPart)

        switch kind {
        case .expense, .income:
            guard let category else {
                return fail(String(localized: "Please select a category"))
            }
            guard let wallet else {
                return fail(String(localized: "Please select a wallet"))
            }
            guard let currency else {
                return fail(String(localized: "Please select a currency"))
            }
            guard !trimmedNote.isEmpty else {
                return fail(String(localized: "Please enter a note"))
            }
            guard amount > 0 else {
                return fail(String(localized: "Please enter an amount"))
            }

            var tax: Double?
            var discount: Double?
            var consumptionTax: Double?

            if kind == .income, isPretax {
                let value = amountValue(taxInt, taxFrac)
                guard value <= amount else {
                    return fail(String(localized: "Tax amount cannot exceed the amount"))
                }
                tax = value > 0 ? value : nil
            }
            if kind == .expense {
                if hasDiscount {
                    let value = amountValue(discountInt, discountFrac)
                    guard value <= amount else {
                        return fail(String(localized: "Discount amount cannot exceed the amount"))
                    }
                    discount = value > 0 ? value : nil
                }
                if excludesConsumptionTax {
                    let value = amountValue(consumptionTaxInt, consumptionTaxFrac)
                    consumptionTax = value > 0 ? value : nil
                }
            }

            var convertedAmount: Double?
            var convertedTax: Double?
            var convertedDiscount: Double?
            var convertedConsumptionTax: Double?

            if currency != defaultCurrency {
                switch conversionMode {
                case .rate:
                    guard let rate = Double(rateText), rate > 0 else {
                        return fail(String(localized: "Please enter the exchange rate"))
                    }
                    convertedAmount = amount * rate
                    if let tax { convertedTax = tax * rate }
                    if let discount { convertedDiscount = discount * rate }
                    if let consumptionTax { convertedConsumptionTax = consumptionTax * rate }
                case .value:
                    let converted = amountValue(convAmountInt, convAmountFrac)
                    guard converted > 0 else {
                        return fail(String(localized: "Please enter the converted amount"))
                    }
                    convertedAmount = converted
                    if tax != nil {
                        let value = amountValue(convTaxInt, convTaxFrac)
                        guard value > 0 else {
                            return fail(String(localized: "Please enter the converted amount"))
                        }
                        convertedTax = value
                    }
                    if discount != nil {
                        let value = amountValue(convDiscountInt, convDiscountFrac)
                        guard value > 0 else {
                            return fail(String(localized: "Please enter the converted amount"))
                        }
                        convertedDiscount = value
                    }
                    if consumptionTax != nil {
                        let value = amountValue(convConsumptionTaxInt, convConsumptionTaxFrac)
                        guard value > 0 else {
                            return fail(String(localized: "Please enter the converted amount"))
                        }
                        convertedConsumptionTax = value
                    }
                }
            }

            let draft = RecordDraft(
                kind: kind,
                amount: amount,
                currency: currency,
                categoryKey: category.key,
                subcategory: subcategory?.name,
                note: trimmedNote,
                date: date,
                wallet: wallet,
                budget: budget,
                taxAmount: tax,
                discountAmount: discount,
                consumptionTaxAmount: consumptionTax,
                convertedAmount: convertedAmount,
                convertedTaxAmount: convertedTax,
                convertedDiscountAmount: convertedDiscount,
                convertedConsumptionTaxAmount: convertedConsumptionTax
            )
            save(draft)
        case .transfer:
            guard let wallet else {
                return fail(String(localized: "Please select a source wallet"))
            }
            guard let targetWallet else {
                return fail(String(localized: "Please select a target wallet"))
            }
            guard !trimmedNote.isEmpty else {
                return fail(String(localized: "Please enter a note"))
            }
            guard amount > 0 else {
                return fail(String(localized: "Please enter an amount"))
            }
            guard let sourceCurrency = resolvedSourceCurrency else {
                return fail(String(localized: "Please select a currency"))
            }
            guard let targetCurrency = resolvedTargetCurrency else {
                return fail(String(localized: "Please select a currency"))
            }
            if wallet === targetWallet && sourceCurrency == targetCurrency {
                return fail(String(localized: "Same wallet transfer requires different currencies"))
            }

            var convertedAmount: Double?
            if sourceCurrency != targetCurrency {
                switch conversionMode {
                case .rate:
                    guard let rate = Double(rateText), rate > 0 else {
                        return fail(String(localized: "Please enter the exchange rate"))
                    }
                    convertedAmount = amount * rate
                case .value:
                    let converted = amountValue(convAmountInt, convAmountFrac)
                    guard converted > 0 else {
                        return fail(String(localized: "Please enter the converted amount"))
                    }
                    convertedAmount = converted
                }
            }

            var fee: Double?
            if needsFee {
                let value = amountValue(feeInt, feeFrac)
                fee = value > 0 ? value : nil
            }

            let draft = RecordDraft(
                kind: .transfer,
                amount: amount,
                currency: sourceCurrency,
                categoryKey: "",
                note: trimmedNote,
                date: date,
                wallet: wallet,
                targetWallet: targetWallet,
                targetCurrencyRaw: targetCurrency.rawValue,
                feeAmount: fee,
                convertedAmount: convertedAmount
            )
            save(draft)
        }
    }

    /// Saves a draft: reverts the old balance effect when editing,
    /// applies the new effect, then dismisses.
    private func save(_ draft: RecordDraft) {
        if let editing = record {
            editing.revertBalanceEffect()
            editing.update(from: draft)
            draft.applyBalanceEffect()
        } else {
            let newRecord = draft.makeRecord()
            draft.applyBalanceEffect()
            modelContext.insert(newRecord)
        }
        dismiss()
    }

    private func fail(_ message: String) {
        errorMessage = message
    }
}

#Preview {
    RecordEntryView()
        .modelContainer(for: [Wallet.self, BillRecord.self, Subcategory.self, Subscription.self, Budget.self], inMemory: true)
}
