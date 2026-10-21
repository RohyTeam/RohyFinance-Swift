//
//  ItemDetailView.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI
import SwiftData
import UIKit

/// Item detail page: hero image, info, cost breakdown, sub-items grid.
struct ItemDetailView: View {
    @Environment(\.modelContext) private var modelContext
    let item: Item

    @State private var showAddSubItem = false
    @State private var editingSubItem: Item?

    private var subItems: [Item] {
        (item.children ?? []).sorted { $0.name < $1.name }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heroImage

                VStack(alignment: .leading, spacing: 8) {
                    Text(item.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(moneyText(item.displayValue, currency: item.displayCurrency))
                    Text("\(item.displayPurchaseDate.formatted(.dateTime.year().month().day())) \(String(localized: "Purchased"))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(item.status.localizedName)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(item.status.color, in: Capsule())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal)

                costCard
                    .padding(.horizontal)

                if !subItems.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Sub-items")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 32)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(subItems) { subItem in
                                ItemCell(item: subItem)
                                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .contextMenu {
                                        Button {
                                            editingSubItem = subItem
                                        } label: {
                                            Label("Edit", systemImage: "pencil")
                                        }
                                        Button {
                                            subItem.parent = nil
                                        } label: {
                                            Label("Remove from Sub-items", systemImage: "arrow.up.doc")
                                        }
                                        Button(role: .destructive) {
                                            modelContext.delete(subItem)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showAddSubItem = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showAddSubItem) {
            ItemFormView(parent: item)
                .presentationDetents([.large])
        }
        .sheet(item: $editingSubItem) { subItem in
            ItemFormView(item: subItem)
                .presentationDetents([.large])
        }
    }

    @ViewBuilder
    private var heroImage: some View {
        if let imageData = item.imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .clipped()
        } else {
            Rectangle()
                .fill(.quaternary)
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .overlay {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
        }
    }

    private var costCard: some View {
        VStack(spacing: 0) {
            costRow("Item Cost", value: item.displayValue)
            Divider().padding(.leading, 16)
            costRow("Sub-item Cost", value: item.childrenCost)
            Divider().padding(.leading, 16)
            costRow("Total Cost", value: item.totalCost, bold: true)
        }
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func costRow(_ title: LocalizedStringKey, value: Double, bold: Bool = false) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(moneyText(value, currency: item.displayCurrency))
                .fontWeight(bold ? .semibold : .regular)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

/// Half-modal picker choosing the parent item for "转为子物品".
struct ParentItemPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var items: [Item]

    /// The item being converted; excluded from the options.
    let item: Item

    private var candidates: [Item] {
        items.filter { $0.parent == nil && $0 !== item }
            .sorted { $0.name < $1.name }
    }

    var body: some View {
        NavigationStack {
            Group {
                if candidates.isEmpty {
                    ContentUnavailableView("No Items", systemImage: "shippingbox")
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(candidates) { candidate in
                                Button {
                                    item.parent = candidate
                                    dismiss()
                                } label: {
                                    ItemCell(item: candidate)
                                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground).ignoresSafeArea())
                }
            }
            .navigationTitle("Convert to Sub-item")
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
