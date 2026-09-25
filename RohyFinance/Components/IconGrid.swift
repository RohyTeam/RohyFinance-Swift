//
//  IconGrid.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI

/// Horizontally scrolling grid of SF Symbol icons, two rows per column.
struct IconGrid: View {
    let symbols: [String]
    @Binding var selection: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: Array(repeating: GridItem(.fixed(44), spacing: 8), count: 2), spacing: 8) {
                ForEach(symbols, id: \.self) { symbol in
                    let isSelected = selection == symbol
                    Button {
                        selection = symbol
                    } label: {
                        Image(systemName: symbol)
                            .font(.title3)
                            .frame(width: 44, height: 44)
                            .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(height: 104)
    }
}
