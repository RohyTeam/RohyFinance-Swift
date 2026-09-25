//
//  SubcategoryManagementView.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI
import SwiftData

/// Lists all user-defined subcategories, with add/edit/delete support.
struct SubcategoryManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Subcategory.name) private var subcategories: [Subcategory]
    @State private var showAdd = false
    @State private var editing: Subcategory?

    var body: some View {
        List {
            ForEach(subcategories) { subcategory in
                HStack(spacing: 12) {
                    if let category = CategoryStore.find(subcategory.categoryKey) {
                        Image(systemName: category.icon)
                            .frame(width: 28, height: 28)
                        Text(category.name)
                            .foregroundStyle(.secondary)
                    }
                    Text(subcategory.name)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        modelContext.delete(subcategory)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    Button {
                        editing = subcategory
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
            }
        }
        .navigationTitle("Subcategory Management")
        .overlay {
            if subcategories.isEmpty {
                ContentUnavailableView("No Subcategories", systemImage: "tag", description: Text("Your subcategories will appear here"))
            }
        }
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
            SubcategoryFormView()
                .presentationDetents([.large])
        }
        .sheet(item: $editing) { subcategory in
            SubcategoryFormView(subcategory: subcategory)
                .presentationDetents([.large])
        }
    }
}

/// Form for creating or editing a subcategory.
struct SubcategoryFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let subcategory: Subcategory?

    @State private var category: CategoryDef?
    @State private var name = ""
    @State private var errorMessage: String?

    init(subcategory: Subcategory? = nil) {
        self.subcategory = subcategory
        if let subcategory {
            _category = State(initialValue: CategoryStore.find(subcategory.categoryKey))
            _name = State(initialValue: subcategory.name)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Category") {
                    CategoryGrid(categories: CategoryStore.all, selection: $category)
                }

                Section {
                    TextField("Name", text: $name)
                }
            }
            .navigationTitle(subcategory == nil ? "Add Subcategory" : "Edit Subcategory")
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
        guard let category else {
            errorMessage = String(localized: "Please select a category")
            return
        }
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            errorMessage = String(localized: "Please enter a name")
            return
        }
        if let subcategory {
            subcategory.categoryKey = category.key
            subcategory.name = trimmed
        } else {
            modelContext.insert(Subcategory(name: trimmed, categoryKey: category.key))
        }
        dismiss()
    }
}

#Preview {
    NavigationStack {
        SubcategoryManagementView()
    }
    .modelContainer(for: [Wallet.self, BillRecord.self, Subcategory.self, Subscription.self], inMemory: true)
}
