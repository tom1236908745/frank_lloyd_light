//
//  LightControlView.swift
//  frank_lloyd_light
//
//  Created on 2026/03/29.
//

import SwiftUI

struct LightControlView: View {
    let device: Device
    @StateObject private var viewModel: LightViewModel
    @State private var brightnessDebounceTask: Task<Void, Never>? = nil
    @State private var colorDebounceTask: Task<Void, Never>? = nil
    
    init(device: Device) {
        self.device = device
        self._viewModel = StateObject(wrappedValue: LightViewModel(deviceId: device.id))
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 背景色を状態に合わせて変更
            (self.viewModel.isTurnOn ? self.viewModel.color.opacity(0.1 + 0.4 * self.viewModel.brightness) : Color.black.opacity(0.05))
                .ignoresSafeArea()

            // コンテンツ本体（ボタンに被らないよう下に余白）
            VStack(spacing: 24) {
                // 1. 照明の状態表示部分
                VStack {
                    Image(systemName: self.viewModel.isTurnOn ? "lightbulb.fill" : "lightbulb")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(self.viewModel.isTurnOn ? self.viewModel.color.opacity(0.6 + 0.4 * self.viewModel.brightness) : .gray)
                        .shadow(color: self.viewModel.isTurnOn ? self.viewModel.color.opacity(self.viewModel.brightness) : .clear, radius: 10 + 20 * self.viewModel.brightness)
                }

                // 2. 明るさと色の調整
                if self.viewModel.isTurnOn {
                VStack(alignment: .leading, spacing: 16) {
                    // 明るさ
                    VStack(alignment: .leading) {
                        Text("明るさ")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            Image(systemName: "sun.min.fill")
                            Slider(value: Binding(
                                get: { self.viewModel.brightness },
                                set: { newValue in
                                    // 即時にUI状態を更新
                                    Task { await self.viewModel.updateBrightness(newValue) }
                                    // 連続操作時の過剰リクエストを避けるためデバウンス
                                    brightnessDebounceTask?.cancel()
                                    brightnessDebounceTask = Task { [newValue] in
                                        do {
                                            try await Task.sleep(nanoseconds: 250_000_000) // 250ms
                                            try Task.checkCancellation()
                                            let percent = Int(newValue * 100)
                                            try await self.viewModel.controlColorBulb(
                                                command: "setBrightness",
                                                parameter: "\(percent)"
                                            )
                                        } catch is CancellationError {
                                            // キャンセル時は何もしない
                                        } catch {
                                            print("Error setBrightness (debounced):", error)
                                        }
                                    }
                                }
                            ), in: 0.0...1.0)
                            Image(systemName: "sun.max.fill")
                            Text("\(Int(self.viewModel.brightness * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 36, alignment: .trailing)
                        }
                    }

                    // 色
                    VStack(alignment: .leading, spacing: 8) {
                        Text("色")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ColorGridPicker(
                            selectedColor: Binding(
                                get: { self.viewModel.color },
                                set: { newColor in
                                    // 即時にUI状態を更新
                                    Task { await self.viewModel.updateColor(newColor) }
                                    // デバウンスでリクエストを間引く
                                    colorDebounceTask?.cancel()
                                    colorDebounceTask = Task { [newColor] in
                                        do {
                                            try await Task.sleep(nanoseconds: 250_000_000) // 250ms
                                            try Task.checkCancellation()
                                            let ui = UIColor(newColor)
                                            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                                            ui.getRed(&r, green: &g, blue: &b, alpha: &a)
                                            let R = Int(round(r * 255))
                                            let G = Int(round(g * 255))
                                            let B = Int(round(b * 255))
                                            try await self.viewModel.controlColorBulb(
                                                command: "setColor",
                                                parameter: "\(R):\(G):\(B)"
                                            )
                                        } catch is CancellationError {
                                            // キャンセル時は何もしない
                                        } catch {
                                            print("Error setColor (debounced):", error)
                                        }
                                    }
                                }
                            )
                        )
                    }
                }
                .padding(.horizontal)
                .transition(.opacity)
                } // end if isTurnOn
            }
            // ボタン分の余白を下に確保
            .padding(.top, 100)
            .padding(.bottom, 120)
            .frame(maxHeight: .infinity, alignment: .top)

            // 3. 切り替えスイッチ部分（画面下部に固定）
            ToggleView(isOn: self.viewModel.isTurnOn, isLoading: self.viewModel.isLoading) {
                Task {
                    await self.viewModel.toggleUIOnly()
                    do {
                        try await self.viewModel.controlColorBulb(
                            command: self.viewModel.isTurnOn ? "turnOn" : "turnOff",
                            parameter: "default",
                        )
                    } catch {
                        print("Error:", error)
                    }
                }
            }
            .padding(.bottom, 48)
        }
        .navigationTitle(device.name)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            Task {
                await self.viewModel.loadStatus()
                try await self.viewModel.fetchDeviceStatus()
            }
        }
        .animation(.easeInOut(duration: 0.4), value: self.viewModel.isTurnOn) // 状態変化にアニメーションを付与
    }
}

// MARK: - Color Helpers

extension Color {
    /// HSB 成分を (hue, saturation, brightness) のタプルで返す
    var hsb: (hue: Double, saturation: Double, brightness: Double) {
        let ui = UIColor(self)
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (Double(h), Double(s), Double(b))
    }

    /// HSB から Color を生成
    static func fromHSB(hue: Double, saturation: Double, brightness: Double) -> Color {
        Color(hue: hue, saturation: saturation, brightness: brightness)
    }
}

// MARK: - HueSlider（グラデーション背景の色相スライダー）

struct HueSlider: View {
    @Binding var hue: Double

    private let gradient = LinearGradient(
        colors: stride(from: 0.0, through: 1.0, by: 0.05).map {
            Color(hue: $0, saturation: 1, brightness: 1)
        },
        startPoint: .leading,
        endPoint: .trailing
    )

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(gradient)
                    .frame(height: 20)

                // つまみ
                Circle()
                    .fill(Color(hue: hue, saturation: 1, brightness: 1))
                    .frame(width: 28, height: 28)
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                    .shadow(radius: 3)
                    .offset(x: hue * (geo.size.width - 28))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let ratio = value.location.x / geo.size.width
                                hue = min(max(ratio, 0), 1)
                            }
                    )
            }
        }
        .frame(height: 28)
    }
}

// MARK: - SaturationSlider（グラデーション背景の彩度スライダー）

struct SaturationSlider: View {
    @Binding var saturation: Double
    let hue: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hue: hue, saturation: 0, brightness: 1),
                                Color(hue: hue, saturation: 1, brightness: 1)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 20)

                // つまみ
                Circle()
                    .fill(Color(hue: hue, saturation: saturation, brightness: 1))
                    .frame(width: 28, height: 28)
                    .overlay(Circle().strokeBorder(Color.white, lineWidth: 2))
                    .shadow(radius: 3)
                    .offset(x: saturation * (geo.size.width - 28))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let ratio = value.location.x / geo.size.width
                                saturation = min(max(ratio, 0), 1)
                            }
                    )
            }
        }
        .frame(height: 28)
    }
}

// MARK: - ColorGridPicker

struct ColorGridPicker: View {
    @Binding var selectedColor: Color

    // プリセットの「色相」ベース（彩度・明度はスライダーで調整）
    private let presetHues: [(name: String, hue: Double)] = [
        ("赤",       0.00),
        ("オレンジ", 0.07),
        ("電球色",   0.10),
        ("黄",       0.17),
        ("黄緑",     0.25),
        ("緑",       0.33),
        ("シアン",   0.50),
        ("空色",     0.57),
        ("青",       0.65),
        ("紫",       0.75),
        ("ピンク",   0.87),
        ("赤紫",     0.93),
    ]

    // スライダー用の内部状態（HSB）
    @State private var hue: Double = 0.15
    @State private var saturation: Double = 1.0

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 6)

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // ── 色のバリエーション（色相）スライダー ──
            VStack(alignment: .leading, spacing: 6) {
                Text("色相")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HueSlider(hue: $hue)
                    .onChange(of: hue) { _, _ in applySliders() }
            }

            // ── 彩度スライダー ──
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("彩度")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(saturation * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                SaturationSlider(saturation: $saturation, hue: hue)
                    .onChange(of: saturation) { _, _ in applySliders() }
            }

            // ── プリセットカラーグリッド ──
            Spacer().frame(height: 8)
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(presetHues, id: \.name) { preset in
                    let presetColor = Color(hue: preset.hue, saturation: 1.0, brightness: 1.0)
                    let isSelected = abs(selectedColor.hsb.hue - preset.hue) < 0.01
                    Circle()
                        .fill(presetColor)
                        .frame(width: 40, height: 40)
                        .padding(isSelected ? 3 : 0)
                        .background(
                            Circle().fill(isSelected ? Color.white : Color.clear)
                        )
                        .shadow(color: presetColor.opacity(0.6), radius: isSelected ? 6 : 2)
                        .scaleEffect(isSelected ? 1.15 : 1.0)
                        .animation(.spring(duration: 0.2), value: isSelected)
                        .onTapGesture {
                            hue = preset.hue
                            selectedColor = Color(hue: preset.hue, saturation: saturation, brightness: 1.0)
                        }
                        .accessibilityLabel(preset.name)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
        }
        .onAppear {
            // 初期表示時に selectedColor から HSB を復元
            let hsb = selectedColor.hsb
            hue = hsb.hue
            saturation = hsb.saturation
        }
    }

    // スライダー変更時に selectedColor を更新
    private func applySliders() {
        selectedColor = Color(hue: hue, saturation: saturation, brightness: 1.0)
    }
}

struct ToggleView: View {
    let isOn: Bool
    let isLoading: Bool
    let action: () -> Void
    
    

    var body: some View {
        Button(action: self.action) {
            HStack {
                if self.isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text(self.isOn ? "OFFにする" : "ONにする")
                        .fontWeight(.bold)

                    Image(systemName: self.isOn ? "power.circle.fill" : "power.circle")
                        .font(.title)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(self.isOn ? Color.gray.opacity(0.55) : Color(hue: 0.08, saturation: 0.85, brightness: 0.95).opacity(0.9))
            .foregroundColor(.white)
            .cornerRadius(30)
            .shadow(radius: 5)
        }
        .disabled(self.isLoading)
    }
}

#Preview {
    NavigationView {
        LightControlView(device: Device(id: "94A99077E00A", name: "リビングの照明", type: .colorBulb))
    }
}
