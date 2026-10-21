//
//  ItemsView.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI
import SwiftData

/// The items (物品) tab: a grid of all top-level items with add/edit/delete.
struct ItemsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]
    @State private var showAddItem = false
    @State private var editingItem: Item?
    @State private var convertingItem: Item?
    @Namespace private var namespace

    private var topLevelItems: [Item] {
        items.filter { $0.parent == nil }
    }

    var body: some View {
        NavigationStack {
            Group {
                if topLevelItems.isEmpty {
                    ContentUnavailableView("No Items", systemImage: "shippingbox")
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(topLevelItems) { item in
                                NavigationLink {
                                    ItemDetailView(item: item)
                                        .navigationTransition(.zoom(sourceID: item.id, in: namespace))
                                } label: {
                                    ItemCell(item: item)
                                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .matchedTransitionSource(id: item.id, in: namespace)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        convertingItem = item
                                    } label: {
                                        Label("Convert to Sub-item", systemImage: "arrow.turn.down.right")
                                    }
                                    Button {
                                        editingItem = item
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    Button(role: .destructive) {
                                        modelContext.delete(item)
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
            .navigationTitle("Items")
            .settingsButton()
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddItem = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddItem) {
                ItemFormView()
                    .presentationDetents([.large])
            }
            .sheet(item: $editingItem) { item in
                ItemFormView(item: item)
                    .presentationDetents([.large])
            }
            .sheet(item: $convertingItem) { item in
                ParentItemPickerView(item: item)
                    .presentationDetents([.large])
            }
        }
    }
}

#Preview {
    ItemsView()
        .modelContainer(for: [Wallet.self, BillRecord.self, Subcategory.self, Subscription.self, Budget.self, SavingsGoal.self, SavingsPlan.self, Item.self, QuickRecord.self], inMemory: true)
}
