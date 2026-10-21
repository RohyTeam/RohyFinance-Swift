//
//  ItemFormView.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI
import SwiftData
import UIKit

/// Form for adding or editing an item (物品).
struct ItemFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Non-nil when editing an existing item.
    let item: Item?

    @State private var name = ""
    @State private var imageData: Data?
    @State private var showImagePicker = false
    @State private var pickedImage: UIImage?
    @State private var record: BillRecord?
    @State private var showRecordPicker = false
    @State private var currency: Currency?
    @State private var intPart = ""
    @State private var fracPart = ""
    @State private var purchaseDate = Date.now
    @State private var retirementDate: Date?
    @State private var warrantyEndDate: Date?
    @State private var status: ItemStatus = .inUse
    @State private var errorMessage: String?

    init(item: Item? = nil) {
        self.item = item
        if let item {
            _name = State(initialValue: item.name)
            _imageData = State(initialValue: item.imageData)
            _record = State(initialValue: item.record)
            _currency = State(initialValue: item.currency)
            _purchaseDate = State(initialValue: item.purchaseDate)
            _retirementDate = State(initialValue: item.retirementDate)
            _warrantyEndDate = State(initialValue: item.warrantyEndDate)
            _status = State(initialValue: item.status)
            if item.record == nil {
                let cents = Int((item.value * 100).rounded())
                if cents != 0 {
                    _intPart = State(initialValue: String(cents / 100))
                    _fracPart = State(initialValue: String(format: "%02d", cents % 100))
                }
            }
        }
    }

    /// Value fields are locked to the bound record.
    private var bound: Bool { record != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        imagePickerBox
                        TextField("Name", text: $name)
                    }
                }

                Section {
                    Button("Bind Record") {
                        showRecordPicker = true
                    }
                }

                if let record {
                    Section("Bound Record") {
                        RecordRow(record: record)
                    }
                }

                Section("Value") {
                    if bound, let boundCurrency = record?.currency {
                        Picker(selection: .constant(boundCurrency)) {
                            Text("\(boundCurrency.symbol) \(boundCurrency.localizedName)")
                                .tag(boundCurrency)
                        } label: {
                            Text("Currency")
                        }
                        .pickerStyle(.menu)
                        .disabled(true)
                    } else {
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
                    }

                    HStack {
                        Text("Amount")
                        if bound, let record {
                            Text(moneyText(record.effectiveAmount, currency: record.currency))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        } else {
                            AmountField(intPart: $intPart, fracPart: $fracPart)
                        }
                    }
                    .disabled(bound)
                }

                Section("Date") {
                    if bound, let record {
                        HStack {
                            Text("Purchase Date")
                            Spacer()
                            Text(record.date, format: .dateTime.year().month().day())
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        DatePicker("Purchase Date", selection: $purchaseDate, displayedComponents: .date)
                    }

                    OptionalDateRow(title: "Retirement Date", date: $retirementDate)
                    OptionalDateRow(title: "Warranty End", date: $warrantyEndDate)
                }

                Section("Status") {
                    Picker(selection: $status) {
                        ForEach(ItemStatus.allCases) { status in
                            Text(status.localizedName).tag(status)
                        }
                    } label: {
                        Text("Usage Status")
                    }
                    .pickerStyle(.menu)
                }
            }
            .navigationTitle(item == nil ? String(localized: "Add Item") : String(localized: "Edit Item"))
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
            .sheet(isPresented: $showRecordPicker) {
                RecordPickerView { picked in
                    record = picked
                    currency = picked.currency
                    purchaseDate = picked.date
                }
                .presentationDetents([.large])
            }
            .alert("Notice", isPresented: errorPresented) {
                Button("OK") {}
            } message: {
                Text(errorMessage ?? "")
            }
            .onChange(of: name) { _, value in
                if characterCount(of: value) > 16 {
                    name = truncatedToCharacterCount(value, limit: 16)
                }
            }
            .onChange(of: pickedImage) { _, image in
                guard let image else { return }
                imageData = Self.squareImageData(image)
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
        Button {
            showImagePicker = true
        } label: {
            previewBox
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var previewBox: some View {
        let size: CGFloat = 96
        if let imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4]))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private static func squareImageData(_ image: UIImage) -> Data? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 256, height: 256))
        return renderer.pngData { _ in
            image.draw(in: CGRect(x: 0, y: 0, width: 256, height: 256))
        }
    }

    private func confirm() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            return fail(String(localized: "Please enter a name"))
        }

        let finalCurrency: Currency
        let finalValue: Double
        let finalPurchaseDate: Date
        if let record {
            finalCurrency = record.currency
            finalValue = record.effectiveAmount
            finalPurchaseDate = record.date
        } else {
            guard let currency else {
                return fail(String(localized: "Please select a currency"))
            }
            let amount = (Double(intPart) ?? 0) + (Double(fracPart) ?? 0) / 100
            guard amount > 0 else {
                return fail(String(localized: "Please enter an amount"))
            }
            finalCurrency = currency
            finalValue = amount
            finalPurchaseDate = purchaseDate
        }

        if let item {
            item.name = trimmed
            item.imageData = imageData
            item.record = record
            item.currencyRaw = finalCurrency.rawValue
            item.value = finalValue
            item.purchaseDate = finalPurchaseDate
            item.retirementDate = retirementDate
            item.warrantyEndDate = warrantyEndDate
            item.statusRaw = status.rawValue
        } else {
            modelContext.insert(Item(
                name: trimmed,
                imageData: imageData,
                record: record,
                currency: finalCurrency,
                value: finalValue,
                purchaseDate: finalPurchaseDate,
                retirementDate: retirementDate,
                warrantyEndDate: warrantyEndDate,
                status: status
            ))
        }
        dismiss()
    }

    private func fail(_ message: String) {
        errorMessage = message
    }
}

/// A date row that can be "未选择" (nil) with a clear button.
struct OptionalDateRow: View {
    let title: LocalizedStringKey
    @Binding var date: Date?

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            if let date {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { date },
                        set: { self.date = $0 }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
                Button {
                    self.date = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Button("Not selected") {
                    date = .now
                }
                .foregroundStyle(.secondary)
            }
        }
    }
}

/// Half-modal record picker with search and kind filter.
struct RecordPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \BillRecord.date, order: .reverse) private var records: [BillRecord]
    @State private var searchText = ""
    @State private var kindFilter: RecordKind?

    let onSelect: (BillRecord) -> Void

    private var filtered: [BillRecord] {
        records.filter { record in
            if let kindFilter, record.kind != kindFilter { return false }
            if !searchText.isEmpty, !record.note.localizedStandardContains(searchText) { return false }
            return true
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filtered) { record in
                    Button {
                        onSelect(record)
                        dismiss()
                    } label: {
                        RecordRow(record: record)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Bind Record")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: Text("Search"))
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            kindFilter = nil
                        } label: {
                            Label("All", systemImage: kindFilter == nil ? "checkmark" : "")
                        }
                        ForEach(RecordKind.allCases) { kind in
                            Button {
                                kindFilter = kind
                            } label: {
                                Label(kind.localizedName, systemImage: kindFilter == kind ? "checkmark" : "")
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
            }
        }
    }
}

#Preview {
    ItemFormView()
        .modelContainer(for: [Wallet.self, BillRecord.self, Subcategory.self, Subscription.self, Budget.self, SavingsGoal.self, SavingsPlan.self, Item.self], inMemory: true)
}
