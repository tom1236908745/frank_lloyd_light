//
//  FirebaseDatabaseClient.swift
//  frank_lloyd_light
//
//  Created by 中山智輝 on 2026/02/14.
//

import FirebaseDatabase

enum FirebaseDatabaseClient {
    /// ルート参照・計算プロパティ
    static var rootRef: DatabaseReference {
        Database.database().reference()
    }

    /// isTurnOn の状態を参照
    static func fetchIsTurnOnStatus() async -> Bool {
        // Continuation を使用することで、Firebase の値を待機
        await withCheckedContinuation { continuation in
            self.rootRef.child("isTurnOn").observeSingleEvent(of: .value) { snapshot in
                let status = snapshot.value as? Bool ?? false
                continuation.resume(returning: status)
            }
        }
    }


    static func updateIsTurnOn(_ isTurnOn: Bool) async throws {
        try await self.rootRef.child("isTurnOn").setValue(isTurnOn)
    }
}
