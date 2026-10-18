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
                content: .custom(CustomPayload(value: "hello world")),
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

    @Test("틀린 비밀번호로 Import하면 invalidPassword를 던진다")
    func failsWithInvalidPassword() throws {
        let data = try service.export(payload: payload, password: "correct horse", expiresAt: nil)

        #expect(throws: DevaultImportError.invalidPassword) {
            try service.import(data: data, password: "battery staple")
        }
    }

    @Test("ciphertext가 변조되면 invalidPassword를 던진다")
    func failsWhenCiphertextTampered() throws {
        var data = try service.export(payload: payload, password: "correct horse", expiresAt: nil)
        data[data.index(before: data.endIndex)] ^= 0xFF

        #expect(throws: DevaultImportError.invalidPassword) {
            try service.import(data: data, password: "correct horse")
        }
    }

    @Test("salt가 변조되면 유도되는 키가 달라져 invalidPassword를 던진다")
    func failsWhenSaltTampered() throws {
        var data = try service.export(payload: payload, password: "correct horse", expiresAt: nil)
        data[data.startIndex + 17] ^= 0xFF // salt 영역 첫 바이트 — Argon2 입력이라 키 자체가 달라진다

        #expect(throws: DevaultImportError.invalidPassword) {
            try service.import(data: data, password: "correct horse")
        }
    }

    @Test("헤더(AAD 전용 영역)가 변조되면 invalidPassword를 던진다 — G7 검증")
    func failsWhenAADOnlyRegionTampered() throws {
        var data = try service.export(payload: payload, password: "correct horse", expiresAt: nil)
        data[data.startIndex + 9] ^= 0x7F // expiresAt 상위 바이트 — AAD에만 있고 키에는 영향 없음

        #expect(throws: DevaultImportError.invalidPassword) {
            try service.import(data: data, password: "correct horse")
        }
    }

    @Test("export마다 salt가 다르다")
    func generatesFreshSaltEachExport() throws {
        let a = try service.export(payload: payload, password: "correct horse", expiresAt: nil)
        let b = try service.export(payload: payload, password: "correct horse", expiresAt: nil)
        let saltRangeA = (a.startIndex + 17)..<(a.startIndex + 33)
        let saltRangeB = (b.startIndex + 17)..<(b.startIndex + 33)

        #expect(a[saltRangeA] != b[saltRangeB])
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
