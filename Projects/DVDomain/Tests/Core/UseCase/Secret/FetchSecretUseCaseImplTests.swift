// Copyright © 2026 Devault. All rights reserved

import Foundation
import Testing

@testable import DVDomain

@Suite("FetchSecretUseCaseImpl")
struct FetchSecretUseCaseImplTests {
    // MARK: - fetch(id:)

    @Test("fetch(id:)는 Repository 결과를 그대로 반환한다")
    func fetchByIDReturnsRepositoryResult() async throws {
        let repo = InMemorySecretRepository()
        let secret = SecretFixture.make()
        repo.seed(secret)
        let sut = makeSUT(repository: repo)

        let result = try await sut.fetch(id: secret.id)

        #expect(result == secret)
    }

    @Test("fetch(id:)는 Repository가 nil을 주면 nil을 반환한다")
    func fetchByIDReturnsNil() async throws {
        let sut = makeSUT(repository: InMemorySecretRepository())

        let result = try await sut.fetch(id: UUID())

        #expect(result == nil)
    }

    // MARK: - fetch(query:)

    @Test("fetch(query:)는 Repository 결과를 그대로 반환한다")
    func fetchQueryReturnsRepositoryResult() async throws {
        let repo = InMemorySecretRepository()
        repo.seed(SecretFixture.make(id: UUID()))
        repo.seed(SecretFixture.make(id: UUID()))
        let sut = makeSUT(repository: repo)

        let result = try await sut.fetch(query: SecretQuery())

        #expect(result.count == 2)
    }

    // MARK: - count(query:)

    @Test("count(query:)는 collection 조건에 맞는 개수만 센다")
    func countAppliesCollection() async throws {
        let repo = InMemorySecretRepository()
        repo.seed(SecretFixture.make(id: UUID()))
        repo.seed(SecretFixture.make(id: UUID(), liked: true))
        repo.seed(SecretFixture.make(id: UUID(), deletedAt: .now))
        let sut = makeSUT(repository: repo)

        #expect(try await sut.count(query: SecretQuery(collection: .all)) == 2)
        #expect(try await sut.count(query: SecretQuery(collection: .liked)) == 1)
        #expect(try await sut.count(query: SecretQuery(collection: .deleted)) == 1)
    }

    @Test("count(query:)는 secretType·service·environment 필터를 함께 적용한다")
    func countAppliesFieldFilters() async throws {
        let repo = InMemorySecretRepository()
        repo.seed(SecretFixture.make(id: UUID(), service: "github", environment: "prod"))
        repo.seed(SecretFixture.make(id: UUID(), service: "github", environment: "dev"))
        repo.seed(SecretFixture.make(id: UUID(), secretType: .database, service: "aws"))
        let sut = makeSUT(repository: repo)

        #expect(try await sut.count(query: SecretQuery(service: "github")) == 2)
        #expect(try await sut.count(query: SecretQuery(service: "github", environment: "prod")) == 1)
        #expect(try await sut.count(query: SecretQuery(secretType: .database)) == 1)
    }

    @Test("count(query:)는 만료된 Secret을 .all에서 제외하고 .expired에서만 센다")
    func countSeparatesExpired() async throws {
        let repo = InMemorySecretRepository()
        let now = Date.now
        repo.seed(SecretFixture.make(id: UUID(), expiresAt: now.addingTimeInterval(3600)))
        repo.seed(SecretFixture.make(id: UUID(), expiresAt: now.addingTimeInterval(-3600)))
        repo.seed(SecretFixture.make(id: UUID(), expiresAt: nil))
        let sut = makeSUT(repository: repo)

        // 만료일이 없는 Secret은 "만료되지 않음"으로 취급되어 .all에 포함된다.
        #expect(try await sut.count(query: SecretQuery(collection: .all)) == 2)
        #expect(try await sut.count(query: SecretQuery(collection: .expired(referenceDate: now))) == 1)
    }

    @Test("count(query:)는 .notice에서 이미 지난 것과 window(7일)를 벗어난 것을 제외한다")
    func countSeparatesNotice() async throws {
        let repo = InMemorySecretRepository()
        let now = Date.now
        let alreadyExpired = SecretFixture.make(id: UUID(), expiresAt: now.addingTimeInterval(-3600))
        let withinWindow = SecretFixture.make(id: UUID(), expiresAt: now.addingTimeInterval(3 * 86_400))
        let exactlyAtBoundary = SecretFixture.make(
            id: UUID(),
            expiresAt: now.addingTimeInterval(TimeInterval(SecretQuery.Collection.noticeWindowDays) * 86_400)
        )
        let beyondWindow = SecretFixture.make(id: UUID(), expiresAt: now.addingTimeInterval(30 * 86_400))
        let neverExpires = SecretFixture.make(id: UUID(), expiresAt: nil)
        [alreadyExpired, withinWindow, exactlyAtBoundary, beyondWindow, neverExpires].forEach(repo.seed)
        let sut = makeSUT(repository: repo)

        // 이미 지남 · window 밖 · 만료일 없음은 제외되고, window 이내(경계 포함) 2건만 남는다.
        #expect(try await sut.count(query: SecretQuery(collection: .notice(referenceDate: now))) == 2)
    }

    @Test("count(query:)는 Repository 에러를 SecretUseCaseError로 매핑한다")
    func countMapsRepositoryError() async {
        let repo = InMemorySecretRepository()
        repo.errorOnCountQuery = .persistenceFailed
        let sut = makeSUT(repository: repo)

        await #expect(throws: SecretUseCaseError.repositoryFailure(.persistenceFailed)) {
            _ = try await sut.count(query: SecretQuery())
        }
    }

    // MARK: - isNameDuplicated

    @Test("isNameDuplicated는 같은 타입에 같은 이름이 있으면 true를 반환한다")
    func isNameDuplicatedFindsSameNameInSameType() async throws {
        let repo = InMemorySecretRepository()
        repo.seed(SecretFixture.make(name: "AWS Key", secretType: .apiKeyToken))
        let sut = makeSUT(repository: repo)

        #expect(try await sut.isNameDuplicated(name: "AWS Key", secretType: .apiKeyToken))
    }

    @Test("isNameDuplicated는 겹치는 이름이 없으면 false를 반환한다")
    func isNameDuplicatedReturnsFalseWhenNoMatch() async throws {
        let repo = InMemorySecretRepository()
        repo.seed(SecretFixture.make(name: "AWS Key", secretType: .apiKeyToken))
        let sut = makeSUT(repository: repo)

        #expect(try await sut.isNameDuplicated(name: "GCP Key", secretType: .apiKeyToken) == false)
    }

    @Test("isNameDuplicated는 이름이 같아도 타입이 다르면 false를 반환한다")
    func isNameDuplicatedSeparatesSecretType() async throws {
        let repo = InMemorySecretRepository()
        repo.seed(SecretFixture.make(name: "AWS Key", secretType: .apiKeyToken))
        let sut = makeSUT(repository: repo)

        #expect(try await sut.isNameDuplicated(name: "AWS Key", secretType: .database) == false)
    }

    @Test("isNameDuplicated는 앞뒤 공백을 제거한 이름으로 비교한다")
    func isNameDuplicatedTrimsName() async throws {
        let repo = InMemorySecretRepository()
        repo.seed(SecretFixture.make(name: "AWS Key", secretType: .apiKeyToken))
        let sut = makeSUT(repository: repo)

        #expect(try await sut.isNameDuplicated(name: "  AWS Key\n", secretType: .apiKeyToken))
        #expect(repo.lastContainsSecretName == "AWS Key")
    }

    @Test("isNameDuplicated는 대소문자가 다르면 false를 반환한다")
    func isNameDuplicatedIsCaseSensitive() async throws {
        let repo = InMemorySecretRepository()
        repo.seed(SecretFixture.make(name: "AWS Key", secretType: .apiKeyToken))
        let sut = makeSUT(repository: repo)

        #expect(try await sut.isNameDuplicated(name: "aws key", secretType: .apiKeyToken) == false)
    }

    @Test("isNameDuplicated는 공백뿐인 이름이면 Repository를 부르지 않고 false를 반환한다")
    func isNameDuplicatedShortCircuitsBlankName() async throws {
        let repo = InMemorySecretRepository()
        repo.seed(SecretFixture.make(name: "AWS Key", secretType: .apiKeyToken))
        let sut = makeSUT(repository: repo)

        #expect(try await sut.isNameDuplicated(name: "   ", secretType: .apiKeyToken) == false)
        #expect(repo.containsSecretCount == 0)
    }

    @Test("isNameDuplicated는 excludingID가 가리키는 Secret을 비교에서 뺀다")
    func isNameDuplicatedExcludesGivenID() async throws {
        let repo = InMemorySecretRepository()
        let editing = SecretFixture.make(id: UUID(), name: "AWS Key", secretType: .apiKeyToken)
        repo.seed(editing)
        let sut = makeSUT(repository: repo)

        #expect(try await sut.isNameDuplicated(
            name: "AWS Key",
            secretType: .apiKeyToken,
            excludingID: editing.id
        ) == false)
    }

    @Test("isNameDuplicated는 휴지통의 Secret을 중복으로 보지 않는다")
    func isNameDuplicatedIgnoresTrashedSecret() async throws {
        let repo = InMemorySecretRepository()
        repo.seed(SecretFixture.make(name: "AWS Key", secretType: .apiKeyToken, deletedAt: .now))
        let sut = makeSUT(repository: repo)

        #expect(try await sut.isNameDuplicated(name: "AWS Key", secretType: .apiKeyToken) == false)
    }

    @Test("isNameDuplicated는 만료된 Secret도 중복으로 본다")
    func isNameDuplicatedCountsExpiredSecret() async throws {
        let repo = InMemorySecretRepository()
        repo.seed(SecretFixture.make(
            name: "AWS Key",
            secretType: .apiKeyToken,
            expiresAt: Date.now.addingTimeInterval(-86_400)
        ))
        let sut = makeSUT(repository: repo)

        #expect(try await sut.isNameDuplicated(name: "AWS Key", secretType: .apiKeyToken))
    }

    @Test("isNameDuplicated는 Repository 에러를 SecretUseCaseError로 매핑한다")
    func isNameDuplicatedMapsRepositoryError() async {
        let repo = InMemorySecretRepository()
        repo.errorOnContainsSecret = .persistenceFailed
        let sut = makeSUT(repository: repo)

        await #expect(throws: SecretUseCaseError.repositoryFailure(.persistenceFailed)) {
            _ = try await sut.isNameDuplicated(name: "AWS Key", secretType: .apiKeyToken)
        }
    }

    // MARK: - Helpers

    private func makeSUT(repository: InMemorySecretRepository) -> FetchSecretUseCaseImpl {
        FetchSecretUseCaseImpl(repository: repository)
    }
}
