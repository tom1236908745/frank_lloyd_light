//
//  CeilingLightView.swift
//  frank_lloyd_light
//
//  Created on 2026/03/29.
//

import SwiftUI

struct CeilingLightView: View {
    let device: Device
    @StateObject private var viewModel: CeilingLightViewModel
    @State private var brightnessDebounceTask: Task<Void, Never>? = nil
    @State private var colorTempDebounceTask: Task<Void, Never>? = nil

    init(device: Device) {
        self.device = device
        self._viewModel = StateObject(wrappedValue: CeilingLightViewModel(deviceId: device.id))
    }

    /// 色温度から背景色を生成（暖色 → 寒色）
    private var ambientColor: Color {
        Color(hue: 0.08 - viewModel.colorTemperature * 0.08,
              saturation: 0.6 - viewModel.colorTemperature * 0.5,
              brightness: 1.0)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // 背景
            (viewModel.isTurnOn
                ? ambientColor.opacity(0.1 + 0.4 * viewModel.brightness)
                : Color.black.opacity(0.05))
                .ignoresSafeArea()

            VStack(spacing: 24) {
                // 照明アイコン
                VStack {
                    Image(systemName: viewModel.isTurnOn ? "light.ceiling.fill" : "light.ceiling")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(viewModel.isTurnOn
                            ? ambientColor.opacity(0.6 + 0.4 * viewModel.brightness)
                            : .gray)
                        .shadow(color: viewModel.isTurnOn
                            ? ambientColor.opacity(viewModel.brightness)
                            : .clear,
                                radius: 10 + 20 * viewModel.brightness)
                }

                if viewModel.isTurnOn {
                    VStack(alignment: .leading, spacing: 16) {

                        // 明るさ
                        VStack(alignment: .leading) {
                            Text("明るさ")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 12) {
                                Image(systemName: "sun.min.fill")
                                Slider(value: Binding(
                                    get: { viewModel.brightness },
                                    set: { newValue in
                                        Task { await viewModel.updateBrightness(newValue) }
                                        brightnessDebounceTask?.cancel()
                                        brightnessDebounceTask = Task { [newValue] in
                                            do {
                                                try await Task.sleep(nanoseconds: 250_000_000)
                                                try Task.checkCancellation()
                                                let percent = Int(newValue * 100)
                                                try await viewModel.sendCommand(
                                                    command: "setBrightness",
                                                    parameter: "\(percent)"
                                                )
                                            } catch is CancellationError {
                                            } catch {
                                                print("Error setBrightness:", error)
                                            }
                                        }
                                    }
                                ), in: 0.0...1.0)
                                Image(systemName: "sun.max.fill")
                                Text("\(Int(viewModel.brightness * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(minWidth: 36, alignment: .trailing)
                            }
                        }

                        // 色温度
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("色温度")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("\(viewModel.kelvin)K")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                            ColorTemperatureSlider(value: Binding(
                                get: { viewModel.colorTemperature },
                                set: { newValue in
                                    Task { await viewModel.updateColorTemperature(newValue) }
                                    colorTempDebounceTask?.cancel()
                                    colorTempDebounceTask = Task { [newValue] in
                                        do {
                                            try await Task.sleep(nanoseconds: 250_000_000)
                                            try Task.checkCancellation()
                                            let minK = CeilingLightViewModel.minKelvin
                                            let maxK = CeilingLightViewModel.maxKelvin
                                            let kelvin = Int((minK + newValue * (maxK - minK)).rounded())
                                            try await viewModel.sendCommand(
                                                command: "setColorTemperature",
                                                parameter: "\(kelvin)"
                                            )
                                        } catch is CancellationError {
                                        } catch {
                                            print("Error setColorTemperature:", error)
                                        }
                                    }
                                }
                            ))
                            HStack {
                                Text("電球色")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text("昼光色")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .transition(.opacity)
                }
            }
            .padding(.top, 100)
            .padding(.bottom, 120)
            .frame(maxHeight: .infinity, alignment: .top)

            // ON/OFF トグル
            ToggleView(isOn: viewModel.isTurnOn, isLoading: viewModel.isLoading) {
                Task {
                    await viewModel.toggleUIOnly()
                    do {
                        try await viewModel.sendCommand(
                            command: viewModel.isTurnOn ? "turnOn" : "turnOff"
                        )
                    } catch {
                        print("Error toggle:", error)
                    }
                }
            }
            .padding(.bottom, 48)
        }
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task { await viewModel.loadStatus() }
        }
        .animation(.easeInOut(duration: 0.4), value: viewModel.isTurnOn)
    }
}

// MARK: - ColorTemperatureSlider

struct ColorTemperatureSlider: View {
    @Binding var value: Double  // 0.0(電球色 2700K) ... 1.0(昼光色 6500K)

    private let gradient = LinearGradient(
        colors: [
            Color(hue: 0.08, saturation: 0.8, brightness: 1.0),   // 電球色
            Color(hue: 0.13, saturation: 0.4, brightness: 1.0),   // 白熱色
            Color(hue: 0.00, saturation: 0.0, brightness: 1.0),   // 白
            Color(hue: 0.60, saturation: 0.15, brightness: 1.0),  // 昼光色
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(gradient)
                    .frame(height: 20)

                Circle()
                    .fill(Color(hue: 0.08 - value * 0.08,
                                saturation: 0.6 - value * 0.5,
                                brightness: 1.0))
                    .frame(width: 28, height: 28)
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                    .shadow(radius: 3)
                    .offset(x: value * (geo.size.width - 28))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                let ratio = drag.location.x / geo.size.width
                                value = min(max(ratio, 0), 1)
                            }
                    )
            }
        }
        .frame(height: 28)
    }
}
