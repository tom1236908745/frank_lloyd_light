//
//  LightControlUseCase.swift
//  frank_lloyd_light
//
//  Created by 中山智輝 on 2026/02/14.
//

enum LightControlUsecaseError: Error {
    case fetchFailed
}

struct LightControlUseCase {
    private let repository: LightRepository

    init(repository: LightRepository) {
        self.repository = repository
        print("[LightControlUseCase] init with repository: \(type(of: repository))")
    }

    func executeFetch() async throws-> DeviceStatus {
        print("[LightControlUseCase] executeFetch called")
        do {
            let result = try await self.repository.fetchIsTurnOnStatus()
            print("[LightControlUseCase] executeFetch result: \(result)")
            return result
        } catch {
            print("[LightControlUseCase] executeFetch error")
            throw LightControlUsecaseError.fetchFailed
        }
    }

    func executeUpdate(isTurnOn: Bool) async throws {
        print("[LightControlUseCase] executeUpdate called with isTurnOn: \(isTurnOn)")
        try await self.repository.updateIsTurnOnStatus(isTurnOn: isTurnOn)
        print("[LightControlUseCase] executeUpdate completed")
    }
}
