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
        )
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
    func roundTrips() async throws {
        let data = try await service.export(payload: payload, password: "correct horse", expiresAt: nil)
        let imported = try await service.import(data: data, password: "correct horse")
        #expect(imported == payload)
    }

    @Test("틀린 비밀번호로 Import하면 invalidPassword를 던진다")
    func failsWithInvalidPassword() async throws {
        let data = try await service.export(payload: payload, password: "correct horse", expiresAt: nil)

        await #expect(throws: DevaultImportError.invalidPassword) {
            try await service.import(data: data, password: "battery staple")
        }
    }

    @Test("ciphertext가 변조되면 invalidPassword를 던진다")
    func failsWhenCiphertextTampered() async throws {
        var data = try await service.export(payload: payload, password: "correct horse", expiresAt: nil)
        data[data.index(before: data.endIndex)] ^= 0xFF

        await #expect(throws: DevaultImportError.invalidPassword) {
            try await service.import(data: data, password: "correct horse")
        }
    }

    @Test("salt가 변조되면 유도되는 키가 달라져 invalidPassword를 던진다")
    func failsWhenSaltTampered() async throws {
        var data = try await service.export(payload: payload, password: "correct horse", expiresAt: nil)
        data[data.startIndex + 17] ^= 0xFF // salt 영역 첫 바이트 — Argon2 입력이라 키 자체가 달라진다

        await #expect(throws: DevaultImportError.invalidPassword) {
            try await service.import(data: data, password: "correct horse")
        }
    }

    @Test("헤더(AAD 전용 영역)가 변조되면 invalidPassword를 던진다 — G7 검증")
    func failsWhenAADOnlyRegionTampered() async throws {
        var data = try await service.export(payload: payload, password: "correct horse", expiresAt: nil)
        data[data.startIndex + 9] ^= 0x7F // expiresAt 상위 바이트 — AAD에만 있고 키에는 영향 없음

        await #expect(throws: DevaultImportError.invalidPassword) {
            try await service.import(data: data, password: "correct horse")
        }
    }

    @Test("export마다 salt가 다르다")
    func generatesFreshSaltEachExport() async throws {
        let a = try await service.export(payload: payload, password: "correct horse", expiresAt: nil)
        let b = try await service.export(payload: payload, password: "correct horse", expiresAt: nil)
        let saltRangeA = (a.startIndex + 17)..<(a.startIndex + 33)
        let saltRangeB = (b.startIndex + 17)..<(b.startIndex + 33)

        #expect(a[saltRangeA] != b[saltRangeB])
    }

    @Test("주입한 현재 시각이 만료 시각보다 미래면 expired를 던진다")
    func failsWhenExpiredAtInjectedTime() async throws {
        let expiresAt = Date(timeIntervalSince1970: 1_000_000_000)
        let data = try await service.export(payload: payload, password: "correct horse", expiresAt: expiresAt)

        let laterService = DevaultContainerServiceImpl(
            passwordKeyDerivationService: PasswordKeyDerivationServiceImpl(
                memoryCostKiB: 8 * 1024, timeCost: 1, parallelism: 1
            ),
            dateProvider: { Date(timeIntervalSince1970: 2_000_000_000) }
        )

        await #expect(throws: DevaultImportError.expired) {
            try await laterService.import(data: data, password: "correct horse")
        }
    }

    @Test("주입한 현재 시각이 만료 시각보다 과거면 expired를 던지지 않는다")
    func doesNotThrowExpiredBeforeInjectedTime() async throws {
        let expiresAt = Date(timeIntervalSince1970: 2_000_000_000)
        let data = try await service.export(payload: payload, password: "correct horse", expiresAt: expiresAt)

        let earlierService = DevaultContainerServiceImpl(
            passwordKeyDerivationService: PasswordKeyDerivationServiceImpl(
                memoryCostKiB: 8 * 1024, timeCost: 1, parallelism: 1
            ),
            dateProvider: { Date(timeIntervalSince1970: 1_000_000_000) }
        )

        let imported = try await earlierService.import(data: data, password: "correct horse")
        #expect(imported == payload)
    }
}
