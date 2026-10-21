// Copyright © 2026 Devault. All rights reserved

import Foundation

public struct DeleteSecretUseCaseImpl: DeleteSecretUseCase {
    private let repository: any SecretRepository
    private let entitlementUseCase: any EntitlementUseCase
    private let dateProvider: @Sendable () -> Date

    /// - Parameters:
    ///   - repository: Secret 저장소
    ///   - entitlementUseCase: 복구 시 무료 티어 한도 판정. **기본값을 두지 않는다** — 빠뜨리면 가드가 조용히 사라진다
    ///   - dateProvider: `deletedAt`·`updatedAt`에 쓸 현재 시각
    public init(
        repository: any SecretRepository,
        entitlementUseCase: any EntitlementUseCase,
        dateProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.entitlementUseCase = entitlementUseCase
        self.dateProvider = dateProvider
    }

    public func softDelete(id: UUID) async throws -> Secret {
        do {
            let now = dateProvider()
            let patch = SecretPatch(
                deletedAt: .set(now),
                updatedAt: .set(now)
            )
            return try await repository.patch(id: id, with: patch)
        } catch {
            throw SecretUseCaseError.map(error)
        }
    }

    /// 저장소에 "세면서 되살리기"가 없어 판정과 저장 사이에 틈이 있다 — 동시에 시작한 복구 둘이 같은 개수를 보고 나란히 통과할 수 있다. 생성 경로(`withinTotalLimit`)와 달리 원자적이지 않다.
    // ponytail: 판정과 저장이 분리된 비원자적 게이트. 한도를 아는 patch API가 생기면 그쪽으로 옮긴다.
    public func restore(id: UUID) async throws -> Secret {
        try await ensureRestorable()

        do {
            let now = dateProvider()
            let patch = SecretPatch(
                deletedAt: .set(nil),
                updatedAt: .set(now)
            )
            return try await repository.patch(id: id, with: patch)
        } catch {
            throw SecretUseCaseError.map(error)
        }
    }

    /// 생성과 같은 기준으로 묻는다 — 복구된 Secret이 차지할 자리가 있어야 한다.
    ///
    /// 판정 실패(저장소 오류)와 게이트 차단은 다른 것이다. 전자는 ``SecretUseCaseError``로 매핑하고, 후자만 ``EntitlementError``로 내보낸다. **화면은 이 게이트에 도달하기 전에 먼저 묻는다** — 여기까지 오면 일반 오류 알림으로 끝나므로, 페이월은 ``EntitlementClient``로 사전 질의한 화면이 띄운다.
    private func ensureRestorable() async throws {
        let allowed: Bool
        do {
            allowed = try await entitlementUseCase.canCreateSecret()
        } catch {
            throw SecretUseCaseError.map(error)
        }
        guard allowed else { throw EntitlementError.limitReached }
    }

    public func permanentlyDelete(id: UUID) async throws {
        do {
            try await repository.delete(id: id)
        } catch {
            throw SecretUseCaseError.map(error)
        }
    }

    public func softDeleteAll(in collection: SecretQuery.Collection) async throws {
        do {
            // "소프트 삭제 = deletedAt·updatedAt 세팅"이라는 규칙은 유스케이스가 정하고(단건 softDelete와 동일),
            // 조회·전체 변경·저장의 원자성은 Repository가 단일 트랜잭션으로 책임진다.
            let now = dateProvider()
            try await repository.patchAll(
                matching: SecretQuery(collection: collection),
                with: SecretPatch(deletedAt: .set(now), updatedAt: .set(now))
            )
        } catch {
            throw SecretUseCaseError.map(error)
        }
    }

    public func permanentlyDeleteAll(in collection: SecretQuery.Collection) async throws {
        do {
            try await repository.deleteAll(matching: SecretQuery(collection: collection))
        } catch {
            throw SecretUseCaseError.map(error)
        }
    }
}
