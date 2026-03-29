//
//  DeviceListViewModel.swift
//  frank_lloyd_light
//
//  Created on 2026/03/29.
//

import Foundation
import SwiftUI

@MainActor
class DeviceListViewModel: ObservableObject {
    @Published var devices: [Device] = []

    private let userDefaultsKey = "saved_devices"

    init() {
        loadDevices()
    }

    // MARK: - Load Devices

    func loadDevices() {
        // UserDefaultsから読み込む
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode([Device].self, from: data) {
            devices = decoded
        } else {
            // 初回起動時はInfo.plistのデバイスをデフォルトとして追加
            var defaults: [Device] = []
            if let raw = Bundle.main.object(forInfoDictionaryKey: "SWITCHBOT_COLOR_BULB_DEVICE_ID") as? String {
                let id = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                defaults.append(Device(id: id, name: "カラー電球", type: .colorBulb))
            }
            if let raw = Bundle.main.object(forInfoDictionaryKey: "SWITCHBOT_CEILING_LIGHT_PRO") as? String {
                let id = raw.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                defaults.append(Device(id: id, name: "シーリングライト", type: .colorBulb))
            }
            if !defaults.isEmpty {
                devices = defaults
                saveDevices()
            }
        }
    }

    // MARK: - Save Devices

    func saveDevices() {
        if let encoded = try? JSONEncoder().encode(devices) {
            UserDefaults.standard.set(encoded, forKey: userDefaultsKey)
        }
    }

    // MARK: - Add Device

    func addDevice(id: String, name: String, type: Device.DeviceType) {
        let newDevice = Device(id: id, name: name, type: type)
        devices.append(newDevice)
        saveDevices()
    }

    // MARK: - Remove Device

    func removeDevice(at offsets: IndexSet) {
        devices.remove(atOffsets: offsets)
        saveDevices()
    }
}
