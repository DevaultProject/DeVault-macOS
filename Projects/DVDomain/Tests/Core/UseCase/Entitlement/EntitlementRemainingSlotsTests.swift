// Copyright © 2026 Devault. All rights reserved

import Foundation
import Testing

@testable import DVDomain

@Suite("EntitlementUseCase — remainingSecretSlots")
struct EntitlementRemainingSlotsTests {

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

    private func seedSecrets(active: Int) {
        for index in 0..<active {
            let id = UUID()
            secretRepository.secrets[id] = SecretFixture.make(id: id, name: "Seed \(index)")
        }
    }

    @Test("무료 한도 아래면 남은 자리를 그대로 돌려준다")
    func returnsRemainingBelowLimit() async throws {
        seedSecrets(active: 10)
        #expect(try await makeUseCase(entitlement: .free).remainingSecretSlots() == 5)
    }

    @Test("한도에 정확히 닿으면 0을 돌려준다")
    func returnsZeroAtLimit() async throws {
        seedSecrets(active: 15)
        #expect(try await makeUseCase(entitlement: .free).remainingSecretSlots() == 0)
    }

    @Test("한도를 넘겨 보유 중이어도 음수가 아니라 0을 돌려준다")
    func returnsZeroOverLimit() async throws {
        seedSecrets(active: 20)
        #expect(try await makeUseCase(entitlement: .free).remainingSecretSlots() == 0)
    }

    @Test("Pro는 개수와 무관하게 nil(무제한)을 돌려주고 저장소를 세지 않는다")
    func proReturnsNilWithoutCounting() async throws {
        seedSecrets(active: 100)
        #expect(try await makeUseCase(entitlement: .pro).remainingSecretSlots() == nil)
        #expect(secretRepository.countQueryCount == 0)
    }
}
