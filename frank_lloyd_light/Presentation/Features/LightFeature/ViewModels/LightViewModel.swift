//
//  LightViewModel.swift
//  frank_lloyd_light
//
//  Created by 中山智輝 on 2026/02/14.
//
import Foundation
import SwiftUI
import CryptoKit

extension UIColor {
    convenience init?(hex: String) {
        var str = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("#") { str.removeFirst() }
        guard str.count == 6, let value = Int(str, radix: 16) else { return nil }
        let r = CGFloat((value >> 16) & 0xFF) / 255.0
        let g = CGFloat((value >> 8) & 0xFF) / 255.0
        let b = CGFloat(value & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
    convenience init?(rgbString: String) {
        // format: "R:G:B"
        let parts = rgbString.split(separator: ":").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        let r = CGFloat(min(max(parts[0], 0), 255)) / 255.0
        let g = CGFloat(min(max(parts[1], 0), 255)) / 255.0
        let b = CGFloat(min(max(parts[2], 0), 255)) / 255.0
        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}

struct AnyCodable: Codable, Equatable {
    let value: Any
    init(_ value: Any) { self.value = value }

    static func == (lhs: AnyCodable, rhs: AnyCodable) -> Bool {
        switch (lhs.value, rhs.value) {
        case let (l as Bool,             r as Bool):             return l == r
        case let (l as Int,              r as Int):              return l == r
        case let (l as Double,           r as Double):           return l == r
        case let (l as String,           r as String):           return l == r
        case let (l as [String: AnyCodable], r as [String: AnyCodable]): return l == r
        case let (l as [AnyCodable],     r as [AnyCodable]):     return l == r
        default: return false
        }
    }
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(Bool.self) { value = v; return }
        if let v = try? container.decode(Int.self) { value = v; return }
        if let v = try? container.decode(Double.self) { value = v; return }
        if let v = try? container.decode(String.self) { value = v; return }
        if let v = try? container.decode([String: AnyCodable].self) { value = v; return }
        if let v = try? container.decode([AnyCodable].self) { value = v; return }
        throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported type")
    }
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let v as Bool: try container.encode(v)
        case let v as Int: try container.encode(v)
        case let v as Double: try container.encode(v)
        case let v as String: try container.encode(v)
        case let v as [String: AnyCodable]: try container.encode(v)
        case let v as [AnyCodable]: try container.encode(v)
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: container.codingPath, debugDescription: "Unsupported type"))
        }
    }
}

enum LightViewModelError: Error {
    case executeFetchFailed
}

class LightViewModel: ObservableObject {
    struct DeviceStatus: Codable, Equatable {
        var power: String?
        var brightness: Int?
        var color: String?
        var raw: [String: AnyCodable]
    }

    @Published var isTurnOn: Bool = false
    @Published var brightness: Double = 0.8 // 0.0 ... 1.0
    @Published var color: Color = .yellow
    @Published var colorHex: String = "#FFFFFF" // 簡易的に色を文字列で保持（将来API連携向け）
    @Published var isLoading: Bool = false
    @Published var deviceStatus: DeviceStatus? = nil

    private let useCase: LightControlUseCase

    init(useCase: LightControlUseCase = DIContainer.shared.makeLightControlUseCase()) {
        self.useCase = useCase
    }

    @MainActor
    func loadStatus() async {
        do {
            let status = try await self.useCase.executeFetch()
            self.isTurnOn = status.power == "ON"
        } catch {
            self.isLoading = false
        }
    }

    @MainActor
    func toggleUIOnly() async {
        isTurnOn.toggle()
    }

    @MainActor
    func toggle() async {
        self.isLoading = true
        let nextStatus = !self.isTurnOn
        do {
            try await self.useCase.executeUpdate(isTurnOn: nextStatus)
            
            do {
                let status = try await self.useCase.executeFetch()
                self.isTurnOn = status.power == "ON"
            } catch {
                self.isLoading = false
            }
            
            self.isLoading = false
        } catch {
            print("エラー: \(error)")
            self.isLoading = false
        }
    }

    @MainActor
    func updateBrightness(_ value: Double) async {
        self.brightness = min(max(value, 0.0), 1.0)
    }

    @MainActor
    func updateColorHex(_ hex: String) async {
        self.colorHex = hex
    }

    @MainActor
    func updateColor(_ value: Color) async {
        self.color = value
    }

    // MARK: - SwitchBot デバイス一覧取得

    func fetchDeviceStatus() async throws {
        await MainActor.run { self.isLoading = true }

        do {let status = try await self.useCase.executeFetch()
            await MainActor.run {
                // 初期値として ViewModel の操作状態にも反映
                if let p = status.power {
                    self.isTurnOn = (p.lowercased() == "on")
                }
                if let b = status.brightness {
                    self.brightness = Double(min(max(b, 0), 100)) / 100.0
                }
                if let c = status.color {
                    if let ui = UIColor(hex: c) ?? UIColor(rgbString: c) {
                        self.color = Color(ui)
                        // hex が来ないケースもあるため、可能なら hex に正規化
                        if let hexColor = Self.hexString(from: ui) {
                            self.colorHex = "#" + hexColor
                        }
                    }
                }
                self.isLoading = false
            }
        } catch {
            throw LightViewModelError.executeFetchFailed
        }
    
           
    }

    private static func hexString(from color: UIColor) -> String? {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return nil }
        let R = Int(round(r * 255))
        let G = Int(round(g * 255))
        let B = Int(round(b * 255))
        return String(format: "%02X%02X%02X", R, G, B)
    }
    
    func controlColorBulb(command: String, parameter: String = "default") async throws {
        let token = Bundle.main.object(forInfoDictionaryKey: "SwitchBotToken") as? String
        let secret = Bundle.main.object(forInfoDictionaryKey: "SwitchBotSecret") as? String
        let deviceId = Bundle.main.object(forInfoDictionaryKey: "SwitchBotDeviceId") as? String
        
        guard let deviceId else {
            print("deviceId を指定してください")
            return
        }
            
        guard let token, let secret else {
            print("[SwitchBot] 認証情報が設定されていません（Info.plist の SwitchBotToken / SwitchBotSecret を確認）")
            return
        }

        let baseUrl = "https://api.switch-bot.com/v1.1/devices/\(deviceId)/commands"
        guard let url = URL(string: baseUrl) else { return }

        let t     = String(Int(Date().timeIntervalSince1970 * 1000))
        let nonce = UUID().uuidString
        let stringToSign = token + t + nonce
        let key   = SymmetricKey(data: Data(secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(
            for: Data(stringToSign.utf8),
            using: key
        )
        let sign = Data(signature).base64EncodedString()

        // リクエスト本体
        let body: [String: Any] = [
            "commandType": "command",
            "command": command,
            "parameter": parameter
        ]
        print("comand", command)
        print("parameter", parameter)
        let jsonData = try JSONSerialization.data(withJSONObject: body, options: [])

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData

        // 必須ヘッダー
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue(sign,  forHTTPHeaderField: "sign")
        request.setValue(t,     forHTTPHeaderField: "t")
        request.setValue(nonce, forHTTPHeaderField: "nonce")
        request.setValue("application/json; charset=utf8", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await URLSession.shared.data(for: request)

        if let httpResp = response as? HTTPURLResponse {
            print("Status Code:", httpResp.statusCode)
        }
        let result = try JSONSerialization.jsonObject(with: data)
        print("Response:", result)
    }
}

