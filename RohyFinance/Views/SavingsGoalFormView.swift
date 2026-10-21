//
//  SavingsGoalFormView.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI
import SwiftData
import UIKit

/// Form for adding or editing a savings goal (攒钱).
struct SavingsGoalFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    /// Non-nil when editing an existing goal.
    let goal: SavingsGoal?

    @State private var name = ""
    @State private var imageData: Data?
    @State private var showImagePicker = false
    @State private var pickedImage: UIImage?
    @State private var currency: Currency?
    @State private var intPart = ""
    @State private var fracPart = ""
    @State private var errorMessage: String?

    init(goal: SavingsGoal? = nil) {
        self.goal = goal
        if let goal {
            _name = State(initialValue: goal.name)
            _imageData = State(initialValue: goal.imageData)
            _currency = State(initialValue: goal.currency)
            let cents = Int((goal.amount * 100).rounded())
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
                    HStack(spacing: 16) {
                        imagePickerBox
                        TextField("Name", text: $name)
                    }
                }

                Section("Goal") {
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
                }
            }
            .navigationTitle(goal == nil ? String(localized: "Add Savings Goal") : String(localized: "Edit Savings Goal"))
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
        guard let currency else {
            return fail(String(localized: "Please select a currency"))
        }
        let amount = (Double(intPart) ?? 0) + (Double(fracPart) ?? 0) / 100
        guard amount > 0 else {
            return fail(String(localized: "Please enter an amount"))
        }

        if let goal {
            goal.name = trimmed
            goal.imageData = imageData
            goal.currencyRaw = currency.rawValue
            goal.amount = amount
        } else {
            modelContext.insert(SavingsGoal(name: trimmed, imageData: imageData, currency: currency, amount: amount))
        }
        dismiss()
    }

    private func fail(_ message: String) {
        errorMessage = message
    }
}

#Preview {
    SavingsGoalFormView()
        .modelContainer(for: [Wallet.self, BillRecord.self, Subcategory.self, Subscription.self, Budget.self, SavingsGoal.self, SavingsPlan.self, Item.self], inMemory: true)
}
