//
//  ItemCell.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI
import UIKit

/// Square grid cell for an item: photo fills the cell, info overlays the
/// bottom (centered), usage status shows as a badge at the top-right.
struct ItemCell: View {
    let item: Item

    var body: some View {
        ZStack(alignment: .bottom) {
            itemImage
            VStack(spacing: 4) {
                Text(item.name)
                    .font(.subheadline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
                HStack {
                    Text(moneyText(item.displayValue, currency: item.displayCurrency))
                        .font(.caption)
                    Spacer()
                    Text("Used for \(item.daysInUse) days")
                        .font(.caption2)
                }
            }
            .foregroundStyle(.white)
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
            )
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
        .overlay(alignment: .topTrailing) {
            Text(item.status.localizedName)
                .font(.caption2)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(item.status.color, in: Capsule())
                .foregroundStyle(.white)
                .padding(8)
        }
    }

    @ViewBuilder
    private var itemImage: some View {
        if let imageData = item.imageData, let image = UIImage(data: imageData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(.quaternary)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(.secondary)
                }
        }
    }
}
