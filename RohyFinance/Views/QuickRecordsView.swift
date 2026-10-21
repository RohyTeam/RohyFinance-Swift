//
//  QuickRecordsView.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI
import SwiftData
import UIKit

/// Grid cell for a quick record template.
struct QuickRecordCell: View {
    let template: QuickRecord

    private var amountText: String {
        switch template.kind {
        case .expense, .saving: return "-\(moneyText(template.amount, currency: template.currency))"
        case .income: return "+\(moneyText(template.amount, currency: template.currency))"
        case .transfer: return moneyText(template.amount, currency: template.currency)
        }
    }

    private var amountColor: Color {
        switch template.kind {
        case .expense: return .red
        case .income: return .green
        case .transfer: return .secondary
        case .saving: return .blue
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            if let imageData = template.imageData, let image = UIImage(data: imageData) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
                    .clipped()
            } else {
                Image(systemName: iconName)
                    .font(.largeTitle)
                    .frame(maxWidth: .infinity)
                    .frame(height: 100)
            }
            VStack(spacing: 4) {
                Text(template.note)
                    .font(.caption)
                    .lineLimit(1)
                Text(amountText)
                    .font(.caption2)
                    .foregroundStyle(amountColor)
            }
            .padding(8)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var iconName: String {
        switch template.kind {
        case .transfer: return "arrow.left.arrow.right"
        case .saving: return "banknote"
        default: return CategoryStore.find(template.categoryKey)?.icon ?? "questionmark"
        }
    }
}

/// Settings page managing quick record templates (管理快捷记账).
struct QuickRecordsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var quickRecords: [QuickRecord]
    @State private var showAdd = false
    @State private var editing: QuickRecord?

    private var sorted: [QuickRecord] {
        quickRecords.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        Group {
            if quickRecords.isEmpty {
                ContentUnavailableView("No Quick Records", systemImage: "bolt")
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(sorted) { template in
                            QuickRecordCell(template: template)
                                .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .contextMenu {
                                    Button {
                                        editing = template
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        modelContext.delete(template)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
            }
        }
        .navigationTitle("Manage Quick Records")
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
            RecordEntryView(template: nil)
                .presentationDetents([.large])
        }
        .sheet(item: $editing) { template in
            RecordEntryView(template: template)
                .presentationDetents([.large])
        }
    }
}

/// Half-modal grid of quick records; tapping one creates the bill instantly.
struct QuickRecordPickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var quickRecords: [QuickRecord]

    private var sorted: [QuickRecord] {
        quickRecords.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        NavigationStack {
            Group {
                if quickRecords.isEmpty {
                    ContentUnavailableView("No Quick Records", systemImage: "bolt")
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(sorted) { template in
                                Button {
                                    template.makeRecord(context: modelContext)
                                    dismiss()
                                } label: {
                                    QuickRecordCell(template: template)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground).ignoresSafeArea())
                }
            }
            .navigationTitle("Quick Record")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        QuickRecordsView()
    }
    .modelContainer(for: [Wallet.self, BillRecord.self, Subcategory.self, Subscription.self, Budget.self, SavingsGoal.self, SavingsPlan.self, Item.self, QuickRecord.self], inMemory: true)
}
