// Copyright © 2026 Devault. All rights reserved

import Foundation
import Testing

@testable import DVDomain

@Suite("DeleteSecretUseCaseImpl — 복구 한도 게이트")
struct DeleteSecretUseCaseEntitlementGuardTests {

    private func makeSUT(
        _ entitlement: StubEntitlementUseCase
    ) -> (DeleteSecretUseCaseImpl, InMemorySecretRepository, Secret) {
        let repo = InMemorySecretRepository()
        let trashed = SecretFixture.make(deletedAt: SecretFixture.fixedDate)
        repo.seed(trashed)
        let sut = DeleteSecretUseCaseImpl(repository: repo, entitlementUseCase: entitlement)
        return (sut, repo, trashed)
    }

    @Test("자리가 없으면 복구를 거부하고 저장소를 건드리지 않는다")
    func rejectsRestoreWhenLimitReached() async throws {
        let (sut, repo, trashed) = makeSUT(StubEntitlementUseCase(canCreateSecret: false))

        await #expect(throws: EntitlementError.limitReached) {
            try await sut.restore(id: trashed.id)
        }
        #expect(repo.patchCount == 0)
    }

    @Test("자리가 있으면 복구한다")
    func allowsRestoreWhenUnderLimit() async throws {
        let (sut, _, trashed) = makeSUT(StubEntitlementUseCase(canCreateSecret: true))

        let restored = try await sut.restore(id: trashed.id)

        #expect(restored.deletedAt == nil)
    }

    @Test("판정이 실패하면 도메인 오류로 접는다 — 저장소 고장은 페이월로 해결되지 않는다")
    func mapsJudgementFailureToDomainError() async throws {
        let entitlement = StubEntitlementUseCase()
        entitlement.judgementError = SecretRepositoryError.persistenceFailed
        let (sut, repo, trashed) = makeSUT(entitlement)

        await #expect(throws: SecretUseCaseError.repositoryFailure(.persistenceFailed)) {
            try await sut.restore(id: trashed.id)
        }
        #expect(repo.patchCount == 0)
    }

    @Test("삭제 경로는 한도 판정을 묻지 않는다 — 개수를 줄이는 동작이다")
    func deletePathsSkipJudgement() async throws {
        let entitlement = StubEntitlementUseCase(canCreateSecret: false)
        let (sut, _, trashed) = makeSUT(entitlement)

        _ = try await sut.softDelete(id: trashed.id)
        try await sut.permanentlyDelete(id: trashed.id)

        #expect(entitlement.canCreateSecretCallCount == 0)
    }
}
