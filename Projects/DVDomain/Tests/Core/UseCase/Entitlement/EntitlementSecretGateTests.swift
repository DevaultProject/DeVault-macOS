// Copyright © 2026 Devault. All rights reserved

import Foundation
import Testing

@testable import DVDomain

@Suite("EntitlementUseCase+SecretGate")
struct EntitlementSecretGateTests {

    @Test("생성이 허용되면 통과한다")
    func createPassesWhenAllowed() async throws {
        try await StubEntitlementUseCase(canCreateSecret: true).ensureCanCreateSecret()
    }

    @Test("생성이 막히면 limitReached를 던진다")
    func createThrowsLimitReachedWhenBlocked() async {
        await #expect(throws: EntitlementError.limitReached) {
            try await StubEntitlementUseCase(canCreateSecret: false).ensureCanCreateSecret()
        }
    }

    @Test("Import가 허용되면 통과하고 개수를 그대로 넘긴다")
    func importPassesCountWhenAllowed() async throws {
        let stub = StubEntitlementUseCase(canImportSecrets: true)

        try await stub.ensureCanImportSecrets(count: 3)

        #expect(stub.lastImportCount == 3)
    }

    @Test("Import가 막히면 limitReached를 던진다")
    func importThrowsLimitReachedWhenBlocked() async {
        await #expect(throws: EntitlementError.limitReached) {
            try await StubEntitlementUseCase(canImportSecrets: false).ensureCanImportSecrets(count: 1)
        }
    }

    // 판정 실패는 게이트 차단이 아니다 — limitReached로 오면 호출부가 저장소 오류에 페이월을 띄운다.
    @Test("판정이 저장소 오류로 실패하면 SecretUseCaseError로 매핑하고 limitReached로 접지 않는다")
    func judgementFailureIsMappedNotGate() async {
        let stub = StubEntitlementUseCase()
        stub.judgementError = SecretRepositoryError.persistenceFailed

        await #expect(throws: SecretUseCaseError.repositoryFailure(.persistenceFailed)) {
            try await stub.ensureCanCreateSecret()
        }
        await #expect(throws: SecretUseCaseError.repositoryFailure(.persistenceFailed)) {
            try await stub.ensureCanImportSecrets(count: 1)
        }
    }
}
