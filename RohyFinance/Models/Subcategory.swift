//
//  Subcategory.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import Foundation
import SwiftData

@Model
final class Subcategory {
    var name: String = ""
    var categoryKey: String = ""

    init(name: String, categoryKey: String) {
        self.name = name
        self.categoryKey = categoryKey
    }
}
