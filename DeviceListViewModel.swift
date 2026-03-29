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
            if let deviceId = Bundle.main.object(forInfoDictionaryKey: "SWITCHBOT_DEVICE_ID") as? String {
                let cleanedId = deviceId.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                devices = [Device(id: cleanedId, name: "メインの照明", type: .colorBulb)]
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
