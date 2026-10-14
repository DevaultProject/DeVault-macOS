// Copyright © 2026 Devault. All rights reserved

import DVDomain
import Foundation
import Testing

@testable import DVData

@Suite("DevaultContainerServiceImpl — 백엔드 E2E")
struct DevaultContainerServiceImplTests {

    private let service = DevaultContainerServiceImpl(
        passwordKeyDerivationService: PasswordKeyDerivationServiceImpl(
            memoryCostKiB: 8 * 1024, timeCost: 1, parallelism: 1
        ),
        cryptoService: DevaultCryptoServiceImpl()
    )

    private let payload = DevaultContainerPayload(
        projectName: "Test Project",
        secrets: [
            DevaultSecretExport(
                name: "My Secret",
                payload: .custom(CustomPayload(value: "hello world")),
                payloadSchemaVersion: CustomPayload.schemaVersion
            )
        ]
    )

    @Test("Export한 걸 같은 비밀번호로 Import하면 원본 payload가 복원된다")
    func roundTrips() throws {
        let data = try service.export(payload: payload, password: "correct horse", expiresAt: nil)
        let imported = try service.import(data: data, password: "correct horse")
        #expect(imported == payload)
    }

    @Test("틀린 비밀번호로 Import하면 wrongPassword를 던진다")
    func failsWithWrongPassword() throws {
        let data = try service.export(payload: payload, password: "correct horse", expiresAt: nil)

        #expect(throws: DevaultImportError.wrongPassword) {
            try service.import(data: data, password: "battery staple")
        }
    }

    @Test("ciphertext가 변조되면 wrongPassword를 던진다")
    func failsWhenCiphertextTampered() throws {
        var data = try service.export(payload: payload, password: "correct horse", expiresAt: nil)
        data[data.index(before: data.endIndex)] ^= 0xFF

        #expect(throws: DevaultImportError.wrongPassword) {
            try service.import(data: data, password: "correct horse")
        }
    }

    @Test("헤더(AAD 영역)가 변조되면 wrongPassword를 던진다 — G7 검증")
    func failsWhenHeaderTampered() throws {
        var data = try service.export(payload: payload, password: "correct horse", expiresAt: nil)
        data[data.startIndex + 17] ^= 0xFF // salt 영역 첫 바이트 — AAD엔 포함되지만 codec이 내용까진 검증 안 하는 지점

        #expect(throws: DevaultImportError.wrongPassword) {
            try service.import(data: data, password: "correct horse")
        }
    }

    @Test("만료된 파일은 Import 시 expired를 던진다")
    func failsWhenExpired() throws {
        let data = try service.export(
            payload: payload, password: "correct horse", expiresAt: Date(timeIntervalSinceNow: -60)
        )

        #expect(throws: DevaultImportError.expired) {
            try service.import(data: data, password: "correct horse")
        }
    }
}
