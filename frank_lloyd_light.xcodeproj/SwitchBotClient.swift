import Foundation

class SwitchBotAPI {
    private let token: String
    private let secret: String
    private let baseURL = URL(string: "https://api.switch-bot.com/v1.0")!
    
    init(token: String, secret: String) {
        self.token = token
        self.secret = secret
    }
    
    func applyAuthHeaders(_ request: inout URLRequest) {
        let timestamp = String(Int(Date().timeIntervalSince1970 * 1000))
        let nonce = UUID().uuidString
        
        let stringToSign = token + timestamp + nonce + secret
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
        let url = baseURL.appendingPathComponent("devices/status")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyAuthHeaders(&request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        print("[SwitchBot][Request] GET", url.absoluteString)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle response
        }
        task.resume()
    }
    
    func updateDeviceStatus(command: String, parameter: String) {
        let url = baseURL.appendingPathComponent("devices/commands")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        applyAuthHeaders(&request)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["command": command, "parameter": parameter]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        
        print("[SwitchBot][Request] POST", url.absoluteString)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle response
        }
        task.resume()
    }
    
    private func HMACSHA256(_ data: String, key: String) -> String {
        // HMAC SHA256 implementation
        return ""
    }
}
