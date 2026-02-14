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
    private init() {}

    /// --- Repositories ---
    /// 戻り値は protocol型にすることで、実態を隠蔽
    private func makeLightRepository() -> LightRepository {
        FirebaseLightRepository()
    }

    /// --- UseCases ---
    /// Repository を UseCase に注入して作成
    func makeLightControlUseCase() -> LightControlUseCase {
        let repository = self.makeLightRepository()
        return LightControlUseCase(repository: repository)
    }
}
