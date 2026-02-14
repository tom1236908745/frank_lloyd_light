//
//  FirebaseDatabaseClient.swift
//  frank_lloyd_light
//
//  Created by 中山智輝 on 2026/02/14.
//

import FirebaseDatabase

struct FirebaseDatabaseClient {
    // ルート参照・計算プロパティ
    static var rootRef: DatabaseReference {
        Database.database().reference()
    }
    
    // isTurnOn の状態を参照
    static func fetchIsTurnOnStatus() async -> Bool {
        // Continuation を使用することで、Firebase の値を待機
        return await withCheckedContinuation { continuation in
            rootRef.child("isTurnOn").observeSingleEvent(of: .value) { snapshot in
                let status = snapshot.value as? Bool ?? false
                continuation.resume(returning: status)
            }
        }
    }
    
    // TODO: isTurnOn の状態を更新するためのロジックを実装
    static func updateIsTurnOn(_ isTurnOn: Bool) async throws {
        try await rootRef.child("isTurnOn").setValue(isTurnOn)
    }
}
