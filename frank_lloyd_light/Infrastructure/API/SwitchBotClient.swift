import Foundation
import CryptoKit

class SwitchBotAPI {
    private let token: String
    private let secret: String
    private let deviceId: String
    private let baseURL = URL(string: "https://api.switch-bot.com/v1.1")!
    
    convenience init?() {
        guard
            let token = Bundle.main.object(forInfoDictionaryKey: "SWITCHBOT_TOKEN") as? String,
            let secret = Bundle.main.object(forInfoDictionaryKey: "SWITCHBOT_SECRET") as? String,
            let deviceId = Bundle.main.object(forInfoDictionaryKey: "SWITCHBOT_DEVICE_ID") as? String
        else {
            return nil
        }
        self.init(token: token, secret: secret, deviceId: deviceId)
    }
    
    init(token: String, secret: String, deviceId: String) {
        self.token = token
        self.secret = secret
        self.deviceId = deviceId
    }
    
    func applyAuthHeaders(_ request: inout URLRequest) {
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
        let nonce = UUID().uuidString
        
        let stringToSign = token + timestamp + nonce
        let sign = HMACSHA256(stringToSign, key: secret)
        
        // Debug logs (do not print secret)
        let maskedToken: String = token.prefix(6) + "…"
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
    
    func fetchDeviceStatus() {
        let url = baseURL.appendingPathComponent("devices").appendingPathComponent(deviceId).appendingPathComponent("status")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuthHeaders(&request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("[SwitchBot][Request] GET", url.absoluteString)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[SwitchBot][Response] Error:", error.localizedDescription)
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                print("[SwitchBot][Response] HTTP Status:", httpResponse.statusCode)
            }
            if let data = data, let bodyString = String(data: data, encoding: .utf8) {
                print("[SwitchBot][Response] Body:")
                print(bodyString)
            }
        }
        task.resume()
    }
    
    func updateDeviceStatus(command: String, parameter: String) {
        let url = baseURL.appendingPathComponent("devices").appendingPathComponent(deviceId).appendingPathComponent("commands")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyAuthHeaders(&request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "command": command,
            "parameter": parameter,
            "commandType": "command"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        
        print("[SwitchBot][Request] POST", url.absoluteString)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("[SwitchBot][Response] Error:", error.localizedDescription)
                return
            }
            if let httpResponse = response as? HTTPURLResponse {
                print("[SwitchBot][Response] HTTP Status:", httpResponse.statusCode)
            }
            if let data = data, let bodyString = String(data: data, encoding: .utf8) {
                print("[SwitchBot][Response] Body:")
                print(bodyString)
            }
        }
        task.resume()
    }
    
    private func HMACSHA256(_ data: String, key: String) -> String {
        let keyData = Data(key.utf8)
        let messageData = Data(data.utf8)
        let symmetricKey = SymmetricKey(data: keyData)
        let signature = HMAC<SHA256>.authenticationCode(for: messageData, using: symmetricKey)
        let signatureData = Data(signature)
        return signatureData.base64EncodedString()
    }
}
