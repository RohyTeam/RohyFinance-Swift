//
//  Item.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
