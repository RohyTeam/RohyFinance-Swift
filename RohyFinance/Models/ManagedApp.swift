//
//  ManagedApp.swift
//  RohyFinance
//
//  Created by Deerio on 2026/9/24.
//

import Foundation
import SwiftData

/// A managed app entry (应用管理): icon + name.
@Model
final class ManagedApp {
    var name: String = ""
    var imageData: Data?

    init(name: String, imageData: Data?) {
        self.name = name
        self.imageData = imageData
    }
}
