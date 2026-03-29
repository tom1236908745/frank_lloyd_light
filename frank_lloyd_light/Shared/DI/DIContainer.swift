//
//  DIContainer.swift
//  frank_lloyd_light
//
//  Created by 中山智輝 on 2026/02/14.
//

import Foundation

class DIContainer {
    // どこからでも参照可
    static let shared = DIContainer()
    
    private let lightRepositoryProvider: (String) -> LightRepositoryProtocol
    
    init(
        lightRepositoryProvider: @escaping (String) -> LightRepositoryProtocol = { deviceId in LightRepository(deviceId: deviceId) }
    ) {
        self.lightRepositoryProvider = lightRepositoryProvider
    }

    /// --- UseCases ---
    /// Repository を UseCase に注入して作成
    func makeLightControlUseCase(deviceId: String) -> LightControlUseCase {
        let repository = lightRepositoryProvider(deviceId)
        return LightControlUseCase(repository: repository)
    }
}
