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
        print("[LightControlUseCase] init with repository: \(type(of: repository))")
    }

    func executeFetch() async throws-> DeviceStatus {
        print("[LightControlUseCase] executeFetch called")
        let result = try await self.repository.fetchIsTurnOnStatus()
        print("[LightControlUseCase] executeFetch result: \(result)")
        return result
    }

    func executeUpdateIsTurnOn(isTurnOn: Bool) async throws {
        print("[LightControlUseCase] executeUpdateIsTurnOn called with isTurnOn: \(isTurnOn)")
        try await self.repository.updateIsTurnOnStatus(isTurnOn: isTurnOn)
    }
    
    func executeUpdateDeviceStatus(command: String, parameter: String = "default") async throws {
        print("[LightControlUseCase] executeUpdateDeviceStatus called command: \(command), parameter: \(parameter)")
        try await self.repository.updateDeviceStatus(command: command, parameter: parameter)
    }
}
