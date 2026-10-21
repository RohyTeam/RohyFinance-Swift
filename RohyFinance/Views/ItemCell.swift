//
//  ItemCell.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI
import UIKit

/// Square grid cell for an item: photo fills the cell, info overlays the bottom.
struct ItemCell: View {
    let item: Item

    var body: some View {
        ZStack(alignment: .bottom) {
            itemImage
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.subheadline)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
                HStack {
                    Text(moneyText(item.displayValue, currency: item.displayCurrency))
                        .font(.caption)
                    Spacer()
                    Text(item.status.localizedName)
                        .font(.caption)
                        .foregroundStyle(item.status.color)
                }
                Text("Days in use: \(item.daysInUse)")
                    .font(.caption2)
            }
            .foregroundStyle(.white)
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
            )
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(1, contentMode: .fit)
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
