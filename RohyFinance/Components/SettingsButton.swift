//
//  SettingsButton.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI

/// Adds a gear button to the top-right toolbar that opens the settings sheet
/// (the former "Profile" tab content).
struct SettingsButtonModifier: ViewModifier {
    @State private var showSettings = false

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                ProfileView()
                    .presentationDetents([.large])
            }
    }
}

extension View {
    func settingsButton() -> some View {
        modifier(SettingsButtonModifier())
    }
}
