//
//  AmountField.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI

/// Custom amount field: integer part, a fixed ".", then a two-digit part.
/// The integer field fills all available width and is right-aligned.
struct AmountField: View {
    @Binding var intPart: String
    @Binding var fracPart: String

    var body: some View {
        HStack(spacing: 2) {
            TextField("0", text: $intPart)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity)
                .onChange(of: intPart) { _, value in
                    intPart = value.filter { $0.isNumber }
                }
            Text(".")
            TextField("00", text: $fracPart)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 32)
                .onChange(of: fracPart) { _, value in
                    fracPart = String(value.filter { $0.isNumber }.prefix(2))
                }
        }
    }

    var value: Double {
        (Double(intPart) ?? 0) + (Double(fracPart) ?? 0) / 100
    }
}
