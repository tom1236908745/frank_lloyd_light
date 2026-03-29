//
//  CeilingLightViewModel.swift
//  frank_lloyd_light
//
//  Created on 2026/03/29.
//

import Foundation
import SwiftUI

class CeilingLightViewModel: ObservableObject {
    /// 2700K（電球色）〜 6500K（昼光色）
    static let minKelvin: Double = 2700
    static let maxKelvin: Double = 6500

    @Published var isTurnOn: Bool = false
    @Published var brightness: Double = 0.8   // 0.0 ... 1.0
    @Published var colorTemperature: Double = 0.3  // 0.0(暖色) ... 1.0(寒色)
    @Published var isLoading: Bool = false

    private let useCase: LightControlUseCase
    private let deviceId: String

    init(deviceId: String, useCase: LightControlUseCase? = nil) {
        self.deviceId = deviceId
        self.useCase = useCase ?? DIContainer.shared.makeLightControlUseCase(deviceId: deviceId)
    }

    /// colorTemperature (0.0-1.0) → Kelvin 値
    var kelvin: Int {
        let k = Self.minKelvin + colorTemperature * (Self.maxKelvin - Self.minKelvin)
        return Int(k.rounded())
    }

    // MARK: - API

    @MainActor
    func loadStatus() async {
        isLoading = true
        do {
            let status = try await useCase.executeFetch()
            isTurnOn = status.power?.lowercased() == "on"
            if let b = status.brightness {
                brightness = Double(min(max(b, 0), 100)) / 100.0
            }
            if let ct = status.raw["colorTemperature"]?.value as? Int {
                let clamped = min(max(Double(ct), Self.minKelvin), Self.maxKelvin)
                colorTemperature = (clamped - Self.minKelvin) / (Self.maxKelvin - Self.minKelvin)
            }
        } catch {
            print("[CeilingLightViewModel] loadStatus error:", error)
        }
        isLoading = false
    }

    @MainActor
    func toggleUIOnly() {
        isTurnOn.toggle()
    }

    @MainActor
    func updateBrightness(_ value: Double) {
        brightness = min(max(value, 0.0), 1.0)
    }

    @MainActor
    func updateColorTemperature(_ value: Double) {
        colorTemperature = min(max(value, 0.0), 1.0)
    }

    func sendCommand(command: String, parameter: String = "default") async throws {
        try await useCase.executeUpdateDeviceStatus(command: command, parameter: parameter)
    }
}
