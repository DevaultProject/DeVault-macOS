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

    /// 휴지통에서 되살린다. **보유 수를 늘리는 동작이므로 생성과 같은 한도 게이트를 지난다** — 한도를 넘긴 보유 상태 자체는 정상으로 다루지만(다운그레이드), 사용자가 능동적으로 더 늘리는 것은 막는다.
    ///
    /// 저장소에 "세면서 되살리기"가 없어 판정과 저장 사이에 틈이 있다 — 동시에 시작한 복구 둘이 같은 개수를 보고 나란히 통과할 수 있다. 생성 경로(`withinTotalLimit`)와 달리 원자적이지 않지만, 휴지통 화면에서 한 건씩 누르는 동작이라 실제로 겹치기 어렵다.
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
    /// 판정 실패(저장소 오류)와 게이트 차단은 다른 것이다. 전자는 ``SecretUseCaseError``로 매핑하고, 후자만 ``EntitlementError``로 내보내 호출부가 페이월을 띄우게 한다.
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
