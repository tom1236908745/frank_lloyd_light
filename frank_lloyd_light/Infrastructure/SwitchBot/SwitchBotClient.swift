//
//  SwitchBotClient.swift
//  frank_lloyd_light
//

import Foundation
import CryptoKit

enum SwitchBotClient {
    private static let token: String = Bundle.main.infoDictionary?["SWITCHBOT_TOKEN"] as? String ?? ""
    private static let secret: String = Bundle.main.infoDictionary?["SWITCHBOT_SECRET"] as? String ?? ""
    private static let deviceId: String = Bundle.main.infoDictionary?["SWITCHBOT_DEVICE_ID"] as? String ?? ""

    private static let baseURL = "https://api.switch-bot.com"

    // MARK: - 署名生成

    private static func makeHeaders() -> [String: String] {
        let t = String(Int(Date().timeIntervalSince1970 * 1000))
        let nonce = UUID().uuidString
        let signStr = token + t + nonce

        let keyData = Data(secret.utf8)
        let msgData = Data(signStr.utf8)
        let signature = HMAC<SHA256>.authenticationCode(
            for: msgData,
            using: SymmetricKey(data: keyData)
        )
        let sign = Data(signature).base64EncodedString()

        return [
            "Authorization": token,
            "sign": sign,
            "nonce": nonce,
            "t": t,
            "Content-Type": "application/json; charset=utf-8",
        ]
    }

    // MARK: - デバイスステータス取得

    static func fetchDeviceStatus() async throws -> URLRequest {
        let urlString = "\(baseURL)/v1.1/devices/\(deviceId)/status"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        makeHeaders().forEach { request.setValue($1, forHTTPHeaderField: $0) }
        return request
    }

    // MARK: - デバイスコマンド送信

    static func updateDeviceStatus(command: String, parameter: String = "default") async throws -> URLRequest {
        let urlString = "\(baseURL)/v1.1/devices/\(deviceId)/commands"
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        makeHeaders().forEach { request.setValue($1, forHTTPHeaderField: $0) }

        let body: [String: Any] = [
            "command": command,
            "parameter": parameter,
            "commandType": "command",
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }
}
