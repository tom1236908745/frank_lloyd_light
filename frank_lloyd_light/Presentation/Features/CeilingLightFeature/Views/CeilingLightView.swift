//
//  CeilingLightView.swift
//  frank_lloyd_light
//
//  Created on 2026/03/29.
//

import SwiftUI

struct CeilingLightView: View {
    let device: Device

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "light.ceiling")
                .resizable()
                .scaledToFit()
                .frame(width: 100, height: 100)
                .foregroundStyle(.secondary)

            Text("このデバイスは未対応です")
                .font(.headline)
                .foregroundStyle(.secondary)

            Text("シーリングライトの操作機能は\n近日対応予定です")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
    }
}
