//
//  LightViewModel.swift
//  frank_lloyd_light
//
//  Created by 中山智輝 on 2026/02/14.
//
import Foundation
import SwiftUI
import CryptoKit

class LightViewModel: ObservableObject {
    @Published var isTurnOn: Bool = false
    @Published var brightness: Double = 0.8 // 0.0 ... 1.0
    @Published var color: Color = .yellow
    @Published var colorHex: String = "#FFFFFF" // 簡易的に色を文字列で保持（将来API連携向け）
    @Published var isLoading: Bool = false

    private let useCase: LightControlUseCase

    init(useCase: LightControlUseCase = DIContainer.shared.makeLightControlUseCase()) {
        self.useCase = useCase
    }

    @MainActor
    func loadStatus() async {
        self.isTurnOn = await self.useCase.executeFetch()
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
            self.isTurnOn = await self.useCase.executeFetch()
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

    func fetchDevices() async {
        let token = Bundle.main.object(forInfoDictionaryKey: "SwitchBotToken") as? String
        let secret = Bundle.main.object(forInfoDictionaryKey: "SwitchBotSecret") as? String

        print("[SwitchBot] token present:", token != nil, "secret present:", secret != nil)

        guard let token, let secret else {
            print("[SwitchBot] 認証情報が設定されていません（Info.plist の SwitchBotToken / SwitchBotSecret を確認）")
            return
        }

        let t     = String(Int(Date().timeIntervalSince1970 * 1000))
        let nonce = UUID().uuidString
        let stringToSign = token + t + nonce
        let key   = SymmetricKey(data: Data(secret.utf8))
        let signature = HMAC<SHA256>.authenticationCode(
            for: Data(stringToSign.utf8),
            using: key
        )
        let sign = Data(signature).base64EncodedString()

        var request = URLRequest(url: URL(string: "https://api.switch-bot.com/v1.1/devices")!)
        request.httpMethod = "GET"
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue(sign,  forHTTPHeaderField: "sign")
        request.setValue(t,     forHTTPHeaderField: "t")
        request.setValue(nonce, forHTTPHeaderField: "nonce")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                print("[SwitchBot] HTTP status:", http.statusCode)
                if http.statusCode == 401 {
                    print("[SwitchBot][Hint] 401 Unauthorized: トークン/シークレット/署名を再確認してください。")
                }
            }
            if let jsonString = String(data: data, encoding: .utf8) {
                print("[SwitchBot] response:", jsonString)
            }
        } catch {
            print("[SwitchBot] request error:", error)
        }
    }
}

