// Copyright © 2026 Devault. All rights reserved

import Foundation
import Testing

@testable import DVDomain

@Suite("EntitlementUseCase — canImportSecrets(count:)")
struct EntitlementImportGateTests {

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

    private func seedSecrets(count: Int, trashed: Int = 0) {
        for index in 0..<(count + trashed) {
            let id = UUID()
            secretRepository.secrets[id] = SecretFixture.make(
                id: id,
                name: "Seed \(index)",
                deletedAt: index < count ? nil : SecretFixture.fixedDate
            )
        }
    }

    @Test("한도를 꽉 채우는 import는 허용한다 — 10 보유 + 5 요청")
    func allowsImportUpToLimit() async throws {
        seedSecrets(count: 10)
        let useCase = makeUseCase(entitlement: .free)
        #expect(try await useCase.canImportSecrets(count: 5) == true)
    }

    @Test("한도를 한 개라도 넘기면 전량 거부한다 — 10 보유 + 6 요청")
    func rejectsImportExceedingLimit() async throws {
        seedSecrets(count: 10)
        let useCase = makeUseCase(entitlement: .free)
        #expect(try await useCase.canImportSecrets(count: 6) == false)
    }

    @Test("휴지통 항목은 보유 수에 세지 않는다")
    func trashedSecretsDoNotCount() async throws {
        seedSecrets(count: 10, trashed: 5)
        let useCase = makeUseCase(entitlement: .free)
        #expect(try await useCase.canImportSecrets(count: 5) == true)
    }

    @Test("Pro는 개수와 무관하게 허용하고 저장소를 세지 않는다")
    func proBypassesCountEntirely() async throws {
        let useCase = makeUseCase(entitlement: .pro)
        #expect(try await useCase.canImportSecrets(count: 1_000) == true)
        #expect(secretRepository.countQueryCount == 0)
    }

    @Test("count 0은 한도 보유 상태에서도 허용한다 — 전부 덮어쓰기/건너뛰기인 import")
    func zeroCountAllowedAtLimit() async throws {
        seedSecrets(count: 15)
        let useCase = makeUseCase(entitlement: .free)
        #expect(try await useCase.canImportSecrets(count: 0) == true)
    }

    @Test("한도를 넘겨 보유 중이어도 생성이 없으면 허용한다 — 판정은 canEditSecrets가 맡는다")
    func zeroCountAllowedWhenOverLimit() async throws {
        // 여기서 막으면 limitReached("더 만들 수 없다")가 나가는데, 다운그레이드 사용자에게 필요한 안내는 editLocked다.
        seedSecrets(count: 20)
        let useCase = makeUseCase(entitlement: .free)
        #expect(try await useCase.canImportSecrets(count: 0) == true)
    }
}
