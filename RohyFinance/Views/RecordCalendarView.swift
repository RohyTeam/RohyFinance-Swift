//
//  RecordCalendarView.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI

/// Calendar sheet showing each day's net value (income - expense):
/// green when income exceeds expense, red when expense exceeds income,
/// nothing when balanced.
struct RecordCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("defaultCurrency") private var defaultCurrencyRaw = Currency.defaultForLocale().rawValue
    let records: [BillRecord]
    @State private var month: Date
    @State private var showMonthPicker = false

    /// Day cells are 44pt high with 12pt spacing.
    private static let dayCellHeight: CGFloat = 44
    private static let gridSpacing: CGFloat = 12

    init(records: [BillRecord], month: Date) {
        self.records = records
        _month = State(initialValue: month)
    }

    private var calendar: Calendar { Calendar.current }

    private var defaultCurrency: Currency {
        Currency(rawValue: defaultCurrencyRaw) ?? .usd
    }

    private var netByDay: [Date: Double] {
        var result: [Date: Double] = [:]
        for record in records where calendar.isDate(record.date, equalTo: month, toGranularity: .month) {
            let day = calendar.startOfDay(for: record.date)
            switch record.kind {
            case .income: result[day, default: 0] += record.effective(in: defaultCurrency)
            case .expense: result[day, default: 0] -= record.effective(in: defaultCurrency)
            case .transfer: break
            }
        }
        return result
    }

    private struct DayItem: Identifiable {
        let date: Date
        let inMonth: Bool
        var id: Date { date }
    }

    /// Days of the current month, padded with previous/next month days
    /// so the first and last rows are complete weeks.
    private var days: [DayItem] {
        guard let range = calendar.range(of: .day, in: .month, for: month),
              let first = calendar.date(from: calendar.dateComponents([.year, .month], from: month)) else {
            return []
        }
        let weekday = calendar.component(.weekday, from: first)
        let offset = (weekday - calendar.firstWeekday + 7) % 7

        var items: [DayItem] = []
        for index in 0..<offset {
            let date = calendar.date(byAdding: .day, value: index - offset, to: first)!
            items.append(DayItem(date: date, inMonth: false))
        }
        for day in range {
            let date = calendar.date(byAdding: .day, value: day - 1, to: first)!
            items.append(DayItem(date: date, inMonth: true))
        }
        let remainder = items.count % 7
        if remainder > 0 {
            let last = items.last!.date
            for index in 1...(7 - remainder) {
                let date = calendar.date(byAdding: .day, value: index, to: last)!
                items.append(DayItem(date: date, inMonth: false))
            }
        }
        return items
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.shortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                HStack {
                    Button {
                        shiftYear(-1)
                    } label: {
                        Image(systemName: "chevron.backward.2")
                    }
                    Button {
                        shiftMonth(-1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    Spacer()
                    Button {
                        showMonthPicker = true
                    } label: {
                        Text(month, format: .dateTime.year().month(.wide))
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                    Spacer()
                    Button {
                        shiftMonth(1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    Button {
                        shiftYear(1)
                    } label: {
                        Image(systemName: "chevron.forward.2")
                    }
                }

                HStack(spacing: 0) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: Self.gridSpacing) {
                    ForEach(days) { item in
                        dayCell(item)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 20)
                        .onEnded { value in
                            if value.translation.width <= -50 {
                                shiftMonth(1)
                            } else if value.translation.width >= 50 {
                                shiftMonth(-1)
                            }
                        }
                )

                Spacer()
            }
            .padding()
            .navigationTitle("Calendar")
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
            .sheet(isPresented: $showMonthPicker) {
                MonthYearPickerView(month: $month)
                    .presentationDetents([.height(280)])
            }
        }
    }

    @ViewBuilder
    private func dayCell(_ item: DayItem) -> some View {
        let day = calendar.component(.day, from: item.date)
        if item.inMonth {
            let net = netByDay[calendar.startOfDay(for: item.date)]
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.callout)
                    .fontWeight(calendar.isDateInToday(item.date) ? .bold : .regular)
                if let net, abs(net) >= 0.005 {
                    Text(signedMoneyText(net, currency: defaultCurrency))
                        .font(.caption2)
                        .foregroundStyle(net > 0 ? .green : .red)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                } else {
                    Text(" ")
                        .font(.caption2)
                }
            }
            .frame(maxWidth: .infinity, minHeight: Self.dayCellHeight)
        } else {
            VStack(spacing: 2) {
                Text("\(day)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(" ")
                    .font(.caption2)
            }
            .frame(maxWidth: .infinity, minHeight: Self.dayCellHeight)
        }
    }

    private func shiftMonth(_ value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: month) {
            month = newMonth
        }
    }

    private func shiftYear(_ value: Int) {
        if let newMonth = calendar.date(byAdding: .year, value: value, to: month) {
            month = newMonth
        }
    }
}

/// Wheel-style month/year picker: years from 1900 to the current year.
struct MonthYearPickerView: View {
    @Binding var month: Date
    @State private var year: Int
    @State private var monthIndex: Int

    private var calendar: Calendar { Calendar.current }
    private var currentYear: Int { calendar.component(.year, from: .now) }

    init(month: Binding<Date>) {
        _month = month
        let components = Calendar.current.dateComponents([.year, .month], from: month.wrappedValue)
        _year = State(initialValue: components.year ?? 2000)
        _monthIndex = State(initialValue: components.month ?? 1)
    }

    var body: some View {
        HStack(spacing: 0) {
            Picker("Year", selection: $year) {
                ForEach(1900...currentYear, id: \.self) { year in
                    Text(yearLabel(year)).tag(year)
                }
            }
            .pickerStyle(.wheel)
            .onChange(of: year) { _, _ in apply() }

            Picker("Month", selection: $monthIndex) {
                ForEach(1...12, id: \.self) { month in
                    Text(monthLabel(month)).tag(month)
                }
            }
            .pickerStyle(.wheel)
            .onChange(of: monthIndex) { _, _ in apply() }
        }
        .padding()
    }

    private func yearLabel(_ year: Int) -> String {
        let date = calendar.date(from: DateComponents(year: year, month: 1, day: 1))!
        return date.formatted(.dateTime.year())
    }

    private func monthLabel(_ month: Int) -> String {
        let date = calendar.date(from: DateComponents(year: 2000, month: month, day: 1))!
        return date.formatted(.dateTime.month(.wide))
    }

    private func apply() {
        if let date = calendar.date(from: DateComponents(year: year, month: monthIndex, day: 1)) {
            month = date
        }
    }
}
