//
//  Device.swift
//  frank_lloyd_light
//
//  Created on 2026/03/29.
//

import Foundation

struct Device: Identifiable, Codable, Hashable {
    let id: String  // デバイスID（SwitchBot API用）
    let name: String  // 表示名（例: "リビングの照明"）
    let type: DeviceType

    enum DeviceType: String, Codable {
        case colorBulb = "Color Bulb"
        case stripLight = "LED Strip Light"
        case plug = "Plug"
    }
}
