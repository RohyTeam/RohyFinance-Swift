//
//  ContentView.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var showRecordSheet = false

    var body: some View {
        TabView {
            Tab("Statistics", systemImage: "chart.pie") {
                StatisticsView()
            }
            Tab("Bills", systemImage: "list.bullet") {
                BillsView()
            }
            Tab("Subscriptions", systemImage: "repeat") {
                SubscriptionsView()
            }
            Tab("Assets", systemImage: "wallet.pass") {
                WalletsView()
            }
            Tab("Profile", systemImage: "person.crop.circle") {
                ProfileView()
            }
        }
        .tabViewBottomAccessory {
            Button {
                showRecordSheet = true
            } label: {
                Label("Record", systemImage: "plus")
            }
        }
        .sheet(isPresented: $showRecordSheet) {
            RecordEntryView()
                .presentationDetents([.large])
        }
        .task {
            SubscriptionBilling.generateDueBills(context: modelContext)
        }
    }
}

/// Placeholder for tabs that are not implemented yet.
struct PlaceholderView: View {
    var body: some View {
        NavigationStack {
            Text("Coming Soon")
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Wallet.self, BillRecord.self, Subcategory.self, Subscription.self, Budget.self], inMemory: true)
}
