//
//  AppManagementView.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI
import SwiftData
import UIKit

/// Settings page managing app icons (应用管理): a dense grid of app icons.
struct AppManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ManagedApp.name) private var apps: [ManagedApp]
    @State private var showAdd = false
    @State private var editing: ManagedApp?

    var body: some View {
        Group {
            if apps.isEmpty {
                ContentUnavailableView("No Apps", systemImage: "square.grid.4x4.fill")
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                        ForEach(apps) { app in
                            Button {
                                editing = app
                            } label: {
                                if let imageData = app.imageData, let image = UIImage(data: imageData) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: .infinity)
                                        .aspectRatio(1, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                } else {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(.quaternary)
                                        .aspectRatio(1, contentMode: .fit)
                                        .overlay {
                                            Image(systemName: "app")
                                                .foregroundStyle(.secondary)
                                        }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                .background(Color(.systemGroupedBackground).ignoresSafeArea())
            }
        }
        .navigationTitle("App Management")
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
            AppFormView()
                .presentationDetents([.large])
        }
        .sheet(item: $editing) { app in
            AppFormView(app: app)
                .presentationDetents([.large])
        }
    }
}

/// Form for adding or editing a managed app.
struct AppFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let app: ManagedApp?

    @State private var name = ""
    @State private var imageData: Data?
    @State private var showImagePicker = false
    @State private var pickedImage: UIImage?
    @State private var errorMessage: String?

    init(app: ManagedApp? = nil) {
        self.app = app
        if let app {
            _name = State(initialValue: app.name)
            _imageData = State(initialValue: app.imageData)
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

                if app != nil {
                    Section {
                        Button(role: .destructive) {
                            if let app {
                                modelContext.delete(app)
                            }
                            dismiss()
                        } label: {
                            Text("Delete")
                        }
                    }
                }
            }
            .navigationTitle(app == nil ? String(localized: "Add App") : String(localized: "Edit App"))
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
        .buttonStyle(.plain)
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
            errorMessage = String(localized: "Please enter a name")
            return
        }
        if let app {
            app.name = trimmed
            app.imageData = imageData
        } else {
            modelContext.insert(ManagedApp(name: trimmed, imageData: imageData))
        }
        dismiss()
    }
}

/// Half-modal grid for picking a managed app (软件); nil clears the selection.
struct AppPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ManagedApp.name) private var apps: [ManagedApp]

    let onSelect: (ManagedApp?) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 16) {
                    Button {
                        onSelect(nil)
                        dismiss()
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "xmark.circle")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                            Text("None")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)

                    ForEach(apps) { app in
                        Button {
                            onSelect(app)
                            dismiss()
                        } label: {
                            VStack(spacing: 4) {
                                if let imageData = app.imageData, let image = UIImage(data: imageData) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(maxWidth: .infinity)
                                        .aspectRatio(1, contentMode: .fit)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                } else {
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(.quaternary)
                                        .aspectRatio(1, contentMode: .fit)
                                        .overlay {
                                            Image(systemName: "app")
                                                .foregroundStyle(.secondary)
                                        }
                                }
                                Text(app.name)
                                    .font(.caption2)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Software")
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
        AppManagementView()
    }
    .modelContainer(for: [Wallet.self, BillRecord.self, Subcategory.self, Subscription.self, Budget.self, SavingsGoal.self, SavingsPlan.self, Item.self, QuickRecord.self, ManagedApp.self], inMemory: true)
}
