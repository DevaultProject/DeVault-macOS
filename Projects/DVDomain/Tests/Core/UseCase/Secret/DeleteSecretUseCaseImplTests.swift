// Copyright © 2026 Devault. All rights reserved

import Foundation
import Testing

@testable import DVDomain

@Suite("DeleteSecretUseCaseImpl")
struct DeleteSecretUseCaseImplTests {
    @Test("softDelete는 deletedAt과 updatedAt을 주입 시각으로 세팅한다")
    func softDeleteSetsDeletedAndUpdatedAt() async throws {
        let repo = InMemorySecretRepository()
        let secret = SecretFixture.make()
        repo.seed(secret)
        let fixedNow = Date(timeIntervalSince1970: 1_950_000_000)
        let sut = DeleteSecretUseCaseImpl(repository: repo, entitlementUseCase: StubEntitlementUseCase(), dateProvider: { fixedNow })

        _ = try await sut.softDelete(id: secret.id)

        #expect(repo.lastPatch?.deletedAt == .set(fixedNow))
        #expect(repo.lastPatch?.updatedAt == .set(fixedNow))
    }

    @Test("restore는 deletedAt을 nil로 만들고 updatedAt은 주입 시각으로 세팅한다")
    func restoreClearsDeletedAt() async throws {
        let repo = InMemorySecretRepository()
        let secret = SecretFixture.make()
        repo.seed(secret)
        let fixedNow = Date(timeIntervalSince1970: 1_950_000_000)
        let sut = DeleteSecretUseCaseImpl(repository: repo, entitlementUseCase: StubEntitlementUseCase(), dateProvider: { fixedNow })

        _ = try await sut.restore(id: secret.id)

        #expect(repo.lastPatch?.deletedAt == .set(nil))
        #expect(repo.lastPatch?.updatedAt == .set(fixedNow))
    }

    @Test("permanentlyDelete는 Repository의 delete를 호출한다")
    func permanentlyDeleteCallsRepositoryDelete() async throws {
        let repo = InMemorySecretRepository()
        let secret = SecretFixture.make()
        repo.seed(secret)
        let sut = DeleteSecretUseCaseImpl(repository: repo, entitlementUseCase: StubEntitlementUseCase())

        try await sut.permanentlyDelete(id: secret.id)

        #expect(repo.deleteCount == 1)
        #expect(repo.secrets[secret.id] == nil)
    }

    @Test("존재하지 않는 id에 대한 softDelete는 secretNotFound로 매핑된다")
    func softDeleteMapsSecretNotFound() async {
        let repo = InMemorySecretRepository()
        let missingID = UUID()
        let sut = DeleteSecretUseCaseImpl(repository: repo, entitlementUseCase: StubEntitlementUseCase())

        await #expect(throws: SecretUseCaseError.secretNotFound(id: missingID)) {
            _ = try await sut.softDelete(id: missingID)
        }
    }

    @Test("존재하지 않는 id에 대한 permanentlyDelete는 secretNotFound로 매핑된다")
    func permanentlyDeleteMapsSecretNotFound() async {
        let repo = InMemorySecretRepository()
        let missingID = UUID()
        let sut = DeleteSecretUseCaseImpl(repository: repo, entitlementUseCase: StubEntitlementUseCase())

        await #expect(throws: SecretUseCaseError.secretNotFound(id: missingID)) {
            try await sut.permanentlyDelete(id: missingID)
        }
    }

    // MARK: - Bulk (컬렉션 일괄)
    // 유스케이스는 "규칙(soft delete = deletedAt·updatedAt)과 대상 컬렉션"을 정하고 Repository.patchAll/deleteAll에
    // 위임한다. 어떤 항목이 컬렉션에 속하는지 필터링은 Repository 책임이라, InMemory fake도 count와 같은
    // `matches` 규칙으로 필터한다 — 그래서 비대상 항목이 안 건드려지는지까지 검증할 수 있다.

    @Test("softDeleteAll은 대상 컬렉션 전체만 소프트 삭제한다(patchAll 위임, deletedAt·updatedAt 세팅, 영구삭제 아님)")
    func softDeleteAllSoftDeletesCollection() async throws {
        let repo = InMemorySecretRepository()
        let refDate = Date(timeIntervalSince1970: 1_900_000_000)
        let expiredA = SecretFixture.make(id: UUID(), expiresAt: Date(timeIntervalSince1970: 1))
        let expiredB = SecretFixture.make(id: UUID(), expiresAt: Date(timeIntervalSince1970: 2))
        // 미래 만료 → .expired 대상 아님. 건드리면 안 된다.
        let active = SecretFixture.make(id: UUID(), expiresAt: Date(timeIntervalSince1970: 2_000_000_000))
        repo.seed(expiredA)
        repo.seed(expiredB)
        repo.seed(active)
        let now = Date(timeIntervalSince1970: 1_950_000_000)
        let sut = DeleteSecretUseCaseImpl(repository: repo, entitlementUseCase: StubEntitlementUseCase(), dateProvider: { now })

        try await sut.softDeleteAll(in: .expired(referenceDate: refDate))

        #expect(repo.patchAllCount == 1)
        #expect(repo.lastPatch?.deletedAt == .set(now))
        #expect(repo.lastPatch?.updatedAt == .set(now))
        #expect(repo.secrets[expiredA.id]?.deletedAt == now)
        #expect(repo.secrets[expiredB.id]?.deletedAt == now)
        #expect(repo.secrets[active.id]?.deletedAt == nil)
        #expect(repo.deleteCount == 0)
    }

    @Test("permanentlyDeleteAll은 대상 컬렉션 전체만 영구 삭제한다(deleteAll 위임)")
    func permanentlyDeleteAllDeletesCollection() async throws {
        let repo = InMemorySecretRepository()
        let trashedA = SecretFixture.make(id: UUID(), deletedAt: Date(timeIntervalSince1970: 1))
        let trashedB = SecretFixture.make(id: UUID(), deletedAt: Date(timeIntervalSince1970: 2))
        // 휴지통 아님 → .deleted 대상 아님. 남아 있어야 한다.
        let live = SecretFixture.make(id: UUID())
        repo.seed(trashedA)
        repo.seed(trashedB)
        repo.seed(live)
        let sut = DeleteSecretUseCaseImpl(repository: repo, entitlementUseCase: StubEntitlementUseCase())

        try await sut.permanentlyDeleteAll(in: .deleted)

        #expect(repo.deleteAllCount == 1)
        #expect(repo.secrets[trashedA.id] == nil)
        #expect(repo.secrets[trashedB.id] == nil)
        #expect(repo.secrets[live.id] != nil)
    }

    @Test("대상이 없어도 위임은 하되 아무것도 바뀌지 않는다")
    func bulkOnEmptyChangesNothing() async throws {
        let repo = InMemorySecretRepository()
        let live = SecretFixture.make(id: UUID())
        repo.seed(live)
        let sut = DeleteSecretUseCaseImpl(repository: repo, entitlementUseCase: StubEntitlementUseCase())

        try await sut.permanentlyDeleteAll(in: .deleted)
        try await sut.softDeleteAll(in: .expired(referenceDate: Date(timeIntervalSince1970: 1)))

        #expect(repo.secrets[live.id]?.deletedAt == nil)
        #expect(repo.deleteAllCount == 1)
        #expect(repo.patchAllCount == 1)
        #expect(repo.deleteCount == 0)
    }

    @Test("Repository의 bulk 실패는 SecretUseCaseError로 매핑된다")
    func bulkMapsRepositoryError() async {
        let repo = InMemorySecretRepository()
        repo.errorOnDeleteAll = .persistenceFailed

        let sut = DeleteSecretUseCaseImpl(repository: repo, entitlementUseCase: StubEntitlementUseCase())

        await #expect(throws: SecretUseCaseError.repositoryFailure(.persistenceFailed)) {
            try await sut.permanentlyDeleteAll(in: .deleted)
        }
    }
}
