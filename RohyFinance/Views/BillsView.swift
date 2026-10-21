//
//  BillsView.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI
import SwiftData

struct BillsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \BillRecord.date, order: .reverse) private var records: [BillRecord]
    @Query private var items: [Item]
    @State private var editing: BillRecord?
    @State private var errorMessage: String?

    private var calendar: Calendar { Calendar.current }

    private struct DayGroup: Identifiable {
        let day: Date
        let records: [BillRecord]
        var id: Date { day }
    }

    private var grouped: [DayGroup] {
        let byDay = Dictionary(grouping: records) { calendar.startOfDay(for: $0.date) }
        return byDay.keys.sorted(by: >).map { day in
            DayGroup(day: day, records: byDay[day]!.sorted { $0.date > $1.date })
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(grouped) { group in
                    Section {
                        ForEach(group.records) { record in
                            RecordRow(record: record)
                                .swipeActions {
                                    Button(role: .destructive) {
                                        delete(record)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    Button {
                                        editing = record
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.orange)
                                }
                        }
                    } header: {
                        Text(dayTitle(group.day))
                    }
                }
            }
            .navigationTitle("Bills")
            .settingsButton()
            .overlay {
                if records.isEmpty {
                    ContentUnavailableView("No Bills", systemImage: "list.bullet.rectangle", description: Text("Your records will appear here"))
                }
            }
            .sheet(item: $editing) { record in
                RecordEntryView(record: record)
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

    /// Deletes a record and reverts its effect on wallet balances.
    /// Records bound to an item cannot be deleted.
    private func delete(_ record: BillRecord) {
        if items.contains(where: { $0.record === record }) {
            errorMessage = String(localized: "This record is linked to an item and cannot be deleted")
            return
        }
        record.revertBalanceEffect()
        modelContext.delete(record)
    }

    private func dayTitle(_ date: Date) -> String {
        if calendar.isDateInToday(date) {
            return String(localized: "Today")
        }
        if calendar.component(.year, from: date) == calendar.component(.year, from: .now) {
            return date.formatted(.dateTime.month(.wide).day())
        }
        return date.formatted(.dateTime.year().month(.wide).day())
    }
}

struct RecordRow: View {
    let record: BillRecord
    @AppStorage("defaultCurrency") private var defaultCurrencyRaw = Currency.defaultForLocale().rawValue

    private var defaultCurrency: Currency {
        Currency(rawValue: defaultCurrencyRaw) ?? .usd
    }

    private var isDefaultCurrency: Bool {
        record.currency == defaultCurrency
    }

    private var categoryIcon: String {
        if record.kind == .transfer { return "arrow.left.arrow.right" }
        if record.kind == .saving { return "banknote" }
        return CategoryStore.find(record.categoryKey)?.icon ?? "questionmark"
    }

    private var amountColor: Color {
        switch record.kind {
        case .expense: return .red
        case .income: return .green
        case .transfer: return .secondary
        case .saving: return .blue
        }
    }

    /// Main amount in the original currency, with the converted value in
    /// parentheses when the record uses a non-default currency.
    private var amountMain: String {
        let main: String
        switch record.kind {
        case .expense: main = "-\(moneyText(record.effectiveAmount, currency: record.currency))"
        case .income: main = "+\(moneyText(record.effectiveAmount, currency: record.currency))"
        case .transfer: main = moneyText(record.amount, currency: record.currency)
        case .saving: main = "-\(moneyText(record.effectiveAmount, currency: record.currency))"
        }
        if isDefaultCurrency { return main }
        let converted = moneyText(abs(record.effective(in: defaultCurrency)), currency: defaultCurrency)
        return "\(main)（\(converted)）"
    }

    /// Parenthesized detail, e.g. （￥100.00 - ￥20.00）for tax/discount.
    private var amountDetail: String? {
        var parts: [String]
        switch record.kind {
        case .income:
            guard let tax = record.taxAmount else { return nil }
            parts = [moneyText(record.amount, currency: record.currency), "-", moneyText(tax, currency: record.currency)]
        case .expense:
            guard record.discountAmount != nil || record.consumptionTaxAmount != nil else { return nil }
            parts = [moneyText(record.amount, currency: record.currency)]
            if let discount = record.discountAmount {
                parts += ["-", moneyText(discount, currency: record.currency)]
            }
            if let tax = record.consumptionTaxAmount {
                parts += ["+", moneyText(tax, currency: record.currency)]
            }
        case .transfer, .saving:
            return nil
        }
        return "（" + parts.joined(separator: " ") + "）"
    }

    var body: some View {
        HStack(spacing: 12) {
            if record.kind == .saving, record.savingsGoal?.imageData != nil {
                GoalIcon(goal: record.savingsGoal, size: 40)
            } else {
                Image(systemName: categoryIcon)
                    .font(.title2)
                    .frame(width: 40, height: 40)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(record.note)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(amountMain)
                        .foregroundStyle(amountColor)
                    if isDefaultCurrency, let amountDetail {
                        Text(amountDetail)
                            .foregroundStyle(.secondary)
                    }
                    walletLabel
                }
                .font(.caption)
                if !isDefaultCurrency, let amountDetail {
                    Text(amountDetail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Text(record.date, format: .dateTime.hour().minute())
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var walletLabel: some View {
        if record.kind == .transfer {
            HStack(spacing: 4) {
                WalletIconView(wallet: record.wallet, size: 14)
                Text(record.wallet?.displayName ?? "-")
                Image(systemName: "arrow.right")
                WalletIconView(wallet: record.targetWallet, size: 14)
                Text(record.targetWallet?.displayName ?? "-")
            }
            .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 4) {
                WalletIconView(wallet: record.wallet, size: 14)
                Text(record.wallet?.displayName ?? "-")
            }
            .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    BillsView()
        .modelContainer(for: [Wallet.self, BillRecord.self, Subcategory.self, Subscription.self, Budget.self, SavingsGoal.self, SavingsPlan.self, Item.self], inMemory: true)
}
