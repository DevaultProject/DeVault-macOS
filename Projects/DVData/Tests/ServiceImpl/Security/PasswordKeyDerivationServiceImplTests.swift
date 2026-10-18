// Copyright © 2026 Devault. All rights reserved

import DVDomain
import Foundation
import Testing

@testable import DVData

@Suite("PasswordKeyDerivationServiceImpl")
struct PasswordKeyDerivationServiceImplTests {

    // 비용 파라미터와 무관한 단언(결정성·민감도·길이)은 싼 파라미터로 — 프로덕션 기본값은 matchesPinnedVector에서만 쓴다.
    private let service = PasswordKeyDerivationServiceImpl(memoryCostKiB: 8 * 1024, timeCost: 1, parallelism: 1)
    private let productionService = PasswordKeyDerivationServiceImpl()
    private let salt = Data(repeating: 0xAB, count: 16)

    @Test("같은 비밀번호·salt·길이면 항상 같은 키가 나온다")
    func deterministic() async throws {
        let first = try await service.deriveKey(password: "correct horse", salt: salt, derivedKeyByteCount: 32)
        let second = try await service.deriveKey(password: "correct horse", salt: salt, derivedKeyByteCount: 32)
        #expect(first == second)
    }

    @Test("비밀번호가 다르면 다른 키가 나온다")
    func sensitiveToPassword() async throws {
        let first = try await service.deriveKey(password: "correct horse", salt: salt, derivedKeyByteCount: 32)
        let second = try await service.deriveKey(password: "battery staple", salt: salt, derivedKeyByteCount: 32)
        #expect(first != second)
    }

    @Test("salt가 다르면 다른 키가 나온다")
    func sensitiveToSalt() async throws {
        let otherSalt = Data(repeating: 0xCD, count: 16)
        let first = try await service.deriveKey(password: "correct horse", salt: salt, derivedKeyByteCount: 32)
        let second = try await service.deriveKey(password: "correct horse", salt: otherSalt, derivedKeyByteCount: 32)
        #expect(first != second)
    }

    @Test("요청한 바이트 길이만큼 키가 나온다")
    func respectsRequestedLength() async throws {
        let key16 = try await service.deriveKey(password: "correct horse", salt: salt, derivedKeyByteCount: 16)
        let key32 = try await service.deriveKey(password: "correct horse", salt: salt, derivedKeyByteCount: 32)
        #expect(key16.count == 16)
        #expect(key32.count == 32)
    }

    @Test("빈 비밀번호·짧은 salt·0 이하 길이는 invalidParameters를 던진다")
    func rejectsInvalidParameters() async {
        await #expect(throws: PasswordKeyDerivationError.invalidParameters) {
            try await service.deriveKey(password: "", salt: salt, derivedKeyByteCount: 32)
        }
        await #expect(throws: PasswordKeyDerivationError.invalidParameters) {
            try await service.deriveKey(password: "correct horse", salt: Data(repeating: 0xAB, count: 4), derivedKeyByteCount: 32)
        }
        await #expect(throws: PasswordKeyDerivationError.invalidParameters) {
            try await service.deriveKey(password: "correct horse", salt: Data(repeating: 0xAB, count: 15), derivedKeyByteCount: 32)
        }
        await #expect(throws: PasswordKeyDerivationError.invalidParameters) {
            try await service.deriveKey(password: "correct horse", salt: salt, derivedKeyByteCount: 0)
        }
        await #expect(throws: PasswordKeyDerivationError.invalidParameters) {
            try await service.deriveKey(password: "correct horse", salt: salt, derivedKeyByteCount: -1)
        }
    }

    @Test("커스텀 m/t/p 파라미터로 초기화하면 고정 벡터를 재현한다")
    func worksWithCustomCostParameters() async throws {
        let customService = PasswordKeyDerivationServiceImpl(memoryCostKiB: 8 * 1024, timeCost: 2, parallelism: 1)
        let customKey = try await customService.deriveKey(password: "correct horse", salt: salt, derivedKeyByteCount: 32)
        #expect(customKey.hexEncoded == "c723f1a4373b9540eaad1d6c0507d8eaafd14f5e4b2f83563946ae477fa7a830")
    }

    @Test("deriveKey가 고정 벡터를 재현한다 — 알고리즘·파라미터·인코딩이 바뀌면 깨진다")
    func matchesPinnedVector() async throws {
        let key = try await productionService.deriveKey(password: "correct horse", salt: salt, derivedKeyByteCount: 32)
        #expect(key.hexEncoded == "5beffef9639dd7e5b490ffb982dc22fa8cb3fe9a99f556ec72f20bc9566c88c5")
    }

    @Test("NFC·NFD로 다르게 인코딩된 같은 비밀번호도 같은 키를 유도한다")
    func normalizesUnicodeBeforeDeriving() async throws {
        let nfc = "테스트".precomposedStringWithCanonicalMapping
        let nfd = "테스트".decomposedStringWithCanonicalMapping
        #expect(Array(nfc.utf8) != Array(nfd.utf8))

        let keyFromNFC = try await service.deriveKey(password: nfc, salt: salt, derivedKeyByteCount: 32)
        let keyFromNFD = try await service.deriveKey(password: nfd, salt: salt, derivedKeyByteCount: 32)
        #expect(keyFromNFC == keyFromNFD)
    }
}

extension Data {
    fileprivate var hexEncoded: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
