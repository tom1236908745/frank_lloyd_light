//
//  DeviceListView.swift
//  frank_lloyd_light
//
//  Created on 2026/03/29.
//

import SwiftUI

struct DeviceListView: View {
    @StateObject private var viewModel = DeviceListViewModel()
    @State private var showingAddDevice = false

    @ViewBuilder
    private func destinationView(for device: Device) -> some View {
        switch device.type {
        case .ceilingLightPro:
            CeilingLightView(device: device)
        default:
            LightControlView(device: device)
        }
    }

    var body: some View {
        List {
            ForEach(viewModel.devices) { device in
                NavigationLink(destination: destinationView(for: device)) {
                    DeviceRow(device: device)
                }
            }
            .onDelete(perform: viewModel.removeDevice)
        }
        .navigationTitle("デバイス一覧")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddDevice = true
                } label: {
                    Image(systemName: "plus")
                }
            }

            ToolbarItem(placement: .navigationBarLeading) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingAddDevice) {
            AddDeviceView(viewModel: viewModel)
        }
        .onAppear {
            viewModel.loadDevices()
        }
    }
}

// MARK: - Device Row

struct DeviceRow: View {
    let device: Device

    var body: some View {
        HStack(spacing: 16) {
            // デバイスタイプに応じたアイコン
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(iconColor)
                .frame(width: 40, height: 40)
                .background(iconColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(device.name)
                    .font(.headline)

                Text(device.type.rawValue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
}
        .padding(.vertical, 8)
    }

    private var iconName: String {
        switch device.type {
        case .colorBulb:
            return "lightbulb.fill"
        case .ceilingLightPro:
            return "lightbulb.fill"
        case .stripLight:
            return "lightstrip.fill"
        case .plug:
            return "powerplug.fill"
        }
    }

    private var iconColor: Color {
        switch device.type {
        case .colorBulb:
            return Color(hue: 0.10, saturation: 0.85, brightness: 0.95)
        case .ceilingLightPro:
            return Color(hue: 0.10, saturation: 0.85, brightness: 0.95)
        case .stripLight:
            return Color.purple
        case .plug:
            return Color.green
        }
    }
}

// MARK: - Add Device View

struct AddDeviceView: View {
    @ObservedObject var viewModel: DeviceListViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var deviceId = ""
    @State private var deviceName = ""
    @State private var deviceType: Device.DeviceType = .colorBulb

    var body: some View {
        NavigationView {
            Form {
                Section {
                    TextField("デバイス名（例: リビングの照明）", text: $deviceName)
                } header: {
                    Text("デバイス名")
                }

                Section {
                    TextField("デバイスID", text: $deviceId)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("デバイスID")
                } footer: {
                    Text("SwitchBot アプリから取得できるデバイスIDを入力してください")
                }

                Section {
                    Picker("デバイスタイプ", selection: $deviceType) {
                        Text("カラー電球").tag(Device.DeviceType.colorBulb)
                        Text("シーリングライト").tag(Device.DeviceType.ceilingLightPro)
                        Text("LEDテープライト").tag(Device.DeviceType.stripLight)
                        Text("プラグ").tag(Device.DeviceType.plug)
                    }
                } header: {
                    Text("デバイスタイプ")
                }
            }
            .navigationTitle("デバイスを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        viewModel.addDevice(id: deviceId, name: deviceName, type: deviceType)
                        dismiss()
                    }
                    .disabled(deviceId.isEmpty || deviceName.isEmpty)
                }
            }
        }
    }
}

#Preview {
    NavigationView {
        DeviceListView()
    }
}
