//
//  LightViewModel.swift
//  frank_lloyd_light
//
//  Created by 中山智輝 on 2026/02/14.
//
import Foundation

class LightViewModel: ObservableObject {
    @Published var isTurnOn: Bool = false

    private let useCase: LightControlUseCase

    init(useCase: LightControlUseCase = DIContainer.shared.makeLightControlUseCase()) {
        self.useCase = useCase
    }

    @MainActor
    func loadStatus() async {
        self.isTurnOn = await self.useCase.executeFetch()
    }

    @MainActor
    func toggle() async {
        do {
            let nextStatus = !self.isTurnOn
            try await self.useCase.executeUpdate(isTurnOn: nextStatus)
            self.isTurnOn = nextStatus
        } catch {
            print("エラー: \(error)")
        }
    }
}
