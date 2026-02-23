//
//  FirebaseLightRepository.swift
//  frank_lloyd_light
//
//  Created by 中山智輝 on 2026/02/14.
//

import Foundation
import CryptoKit

enum SwitchBotAPIError: Error {
    case invalidResponse
    case requestError
}

struct LightRepository: LightRepositoryProtocol {
    func fetchIsTurnOnStatus() async throws -> DeviceStatus {
//        await FirebaseDatabaseClient.fetchIsTurnOnStatus()
        
        do {
            let (data, response) = try await URLSession.shared.data(for: SwitchBotClient.fetchDeviceStatus())
            if let http = response as? HTTPURLResponse {
                print("[SwitchBot] HTTP status:", http.statusCode)
                if http.statusCode == 401 {
                    print("[SwitchBot][Hint] 401 Unauthorized: トークン/シークレット/署名を再確認してください。")
                }
            }

            // Try to decode generic SwitchBot status payload
            struct StatusEnvelope: Decodable {
                let statusCode: Int
                let message: String?
                let body: [String: AnyCodable]?
            }
            let decoder = JSONDecoder()
            if let envelope = try? decoder.decode(StatusEnvelope.self, from: data), let body = envelope.body {
                let power = (body["power"])?.value as? String
                let brightness = (body["brightness"])?.value as? Int
                let color = (body["color"])?.value as? String
                let status = DeviceStatus(power: power, brightness: brightness, color: color, raw: body)
                return status
            } else {
                // Fallback: keep raw string for debugging
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("[SwitchBot] response:", jsonString)
                }
                throw SwitchBotAPIError.invalidResponse
            }
        } catch {
            print("[SwitchBot] request error:", error)
            throw SwitchBotAPIError.requestError
        }
    }

    func updateIsTurnOnStatus(isTurnOn: Bool) async throws {
        try await FirebaseDatabaseClient.updateIsTurnOn(isTurnOn)
    }
}
