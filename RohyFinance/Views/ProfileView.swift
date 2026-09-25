//
//  ProfileView.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI
import SwiftData

struct ProfileView: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage("defaultCurrency") private var defaultCurrencyRaw = Currency.defaultForLocale().rawValue

    @State private var pendingCurrency: Currency?
    /// 1...3 while the triple confirmation is in progress.
    @State private var confirmStep = 0

    private var defaultCurrency: Currency {
        Currency(rawValue: defaultCurrencyRaw) ?? .usd
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Account") {
                    Picker(selection: currencyBinding) {
                        ForEach(Currency.allCases) { currency in
                            Text("\(currency.symbol) \(currency.localizedName)")
                                .tag(currency)
                        }
                    } label: {
                        Text("Default Currency")
                    }
                    .pickerStyle(.menu)

                    NavigationLink("Subcategory") {
                        SubcategoryManagementView()
                    }
                }
            }
            .navigationTitle("Profile")
            .alert("\(String(localized: "Notice"))（1/3）", isPresented: stepBinding(1)) {
                Button("Continue") { confirmStep = 2 }
                Button("Cancel", role: .cancel) { resetPending() }
            } message: {
                Text("Switching the default currency will erase all records. Continue?")
            }
            .alert("\(String(localized: "Notice"))（2/3）", isPresented: stepBinding(2)) {
                Button("Continue") { confirmStep = 3 }
                Button("Cancel", role: .cancel) { resetPending() }
            } message: {
                Text("Switching the default currency will erase all records. Continue?")
            }
            .alert("\(String(localized: "Notice"))（3/3）", isPresented: stepBinding(3)) {
                Button("Continue") { applyPending() }
                Button("Cancel", role: .cancel) { resetPending() }
            } message: {
                Text("Switching the default currency will erase all records. Continue?")
            }
        }
    }

    private var currencyBinding: Binding<Currency> {
        Binding(
            get: { defaultCurrency },
            set: { newValue in
                guard newValue != defaultCurrency else { return }
                pendingCurrency = newValue
                confirmStep = 1
            }
        )
    }

    private func stepBinding(_ step: Int) -> Binding<Bool> {
        Binding(
            get: { confirmStep == step },
            set: { isPresented in
                if !isPresented && confirmStep == step {
                    resetPending()
                }
            }
        )
    }

    private func resetPending() {
        pendingCurrency = nil
        confirmStep = 0
    }

    private func applyPending() {
        guard let pendingCurrency else {
            resetPending()
            return
        }
        defaultCurrencyRaw = pendingCurrency.rawValue
        do {
            try modelContext.delete(model: BillRecord.self)
        } catch {
            // Lightweight best-effort wipe; records list will simply keep old data on failure.
        }
        resetPending()
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [Wallet.self, BillRecord.self, Subcategory.self, Subscription.self, Budget.self], inMemory: true)
}
