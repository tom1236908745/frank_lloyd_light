//
//  LightControlUseCase.swift
//  frank_lloyd_light
//
//  Created by 中山智輝 on 2026/02/14.
//

struct LightControlUseCase {
    private let repository: LightRepository
    
    init(repository: LightRepository) {
        self.repository = repository
    }
    
    func executeFetch() async -> Bool {
        return await repository.fetchIsTurnOnStatus()
    }
    
    func executeUpdate(isTurnOn: Bool) async throws {
        try await repository.updateIsTurnOnStatus(isTurnOn: isTurnOn)
    }
}
