//
//  LightRepository.swift
//  frank_lloyd_light
//
//  Created by 中山智輝 on 2026/02/14.
//

protocol LightRepositoryProtocol {
    func fetchIsTurnOnStatus() async throws-> DeviceStatus
    func updateIsTurnOnStatus(isTurnOn: Bool) async throws
}
