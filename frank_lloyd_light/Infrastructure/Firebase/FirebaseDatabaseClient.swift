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
        Database.database(url: "https://frank-lloyd-light-default-rtdb.asia-southeast1.firebasedatabase.app").reference()
    }

    /// isTurnOn の状態を参照
    static func fetchIsTurnOnStatus() async -> Bool {
        await withCheckedContinuation { continuation in
            self.rootRef.child("isTurnOn").getData { error, snapshot in
                if let error = error {
                    print("[FirebaseDatabaseClient] fetchIsTurnOnStatus error: \(error.localizedDescription)")
                    continuation.resume(returning: false) // 失敗時は false
                    return
                }
                guard let snapshot else {
                    continuation.resume(returning: false)
                    return
                }
                if let bool = snapshot.value as? Bool {
                    continuation.resume(returning: bool)
                } else if let num = snapshot.value as? NSNumber {
                    continuation.resume(returning: num.boolValue)
                } else {
                    continuation.resume(returning: false)
                }
            }
        }
    }


    static func updateIsTurnOn(_ isTurnOn: Bool) async throws {
        print("[FirebaseDatabaseClient] updateIsTurnOn called with \(isTurnOn)")
        try await self.rootRef.child("isTurnOn").setValue(isTurnOn)
        print("[FirebaseDatabaseClient] updateIsTurnOn finished")
    }
}

