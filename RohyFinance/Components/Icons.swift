//
//  Icons.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import SwiftUI
import UIKit

/// Renders an asset image with rounded corners baked into the bitmap, so the
/// shape survives contexts that ignore view modifiers (e.g. Menu item icons).
func roundedAssetImage(_ assetName: String, size: CGFloat = 60, cornerRadius: CGFloat? = nil) -> Image {
    guard let image = UIImage(named: assetName) else { return Image(assetName) }
    let radius = cornerRadius ?? size * 0.22
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
    let rounded = renderer.image { _ in
        UIBezierPath(roundedRect: CGRect(x: 0, y: 0, width: size, height: size), cornerRadius: radius).addClip()
        image.draw(in: CGRect(x: 0, y: 0, width: size, height: size))
    }
    return Image(uiImage: rounded)
}

/// Icon for a wallet source: asset image for banks/apps, emoji for cash.
struct SourceIconView: View {
    let source: WalletSource
    var size: CGFloat = 28

    var body: some View {
        if let assetName = source.assetName {
            Image(assetName)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        } else {
            Text(source.emoji ?? "❓")
                .font(.system(size: size * 0.75))
                .frame(width: size, height: size)
        }
    }
}

/// Icon for a wallet instance, with a placeholder for deleted wallets.
struct WalletIconView: View {
    let wallet: Wallet?
    var size: CGFloat = 28

    var body: some View {
        if let wallet {
            SourceIconView(source: wallet.source, size: size)
        } else {
            Image(systemName: "questionmark.circle")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .foregroundStyle(.secondary)
        }
    }
}
