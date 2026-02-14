import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = LightViewModel()

    var body: some View {
        ZStack {
            // 背景色を状態に合わせて変更
            (self.viewModel.isTurnOn ? Color.yellow.opacity(0.2) : Color.black.opacity(0.05))
                .ignoresSafeArea()

            VStack(spacing: 40) {
                // 1. 照明の状態表示部分
                VStack {
                    Image(systemName: self.viewModel.isTurnOn ? "lightbulb.fill" : "lightbulb")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(self.viewModel.isTurnOn ? .yellow : .gray)
                        .shadow(color: self.viewModel.isTurnOn ? .yellow : .clear, radius: 20)

                    Text(self.viewModel.isTurnOn ? "ライトは点灯中" : "ライトは消灯中")
                        .font(.headline)
                        .padding(.top)
                }

                // 2. 切り替えスイッチ部分
                ToggleView(isOn: self.viewModel.isTurnOn) {
                    Task {
                        await self.viewModel.toggle()
                    }
                }
            }
        }
        .onAppear {
            Task {
                await self.viewModel.loadStatus()
            }
        }
        .animation(.default, value: self.viewModel.isTurnOn) // 状態変化にアニメーションを付与
    }
}

struct ToggleView: View {
    let isOn: Bool
    let action: () -> Void

    var body: some View {
        Button(action: self.action) {
            HStack {
                Text(self.isOn ? "OFFにする" : "ONにする")
                    .fontWeight(.bold)

                Image(systemName: self.isOn ? "power.circle.fill" : "power.circle")
                    .font(.title)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 24)
            .background(self.isOn ? Color.red.opacity(0.8) : Color.blue.opacity(0.8))
            .foregroundColor(.white)
            .cornerRadius(30)
            .shadow(radius: 5)
        }
    }
}

#Preview {
    ContentView()
}
