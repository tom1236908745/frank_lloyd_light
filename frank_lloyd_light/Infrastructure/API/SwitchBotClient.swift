import Foundation
import CryptoKit

enum SwitchBotClient {
    private static let baseURL = URL(string: "https://api.switch-bot.com/v1.1")!
    
    enum SwitchBotClientError: Error {
        case missingCredentials
    }
    
    private static func getCredentials() throws -> (token: String, secret: String) {
        guard
            let tokenRaw = Bundle.main.object(forInfoDictionaryKey: "SWITCHBOT_TOKEN") as? String,
            let secretRaw = Bundle.main.object(forInfoDictionaryKey: "SWITCHBOT_SECRET") as? String
        else {
            throw SwitchBotClientError.missingCredentials
        }
        
        // Remove surrounding quotes if present
        let token = tokenRaw.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        let secret = secretRaw.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
        
        return (token, secret)
    }
    
    private static func applyAuthHeaders(_ request: inout URLRequest, token: String, secret: String) {
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
        let nonce = UUID().uuidString
        
        let stringToSign = token + timestamp + nonce
        let sign = HMACSHA256(stringToSign, key: secret)
        
        // Debug logs (do not print secret)
        let maskedToken: String = String(token.prefix(6)) + "…"
        let maskedSign: String = String(sign.prefix(10)) + "…"
        print("[SwitchBot][Auth] signVersion=1")
        print("[SwitchBot][Auth] t=", timestamp)
        print("[SwitchBot][Auth] nonce=", nonce)
        print("[SwitchBot][Auth] token=", maskedToken)
        print("[SwitchBot][Auth] sign(prefix)=", maskedSign)
        
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue(timestamp, forHTTPHeaderField: "t")
        request.setValue(nonce, forHTTPHeaderField: "nonce")
        request.setValue(sign, forHTTPHeaderField: "sign")
        request.setValue("1", forHTTPHeaderField: "signVersion")
    }
    
    static func fetchDeviceStatus(deviceId: String) async throws -> URLRequest {
        let credentials = try getCredentials()
        let url = baseURL
            .appendingPathComponent("devices")
            .appendingPathComponent(deviceId)
            .appendingPathComponent("status")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuthHeaders(&request, token: credentials.token, secret: credentials.secret)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("[SwitchBot][Request] GET", url.absoluteString)
        
        return request
    }
    
    static func updateDeviceStatus(deviceId: String, command: String, parameter: String) async throws -> URLRequest {
        let credentials = try getCredentials()
        let url = baseURL
            .appendingPathComponent("devices")
            .appendingPathComponent(deviceId)
            .appendingPathComponent("commands")
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyAuthHeaders(&request, token: credentials.token, secret: credentials.secret)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "command": command,
            "parameter": parameter,
            "commandType": "command"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        
        print("[SwitchBot][Request] POST", url.absoluteString)
        
        return request
    }
    
    private static func HMACSHA256(_ data: String, key: String) -> String {
        let keyData = Data(key.utf8)
        let messageData = Data(data.utf8)
        let symmetricKey = SymmetricKey(data: keyData)
        let signature = HMAC<SHA256>.authenticationCode(for: messageData, using: symmetricKey)
        let signatureData = Data(signature)
        return signatureData.base64EncodedString()
    }
}
