//
//  Light.swift
//  frank_lloyd_light
//
//  Created by 中山智輝 on 2026/02/23.
//

struct DeviceStatus: Codable, Equatable {
    var power: String?
    var brightness: Int?
    var color: String?
    var raw: [String: AnyCodable]
}
