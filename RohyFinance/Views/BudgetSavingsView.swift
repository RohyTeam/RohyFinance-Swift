//
//  BudgetSavingsView.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI
import SwiftData
import UIKit

/// Lists the savings plans (攒钱计划) of a budget, reorderable by drag.
struct BudgetSavingsView: View {
    @Environment(\.modelContext) private var modelContext
    let budget: Budget
    @Query private var plans: [SavingsPlan]
    @State private var showAdd = false

    private var budgetPlans: [SavingsPlan] {
        plans
            .filter { $0.budget === budget }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        Group {
            if budgetPlans.isEmpty {
                ContentUnavailableView("No Savings Plans", systemImage: "chart.line.uptrend.xyaxis")
            } else {
                List {
                    ForEach(budgetPlans) { plan in
                        HStack(spacing: 12) {
                            GoalIcon(goal: plan.goal, size: 32)
                            Text(plan.goal?.name ?? "-")
                            Spacer()
                            if plan.allRemaining {
                                Text("All Remaining")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(moneyText(plan.amount, currency: budget.currency))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onMove(perform: move)
                }
            }
        }
        .navigationTitle(budget.name)
        .navigationBarTitleDisplayMode(.inline)
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
            SavingsPlanFormView(budget: budget, sortOrder: (budgetPlans.last?.sortOrder ?? -1) + 1)
                .presentationDetents([.large])
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = budgetPlans
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, plan) in ordered.enumerated() {
            plan.sortOrder = index
        }
    }
}

/// Icon for a savings goal: imported image or placeholder symbol.
struct GoalIcon: View {
    let goal: SavingsGoal?
    var size: CGFloat = 32

    var body: some View {
        if let imageData = goal?.imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        } else {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(.secondary)
        }
    }
}

/// Half-modal form adding a savings plan to a budget.
struct SavingsPlanFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var goals: [SavingsGoal]

    let budget: Budget
    let sortOrder: Int

    @State private var goal: SavingsGoal?
    @State private var allRemaining = false
    @State private var intPart = ""
    @State private var fracPart = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Picker(selection: $goal) {
                    Text("Select").tag(SavingsGoal?.none)
                    ForEach(goals) { goal in
                        Text("\(goal.currency.symbol) \(goal.name)")
                            .tag(SavingsGoal?.some(goal))
                    }
                } label: {
                    Text("Savings Wallet")
                }
                .pickerStyle(.menu)

                Toggle("All Remaining", isOn: $allRemaining)

                HStack {
                    Text("Amount")
                        .foregroundStyle(allRemaining ? Color.secondary : Color.primary)
                    AmountField(intPart: $intPart, fracPart: $fracPart)
                        .disabled(allRemaining)
                }
            }
            .navigationTitle("Add Savings Plan")
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
        }
    }

    private var errorPresented: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func confirm() {
        guard let goal else {
            errorMessage = String(localized: "Please select a savings goal")
            return
        }
        let amount = (Double(intPart) ?? 0) + (Double(fracPart) ?? 0) / 100
        if !allRemaining {
            guard amount > 0 else {
                errorMessage = String(localized: "Please enter an amount")
                return
            }
        }
        modelContext.insert(SavingsPlan(budget: budget, goal: goal, amount: amount, allRemaining: allRemaining, sortOrder: sortOrder))
        dismiss()
    }
}

#Preview {
    NavigationStack {
        BudgetSavingsView(budget: Budget(icon: "fork.knife", name: "预算", wallet: nil, currency: .cny, amount: 100, period: .monthly))
    }
    .modelContainer(for: [Wallet.self, BillRecord.self, Subcategory.self, Subscription.self, Budget.self, SavingsGoal.self, SavingsPlan.self, Item.self, QuickRecord.self], inMemory: true)
}
