// Copyright © 2026 Devault. All rights reserved

import Foundation
import Testing

@testable import DVDomain

@Suite("DeleteSecretUseCaseImpl — 복구 한도 게이트")
struct DeleteSecretUseCaseEntitlementGuardTests {

    private func makeSUT(
        entitlement: StubEntitlementUseCase
    ) -> (DeleteSecretUseCaseImpl, InMemorySecretRepository, Secret) {
        let repo = InMemorySecretRepository()
        let trashed = SecretFixture.make(deletedAt: SecretFixture.fixedDate)
        repo.seed(trashed)
        let sut = DeleteSecretUseCaseImpl(repository: repo, entitlementUseCase: entitlement)
        return (sut, repo, trashed)
    }

    @Test("자리가 없으면 복구를 거부하고 저장소를 건드리지 않는다")
    func rejectsRestoreWhenLimitReached() async throws {
        let (sut, repo, trashed) = makeSUT(entitlement: StubEntitlementUseCase(canCreateSecret: false))

        await #expect(throws: EntitlementError.limitReached) {
            try await sut.restore(id: trashed.id)
        }
        #expect(repo.patchCount == 0)
    }

    @Test("자리가 있으면 복구한다")
    func allowsRestoreWhenUnderLimit() async throws {
        let (sut, _, trashed) = makeSUT(entitlement: StubEntitlementUseCase(canCreateSecret: true))

        let restored = try await sut.restore(id: trashed.id)

        #expect(restored.deletedAt == nil)
    }

    @Test("판정이 실패하면 도메인 오류로 접는다 — 저장소 고장은 페이월로 해결되지 않는다")
    func mapsJudgementFailureToDomainError() async throws {
        let repo = InMemorySecretRepository()
        let trashed = SecretFixture.make(deletedAt: SecretFixture.fixedDate)
        repo.seed(trashed)
        let entitlement = ThrowingEntitlementUseCase()
        let sut = DeleteSecretUseCaseImpl(repository: repo, entitlementUseCase: entitlement)

        do {
            _ = try await sut.restore(id: trashed.id)
            Issue.record("판정이 실패했는데 복구가 성공하면 안 된다")
        } catch is EntitlementError {
            Issue.record("판정 실패를 게이트 차단으로 내보내면 호출부가 페이월을 띄운다 — 결제로 해결되지 않는 오류다")
        } catch {
            // 도메인 오류 — 기대한 경로
        }
        #expect(repo.patchCount == 0)
    }

    @Test("삭제 경로는 한도 판정을 묻지 않는다 — 개수를 줄이는 동작이다")
    func deletePathsSkipJudgement() async throws {
        let entitlement = StubEntitlementUseCase(canCreateSecret: false)
        let (sut, _, trashed) = makeSUT(entitlement: entitlement)

        _ = try await sut.softDelete(id: trashed.id)
        try await sut.permanentlyDelete(id: trashed.id)
    }
}

/// 판정에서 저장소 오류를 던지는 스텁 — 게이트 차단과 판정 실패가 갈라지는지 보는 데 쓴다.
private final class ThrowingEntitlementUseCase: EntitlementUseCase, @unchecked Sendable {
    func current() -> Entitlement { .free }
    func stream() -> AsyncStream<Entitlement> { AsyncStream { $0.finish() } }
    func canCreateSecret() async throws -> Bool { throw SecretRepositoryError.persistenceFailed }
    func canCreateProject() async throws -> Bool { throw SecretRepositoryError.persistenceFailed }
    func canImportSecrets(count: Int) async throws -> Bool { throw SecretRepositoryError.persistenceFailed }
    func canEditSecrets() async throws -> Bool { throw SecretRepositoryError.persistenceFailed }
    func canEnableICloudSync() -> Bool { false }
    func canUseMultipleExpiryAlertDays() -> Bool { false }
}
