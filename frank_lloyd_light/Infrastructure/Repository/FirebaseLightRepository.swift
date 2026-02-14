//
//  FirebaseLightRepository.swift
//  frank_lloyd_light
//
//  Created by 中山智輝 on 2026/02/14.
//

struct FirebaseLightRepository: LightRepository {
    func fetchIsTurnOnStatus() async -> Bool {
        await FirebaseDatabaseClient.fetchIsTurnOnStatus()
    }

    func updateIsTurnOnStatus(isTurnOn: Bool) async throws {
        try await FirebaseDatabaseClient.updateIsTurnOn(isTurnOn)
    }
}
