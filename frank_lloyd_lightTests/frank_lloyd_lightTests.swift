//
//  frank_lloyd_lightTests.swift
//  frank_lloyd_lightTests
//
//  Created by 中山智輝 on 2025/11/20.
//

import Testing
import Foundation
import CryptoKit

@testable import frank_lloyd_light

struct frank_lloyd_lightTests {
    
    struct MockLightRepository: LightRepositoryProtocol {
        func fetchIsTurnOnStatus() async throws -> DeviceStatus {
            return DeviceStatus(
                power: "on",
                brightness: 34,
                color: "81:255:81",
                raw: ["deviceType": frank_lloyd_light.AnyCodable("Color Bulb"), "color": frank_lloyd_light.AnyCodable("81:255:81"), "brightness": frank_lloyd_light.AnyCodable(34), "colorTemperature": frank_lloyd_light.AnyCodable(0), "hubDeviceId": frank_lloyd_light.AnyCodable("94A99077E00A"), "deviceId": frank_lloyd_light.AnyCodable("94A99077E00A"), "power": frank_lloyd_light.AnyCodable("on"), "version": frank_lloyd_light.AnyCodable("V2.0-2.0")]
            )
        }

        func updateIsTurnOnStatus(isTurnOn: Bool) async throws {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }

        func updateDeviceStatus(command: String, parameter: String = "default") async throws {
            try await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }
    
    @Test("配列要素に指定要素が含まれるか確認")
    func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
        let array = [1,2,3,4]
        let num = 4
        try #require(array.isEmpty == false)
        #expect(array.contains(num))
    }
    
    @Test("UseCase用の検証")
    func lightControlUseaCaseTest() async throws {
        let container = DIContainer(lightRepositoryProvider: { MockLightRepository() })
        let usecase: LightControlUseCase = container.makeLightControlUseCase()
        
        let devideStatus = try await usecase.executeFetch()
        
        let expectedPowerStatus: String = "on"
        let expectedBrightness: Int = 34
        let expectedColor: String = "81:255:81"

        #expect(devideStatus.power == expectedPowerStatus)
        #expect(devideStatus.brightness == expectedBrightness)
        #expect(devideStatus.color == expectedColor)
    }
}

