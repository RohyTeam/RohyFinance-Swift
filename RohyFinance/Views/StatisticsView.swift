//
//  StatisticsView.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI
import SwiftData
import Charts

struct StatisticsView: View {
    @Query private var records: [BillRecord]
    @AppStorage("defaultCurrency") private var defaultCurrencyRaw = Currency.defaultForLocale().rawValue
    @State private var selectedMonth: Date?
    @State private var showCalendar = false

    private var calendar: Calendar { Calendar.current }

    private var defaultCurrency: Currency {
        Currency(rawValue: defaultCurrencyRaw) ?? .usd
    }

    /// Months that have at least one record, latest first.
    private var availableMonths: [Date] {
        var seen = Set<Date>()
        var months: [Date] = []
        for record in records.sorted(by: { $0.date > $1.date }) {
            guard let month = calendar.date(from: calendar.dateComponents([.year, .month], from: record.date)) else { continue }
            if seen.insert(month).inserted {
                months.append(month)
            }
        }
        return months
    }

    private var activeMonth: Date {
        if let selectedMonth { return selectedMonth }
        if let first = availableMonths.first { return first }
        return calendar.date(from: calendar.dateComponents([.year, .month], from: .now)) ?? .now
    }

    private func recordsIn(_ month: Date) -> [BillRecord] {
        records.filter { calendar.isDate($0.date, equalTo: month, toGranularity: .month) }
    }

    private func expenseTotal(in month: Date) -> Double {
        recordsIn(month).filter { $0.kind == .expense }.reduce(0) { $0 + $1.effective(in: defaultCurrency) }
    }

    private func incomeTotal(in month: Date) -> Double {
        recordsIn(month).filter { $0.kind == .income }.reduce(0) { $0 + $1.effective(in: defaultCurrency) }
    }

    private var previousMonth: Date {
        calendar.date(byAdding: .month, value: -1, to: activeMonth) ?? activeMonth
    }

    private struct CategoryTotal: Identifiable {
        let category: CategoryDef
        let total: Double
        var id: String { category.id }
    }

    private var expenseByCategory: [CategoryTotal] {
        totalsByCategory(kind: .expense)
    }

    private var incomeByCategory: [CategoryTotal] {
        totalsByCategory(kind: .income)
    }

    private func totalsByCategory(kind: RecordKind) -> [CategoryTotal] {
        let filtered = recordsIn(activeMonth).filter { $0.kind == kind }
        let grouped = Dictionary(grouping: filtered, by: \.categoryKey)
        return grouped.compactMap { key, records in
            guard let category = CategoryStore.find(key) else { return nil }
            return CategoryTotal(category: category, total: records.reduce(0) { $0 + $1.effective(in: defaultCurrency) })
        }
        .sorted { $0.total > $1.total }
    }

    private struct CurrencyKindTotal: Identifiable {
        let currency: Currency
        let kind: RecordKind
        let total: Double
        var id: String { "\(currency.rawValue)-\(kind.rawValue)" }
    }

    /// Income/expense totals grouped by the records' original currencies.
    private var totalsByCurrency: [CurrencyKindTotal] {
        let filtered = recordsIn(activeMonth).filter { $0.kind != .transfer }
        var totals: [String: Double] = [:]
        for record in filtered {
            totals[record.currencyRaw + record.kindRaw, default: 0] += record.effectiveAmount
        }
        return totals.compactMap { key, total -> CurrencyKindTotal? in
            for kind in [RecordKind.expense, .income] where key.hasSuffix(kind.rawValue) {
                let currencyRaw = String(key.dropLast(kind.rawValue.count))
                guard let currency = Currency(rawValue: currencyRaw) else { return nil }
                return CurrencyKindTotal(currency: currency, kind: kind, total: total)
            }
            return nil
        }
        .sorted { lhs, rhs in
            if lhs.currency.rawValue != rhs.currency.rawValue {
                return lhs.currency.rawValue < rhs.currency.rawValue
            }
            return lhs.kind.rawValue < rhs.kind.rawValue
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if availableMonths.isEmpty {
                    ContentUnavailableView("No Records", systemImage: "chart.pie", description: Text("Add a record to see statistics"))
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            monthMenu
                            summaryRow
                            charts
                            comparison
                            currencyBarChart
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Statistics")
            .toolbar {
                if !availableMonths.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showCalendar = true
                        } label: {
                            Image(systemName: "calendar")
                        }
                    }
                }
            }
            .sheet(isPresented: $showCalendar) {
                RecordCalendarView(records: records, month: activeMonth)
                    .presentationDetents([.medium])
            }
        }
    }

    private var monthMenu: some View {
        Menu {
            ForEach(availableMonths, id: \.self) { month in
                Button {
                    selectedMonth = month
                } label: {
                    Text(month, format: .dateTime.year().month(.wide))
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(activeMonth, format: .dateTime.year().month(.wide))
                    .font(.title3)
                    .fontWeight(.semibold)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption)
            }
            .foregroundStyle(.primary)
        }
    }

    private var summaryRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Monthly Expense")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(moneyText(expenseTotal(in: activeMonth), currency: defaultCurrency))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.red)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("Monthly Income")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(moneyText(incomeTotal(in: activeMonth), currency: defaultCurrency))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
            }
        }
    }

    private var charts: some View {
        HStack(spacing: 16) {
            chartColumn(title: "Expense", emptyTitle: "No expenses this month", data: expenseByCategory)
            chartColumn(title: "Income", emptyTitle: "No income this month", data: incomeByCategory)
        }
    }

    @ViewBuilder
    private func chartColumn(title: LocalizedStringKey, emptyTitle: LocalizedStringKey, data: [CategoryTotal]) -> some View {
        VStack(spacing: 8) {
            if data.isEmpty {
                ZStack {
                    Chart {
                        SectorMark(
                            angle: .value("Amount", 1),
                            innerRadius: .ratio(0.6)
                        )
                        .foregroundStyle(Color.gray.opacity(0.25))
                    }
                    .chartLegend(.hidden)
                    .chartPlotStyle { plot in
                        plot.frame(height: 140)
                    }
                    Text(emptyTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(height: 180, alignment: .top)
                .frame(maxWidth: .infinity)
            } else {
                Chart(data) { item in
                    SectorMark(
                        angle: .value("Amount", item.total),
                        innerRadius: .ratio(0.6),
                        angularInset: 1.5
                    )
                    .cornerRadius(4)
                    .foregroundStyle(by: .value("Category", item.category.name))
                }
                .chartPlotStyle { plot in
                    plot.frame(height: 140)
                }
                .frame(height: 180, alignment: .top)
            }
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var comparison: some View {
        VStack(spacing: 12) {
            diffRow(
                title: "Expense vs last month",
                diff: expenseTotal(in: activeMonth) - expenseTotal(in: previousMonth),
                positiveIsGood: false
            )
            diffRow(
                title: "Income vs last month",
                diff: incomeTotal(in: activeMonth) - incomeTotal(in: previousMonth),
                positiveIsGood: true
            )
        }
    }

    private func diffRow(title: LocalizedStringKey, diff: Double, positiveIsGood: Bool) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(signedMoneyText(diff, currency: defaultCurrency))
                .fontWeight(.medium)
                .foregroundStyle(diffColor(diff: diff, positiveIsGood: positiveIsGood))
        }
    }

    private struct CurrencyBar: Identifiable {
        let currency: Currency
        let kind: RecordKind
        let total: Double
        /// Position on a continuous x scale: two slots per currency.
        let position: Double
        var id: String { "\(currency.rawValue)-\(kind.rawValue)" }
    }

    /// Bars laid out on a continuous x scale so they naturally hug the leading edge.
    private var currencyBars: [CurrencyBar] {
        let grouped = Dictionary(grouping: totalsByCurrency, by: \.currency)
        let currencies = grouped.keys.sorted { $0.rawValue < $1.rawValue }
        var bars: [CurrencyBar] = []
        for (index, currency) in currencies.enumerated() {
            for (offset, kind) in [RecordKind.expense, .income].enumerated() {
                if let item = grouped[currency]?.first(where: { $0.kind == kind }) {
                    bars.append(CurrencyBar(currency: currency, kind: kind, total: item.total, position: Double(index * 2 + offset)))
                }
            }
        }
        return bars
    }

    private var barAxisLabels: [(position: Double, symbol: String)] {
        let currencies = Set(currencyBars.map(\.currency)).sorted { $0.rawValue < $1.rawValue }
        return currencies.enumerated().map { (Double($0.offset * 2) + 0.5, $0.element.symbol) }
    }

    @ViewBuilder
    private var currencyBarChart: some View {
        if !currencyBars.isEmpty {
            let slotCount = Set(currencyBars.map(\.currency)).count * 2
            Chart(currencyBars) { item in
                BarMark(
                    x: .value("Position", item.position),
                    y: .value("Amount", item.total),
                    width: .fixed(28)
                )
                .foregroundStyle(by: .value("Kind", item.kind.localizedName))
                .annotation(position: .top) {
                    Text(moneyText(item.total, currency: item.currency))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .chartXScale(domain: -0.75...max(Double(slotCount) - 0.25, 5.75))
            .chartXAxis {
                AxisMarks(values: barAxisLabels.map(\.position)) { value in
                    if let position = value.as(Double.self),
                       let label = barAxisLabels.first(where: { $0.position == position }) {
                        AxisValueLabel(label.symbol)
                    }
                }
            }
            .chartForegroundStyleScale([
                RecordKind.expense.localizedName: Color.red,
                RecordKind.income.localizedName: Color.green,
            ])
            .frame(height: 220)
        }
    }

    private func diffColor(diff: Double, positiveIsGood: Bool) -> Color {
        if abs(diff) < 0.005 { return .secondary }
        let good = (diff > 0) == positiveIsGood
        return good ? .green : .red
    }
}

#Preview {
    StatisticsView()
        .modelContainer(for: [Wallet.self, BillRecord.self, Subcategory.self], inMemory: true)
}
