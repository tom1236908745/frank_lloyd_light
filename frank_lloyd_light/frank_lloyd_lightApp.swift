//
//  frank_lloyd_lightApp.swift
//  frank_lloyd_light
//
//  Created by 中山智輝 on 2025/11/20.
//

import FirebaseCore
import FirebaseDatabase
import SwiftUI

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_: UIApplication,
                     didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        FirebaseApp.configure()

        return true
    }
}

@main
struct FrankLloydLightApp: App {
    /// register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    /// あとでデータベースを参照する際に使用する
    var ref: DatabaseReference {
        Database.database().reference()
    }

    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
        }
    }
}

