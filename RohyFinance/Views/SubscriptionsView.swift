//
//  SubscriptionsView.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI
import SwiftData
import UIKit

struct SubscriptionsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var subscriptions: [Subscription]
    @State private var showAdd = false
    @State private var editing: Subscription?

    var body: some View {
        NavigationStack {
            List {
                ForEach(subscriptions) { subscription in
                    SubscriptionRow(subscription: subscription)
                        .swipeActions {
                            Button(role: .destructive) {
                                modelContext.delete(subscription)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                editing = subscription
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                }
            }
            .navigationTitle("Subscriptions")
            .overlay {
                if subscriptions.isEmpty {
                    ContentUnavailableView("No Subscriptions", systemImage: "repeat", description: Text("Your subscriptions will appear here"))
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                SubscriptionFormView()
                    .presentationDetents([.large])
            }
            .sheet(item: $editing) { subscription in
                SubscriptionFormView(subscription: subscription)
                    .presentationDetents([.large])
            }
            .onAppear {
                SubscriptionBilling.generateDueBills(context: modelContext)
            }
        }
    }
}

struct SubscriptionRow: View {
    @Environment(\.modelContext) private var modelContext
    let subscription: Subscription

    var body: some View {
        HStack(spacing: 12) {
            SubscriptionIcon(subscription: subscription, size: 40)
            VStack(alignment: .leading, spacing: 4) {
                Text(subscription.name)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text("\(subscription.period.localizedName) · \(moneyText(subscription.amount, currency: subscription.currency))")
                    if let wallet = subscription.wallet {
                        Text("·")
                        WalletIconView(wallet: wallet, size: 12)
                        Text(wallet.displayName)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: enabledBinding)
                .labelsHidden()
        }
        .padding(.vertical, 2)
    }

    private var enabledBinding: Binding<Bool> {
        Binding(
            get: { subscription.isEnabled },
            set: { newValue in
                subscription.isEnabled = newValue
                if newValue {
                    SubscriptionBilling.generateDueBills(context: modelContext)
                }
            }
        )
    }
}

/// Icon for a subscription: custom image, preset asset, or placeholder.
struct SubscriptionIcon: View {
    let subscription: Subscription
    var size: CGFloat = 40

    var body: some View {
        if let imageData = subscription.imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        } else if let presetIcon = subscription.presetIcon {
            Image(presetIcon)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(.quaternary)
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
        }
    }
}

/// Preset icons bundled with the app, sorted by asset id.
private let presetIcons: [(asset: String, name: String)] = [
    ("aliyun_drive", String(localized: "Aliyun Drive")),
    ("apple_music", "Apple Music"),
    ("baidu_netdisk", String(localized: "Baidu Netdisk")),
    ("bandizip_365", "Bandizip 365"),
    ("bilibili", String(localized: "Bilibili")),
    ("icloud", "iCloud"),
    ("kugou_music", String(localized: "Kugou Music")),
    ("netease_cloud_music", String(localized: "NetEase Cloud Music")),
    ("qqmusic", String(localized: "QQ Music")),
    ("quark_cloud_disk", String(localized: "Quark Cloud Disk")),
    ("soda_music", String(localized: "Soda Music")),
    ("spotify", "Spotify"),
]

/// Form for adding or editing a subscription.
struct SubscriptionFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var wallets: [Wallet]
    @AppStorage("defaultCurrency") private var defaultCurrencyRaw = Currency.defaultForLocale().rawValue

    let subscription: Subscription?

    @State private var name = ""
    @State private var imageData: Data?
    @State private var presetIcon: String?
    @State private var showImagePicker = false
    @State private var pickedImage: UIImage?

    @State private var currency: Currency?
    @State private var intPart = ""
    @State private var fracPart = ""
    @State private var conversionMode: ConversionMode = .rate
    @State private var rateText = ""
    @State private var convAmountInt = ""
    @State private var convAmountFrac = ""
    @State private var wallet: Wallet?

    @State private var startDate = Date.now
    @State private var period: SubscriptionPeriod = .monthly
    @State private var advanceDays = 0

    @State private var errorMessage: String?

    init(subscription: Subscription? = nil) {
        self.subscription = subscription
        if let subscription {
            _name = State(initialValue: subscription.name)
            _imageData = State(initialValue: subscription.imageData)
            _presetIcon = State(initialValue: subscription.presetIcon)
            _currency = State(initialValue: subscription.currency)
            let cents = Int((subscription.amount * 100).rounded())
            if cents != 0 {
                _intPart = State(initialValue: String(cents / 100))
                _fracPart = State(initialValue: String(format: "%02d", cents % 100))
            }
            _wallet = State(initialValue: subscription.wallet)
            _startDate = State(initialValue: subscription.startDate)
            _period = State(initialValue: subscription.period)
            _advanceDays = State(initialValue: subscription.advanceDays)
        }
    }

    private var defaultCurrency: Currency {
        Currency(rawValue: defaultCurrencyRaw) ?? .usd
    }

    private var needsConversion: Bool {
        guard let currency else { return false }
        return currency != defaultCurrency
    }

    private var availableWallets: [Wallet] {
        guard let currency else { return [] }
        return wallets.filter { $0.supports(currency) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Info") {
                    HStack(spacing: 12) {
                        imagePickerBox
                        TextField("Name", text: $name)
                    }
                }

                Section("Payment") {
                    Picker(selection: $currency) {
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

                    if needsConversion {
                        conversionRow
                        switch conversionMode {
                        case .rate:
                            rateRow
                        case .value:
                            HStack {
                                Text("\(defaultCurrency.symbol) \(String(localized: "Amount"))")
                                AmountField(intPart: $convAmountInt, fracPart: $convAmountFrac)
                            }
                        }
                    }

                    Picker(selection: $wallet) {
                        Text("Select").tag(Wallet?.none)
                        ForEach(availableWallets) { wallet in
                            walletMenuLabel(wallet)
                                .tag(Wallet?.some(wallet))
                        }
                    } label: {
                        Text("Wallet")
                    }
                    .pickerStyle(.menu)
                    .disabled(currency == nil)
                }

                Section("Cycle") {
                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)

                    Picker(selection: $period) {
                        ForEach(SubscriptionPeriod.allCases) { period in
                            Text(period.localizedName).tag(period)
                        }
                    } label: {
                        Text("Subscription Period")
                    }
                    .pickerStyle(.menu)

                    Picker(selection: $advanceDays) {
                        ForEach(0...5, id: \.self) { days in
                            Text(days == 0 ? String(localized: "Same day") : "\(days) \(String(localized: "days"))")
                                .tag(days)
                        }
                    } label: {
                        Text("Renewal Date")
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle(subscription == nil ? "Add Subscription" : "Edit Subscription")
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
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(image: $pickedImage)
                    .ignoresSafeArea()
            }
            .alert("Notice", isPresented: errorPresented) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onChange(of: name) { _, value in
                if characterCount(of: value) > 10 {
                    name = truncatedToCharacterCount(value, limit: 10)
                }
            }
            .onChange(of: currency) { _, _ in
                wallet = nil
            }
            .onChange(of: pickedImage) { _, image in
                guard let image else { return }
                imageData = Self.squareImageData(image)
                presetIcon = nil
                pickedImage = nil
            }
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private var imagePickerBox: some View {
        Menu {
            Button {
                showImagePicker = true
            } label: {
                Label("Library", systemImage: "photo")
            }
            Menu {
                ForEach(presetIcons, id: \.asset) { preset in
                    Button {
                        presetIcon = preset.asset
                        imageData = nil
                    } label: {
                        Label {
                            Text(preset.name)
                        } icon: {
                            roundedAssetImage(preset.asset)
                                .frame(width: 20, height: 20)
                        }
                    }
                }
            } label: {
                Label("Preset", systemImage: "square.grid.2x2")
            }
        } label: {
            previewBox
        }
    }

    @ViewBuilder
    private var previewBox: some View {
        let size: CGFloat = 56
        if let imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else if let presetIcon {
            Image(presetIcon)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
        }
    }

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

    private var rateRow: some View {
        HStack(spacing: 12) {
            HStack {
                Text(currency?.symbol ?? "")
                TextField("1.00", text: .constant(""))
                    .keyboardType(.decimalPad)
                    .disabled(true)
            }
            .frame(maxWidth: .infinity)
            HStack {
                Text(defaultCurrency.symbol)
                TextField("0.00", text: $rateText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
            }
            .frame(maxWidth: .infinity)
        }
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

    private static func squareImageData(_ image: UIImage) -> Data? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256))
        return renderer.pngData { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: 256, height: 256))
        }
    }

    private func amountValue(_ intPart: String, _ fracPart: String) -> Double {
        (Double(intPart) ?? 0) + (Double(fracPart) ?? 0) / 100
    }

    private func confirm() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return fail(String(localized: "Please enter a name"))
        }
        guard let currency else {
            return fail(String(localized: "Please select a currency"))
        }
        let amount = amountValue(intPart, fracPart)
        guard amount > 0 else {
            return fail(String(localized: "Please enter an amount"))
        }
        guard let wallet else {
            return fail(String(localized: "Please select a wallet"))
        }

        var convertedAmount: Double?
        if currency != defaultCurrency {
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

        if let subscription {
            subscription.name = trimmed
            subscription.imageData = imageData
            subscription.presetIcon = presetIcon
            subscription.amount = amount
            subscription.currencyRaw = currency.rawValue
            subscription.convertedAmount = convertedAmount
            subscription.wallet = wallet
            subscription.startDate = startDate
            subscription.periodDays = period.rawValue
            subscription.advanceDays = advanceDays
        } else {
            let subscription = Subscription(
                name: trimmed,
                imageData: imageData,
                presetIcon: presetIcon,
                amount: amount,
                currency: currency,
                convertedAmount: convertedAmount,
                wallet: wallet,
                startDate: startDate,
                periodDays: period.rawValue,
                advanceDays: advanceDays,
                isEnabled: true
            )
            modelContext.insert(subscription)
            SubscriptionBilling.generateDueBills(context: modelContext)
        }
        dismiss()
    }

    private func fail(_ message: String) {
        errorMessage = message
    }
}

#Preview {
    SubscriptionsView()
        .modelContainer(for: [Wallet.self, BillRecord.self, Subcategory.self, Subscription.self], inMemory: true)
}
