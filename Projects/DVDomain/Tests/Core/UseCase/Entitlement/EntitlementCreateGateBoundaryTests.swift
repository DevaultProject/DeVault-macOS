// Copyright © 2026 Devault. All rights reserved

import Foundation
import Testing

@testable import DVDomain

/// 복구(``DeleteSecretUseCase/restore(id:)``)가 이 판정에 기대게 되면서 경계를 고정한다. 생성·복구 양쪽이 같은 판정을 쓰므로 여기가 틀리면 두 경로가 함께 틀린다.
@Suite("EntitlementUseCase — canCreateSecret 경계")
struct EntitlementCreateGateBoundaryTests {

    private let secretRepository = InMemorySecretRepository()
    private let projectRepository = InMemoryProjectRepository()

    private func makeUseCase(entitlement: Entitlement) -> EntitlementUseCaseImpl {
        EntitlementUseCaseImpl(
            secretRepository: secretRepository,
            projectRepository: projectRepository,
            entitlementProvider: { entitlement },
            entitlementStream: { AsyncStream { $0.finish() } }
        )
    }

    private func seedSecrets(active: Int, trashed: Int = 0) {
        for index in 0..<(active + trashed) {
            let id = UUID()
            secretRepository.secrets[id] = SecretFixture.make(
                id: id,
                name: "Seed \(index)",
                deletedAt: index < active ? nil : SecretFixture.fixedDate
            )
        }
    }

    @Test("한도 직전(14)에는 허용한다 — 복구하면 정확히 한도에 닿는다")
    func allowsOneBelowLimit() async throws {
        seedSecrets(active: 14, trashed: 1)
        #expect(try await makeUseCase(entitlement: .free).canCreateSecret() == true)
    }

    @Test("한도에 닿으면(15) 거부한다 — 복구는 자리를 차지한다")
    func rejectsAtLimit() async throws {
        seedSecrets(active: 15, trashed: 1)
        #expect(try await makeUseCase(entitlement: .free).canCreateSecret() == false)
    }

    @Test("한도를 넘겨 보유 중이어도(16) 거부한다 — 다운그레이드 상태에서 더 늘리지 않는다")
    func rejectsOverLimit() async throws {
        seedSecrets(active: 16, trashed: 1)
        #expect(try await makeUseCase(entitlement: .free).canCreateSecret() == false)
    }

    @Test("휴지통 항목은 보유 수에 세지 않는다")
    func trashedSecretsDoNotCount() async throws {
        seedSecrets(active: 14, trashed: 10)
        #expect(try await makeUseCase(entitlement: .free).canCreateSecret() == true)
    }

    @Test("Pro는 개수와 무관하게 허용하고 저장소를 세지 않는다")
    func proBypassesCountEntirely() async throws {
        seedSecrets(active: 100)
        #expect(try await makeUseCase(entitlement: .pro).canCreateSecret() == true)
        #expect(secretRepository.countQueryCount == 0)
    }
}
