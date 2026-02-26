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
    
    var lightRepositoryProvider: () -> LightRepositoryProtocol
    
    
    private init(
        lightRepositoryProvider: @escaping () -> LightRepositoryProtocol = { LightRepository() }
    ) {
        self.lightRepositoryProvider = lightRepositoryProvider
    }

    /// --- UseCases ---
    /// Repository を UseCase に注入して作成
    func makeLightControlUseCase() -> LightControlUseCase {
        let repository = lightRepositoryProvider()
        return LightControlUseCase(repository: repository)
    }
}
