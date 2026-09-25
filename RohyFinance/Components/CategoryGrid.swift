//
//  CategoryGrid.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI

/// Horizontally scrolling grid of categories, three rows per column.
struct CategoryGrid: View {
    let categories: [CategoryDef]
    @Binding var selection: CategoryDef?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHGrid(rows: Array(repeating: GridItem(.fixed(64), spacing: 8), count: 3), spacing: 8) {
                ForEach(categories) { category in
                    let isSelected = selection == category
                    Button {
                        selection = category
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: category.icon)
                                .font(.title2)
                            Text(category.name)
                                .font(.caption2)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(width: 72, height: 64)
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
        .frame(height: 224)
    }
}
