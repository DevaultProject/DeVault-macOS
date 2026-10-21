// Copyright © 2026 Devault. All rights reserved

import Foundation
import Testing

@testable import DVDomain

@Suite("ImportSecretsUseCaseImpl")
struct ImportSecretsUseCaseImplTests {

    private let secretRepository = InMemorySecretRepository()
    private let projectRepository = InMemoryProjectRepository()
    private let crypto = FakeSecretCryptoService()
    private let container = StubDevaultContainerService()
    private let entitlement = StubEntitlementUseCase()

    private func makeSUT() -> ImportSecretsUseCaseImpl {
        ImportSecretsUseCaseImpl(
            secretRepository: secretRepository,
            projectRepository: projectRepository,
            cryptoService: crypto,
            containerService: container,
            entitlementUseCase: entitlement
        )
    }

    private func export(
        name: String,
        content: DevaultSecretContentBox = .apiKey(APIKeyPayload(value: "v"), nil),
        expiresAt: DevaultDateComponents? = nil
    ) -> DevaultSecretExport {
        DevaultSecretExport(
            name: name,
            expiresAt: expiresAt,
            content: content,
            payloadSchemaVersion: APIKeyPayload.schemaVersion
        )
    }

    private func seedVaultSecret(name: String, secretType: SecretType = .apiKeyToken, createdAt: Date = SecretFixture.fixedDate) -> Secret {
        let secret = SecretFixture.make(id: UUID(), name: name, secretType: secretType, createdAt: createdAt)
        secretRepository.seed(secret)
        return secret
    }

    // MARK: - decrypt

    @Test("컨테이너 오류는 그대로, 그 밖의 실패는 invalidPassword로 닫는다")
    func closesErrorSurface() async throws {
        container.errorOnImport = DevaultImportError.expired
        await #expect(throws: DevaultImportError.expired) {
            try await makeSUT().decrypt(data: Data(), password: SensitiveString("pw"))
        }

        container.errorOnImport = SecretRepositoryError.persistenceFailed
        await #expect(throws: DevaultImportError.invalidPassword) {
            try await makeSUT().decrypt(data: Data(), password: SensitiveString("pw"))
        }
    }

    // MARK: - judgeDuplicates

    @Test("금고에 같은 이름·타입이 있으면 충돌로 보고한다")
    func detectsVaultConflict() async throws {
        let existing = seedVaultSecret(name: "GitHub")
        let payload = DevaultContainerPayload(secrets: [export(name: "GitHub")])

        let judgement = try await makeSUT().judgeDuplicates(payload: payload, resolutions: [:])

        #expect(judgement.conflicts.count == 1)
        #expect(judgement.conflicts.first?.target == .existingSecret(id: existing.id))
    }

    @Test("타입이 다르면 같은 이름이어도 충돌이 아니다")
    func sameNameDifferentTypeIsNotConflict() async throws {
        _ = seedVaultSecret(name: "GitHub", secretType: .database)
        let payload = DevaultContainerPayload(secrets: [export(name: "GitHub")])

        let judgement = try await makeSUT().judgeDuplicates(payload: payload, resolutions: [:])

        #expect(judgement.conflicts.isEmpty)
    }

    @Test("파일 안에서 앞선 항목과 겹치면 itemInFile로 보고한다 — 덮어쓸 대상이 없다")
    func detectsInFileConflict() async throws {
        let payload = DevaultContainerPayload(secrets: [export(name: "Dup"), export(name: "Dup")])

        let judgement = try await makeSUT().judgeDuplicates(payload: payload, resolutions: [:])

        #expect(judgement.conflicts.count == 1)
        #expect(judgement.conflicts.first?.index == 1)
        #expect(judgement.conflicts.first?.target == .itemInFile(index: 0))
    }

    @Test("이름을 바꾸면 그 이름으로 재판정한다 — 충돌이 사라지거나 새로 생긴다")
    func rejudgesRenamedName() async throws {
        _ = seedVaultSecret(name: "GitHub")
        _ = seedVaultSecret(name: "GitLab")
        let payload = DevaultContainerPayload(secrets: [export(name: "GitHub")])
        let sut = makeSUT()

        // 충돌 없는 이름으로 바꾸면 사라진다.
        let cleared = try await sut.judgeDuplicates(payload: payload, resolutions: [0: .rename("Bitbucket")])
        #expect(cleared.conflicts.isEmpty)

        // 또 다른 기존 이름으로 바꾸면 새 충돌이 생긴다.
        let recreated = try await sut.judgeDuplicates(payload: payload, resolutions: [0: .rename("GitLab")])
        #expect(recreated.conflicts.count == 1)
    }

    @Test("건너뛴 항목은 이름을 차지하지 않아 뒤 항목을 막지 않는다")
    func skippedItemDoesNotClaimName() async throws {
        let payload = DevaultContainerPayload(secrets: [export(name: "Dup"), export(name: "Dup")])

        let judgement = try await makeSUT().judgeDuplicates(payload: payload, resolutions: [0: .skip])

        #expect(judgement.conflicts.isEmpty)
    }

    @Test("동명이 여럿이면 가장 먼저 만들어진 것을 덮어쓰기 대상으로 고른다")
    func picksOldestOnMultipleMatches() async throws {
        let older = seedVaultSecret(name: "Dup", createdAt: Date(timeIntervalSince1970: 1_000))
        _ = seedVaultSecret(name: "Dup", createdAt: Date(timeIntervalSince1970: 2_000))
        let payload = DevaultContainerPayload(secrets: [export(name: "Dup")])

        let judgement = try await makeSUT().judgeDuplicates(payload: payload, resolutions: [:])

        #expect(judgement.conflicts.first?.target == .existingSecret(id: older.id))
    }

    // MARK: - execute

    @Test("충돌이 없으면 전부 새로 만든다")
    func createsAllWhenNoConflict() async throws {
        let payload = DevaultContainerPayload(secrets: [export(name: "A"), export(name: "B")])

        let imported = try await makeSUT().execute(payload: payload, resolutions: [:], project: .none)

        #expect(imported.count == 2)
        #expect(secretRepository.secrets.count == 2)
    }

    @Test("선택하지 않은 충돌이 남아 있으면 거부한다 — 추측하면 데이터가 사라진다")
    func rejectsUnresolvedConflict() async throws {
        _ = seedVaultSecret(name: "GitHub")
        let payload = DevaultContainerPayload(secrets: [export(name: "GitHub")])

        await #expect(throws: (any Error).self) {
            try await makeSUT().execute(payload: payload, resolutions: [:], project: .none)
        }
        #expect(secretRepository.createCount == 0)
    }

    @Test("overwrite는 기존 시크릿을 교체하고 새 자리를 쓰지 않는다")
    func overwriteReplacesExisting() async throws {
        let existing = seedVaultSecret(name: "GitHub")
        let payload = DevaultContainerPayload(secrets: [export(name: "GitHub")])

        let imported = try await makeSUT().execute(payload: payload, resolutions: [0: .overwrite], project: .none)

        #expect(imported.count == 1)
        #expect(imported.first?.id == existing.id)
        #expect(secretRepository.createCount == 0)
        #expect(entitlement.lastImportCount == 0)
    }

    @Test("skip한 항목은 만들지 않는다")
    func skipCreatesNothing() async throws {
        _ = seedVaultSecret(name: "GitHub")
        let payload = DevaultContainerPayload(secrets: [export(name: "GitHub"), export(name: "New")])

        let imported = try await makeSUT().execute(payload: payload, resolutions: [0: .skip], project: .none)

        #expect(imported.count == 1)
        #expect(imported.first?.name == "New")
    }

    @Test("한도를 넘기면 아무것도 만들지 않고 거부한다")
    func rejectsWhenOverLimit() async throws {
        entitlement.canImportSecretsValue = false
        let payload = DevaultContainerPayload(secrets: [export(name: "A")])

        await #expect(throws: EntitlementError.limitReached) {
            try await makeSUT().execute(payload: payload, resolutions: [:], project: .none)
        }
        #expect(secretRepository.createCount == 0)
    }

    @Test("중도 실패하면 이미 만든 것을 지우고 전량 되돌린다")
    func rollsBackOnPartialFailure() async throws {
        // 두 번째 저장에서 깨지게 한다.
        secretRepository.failCreateAfter = 1
        let payload = DevaultContainerPayload(secrets: [export(name: "A"), export(name: "B")])

        await #expect(throws: (any Error).self) {
            try await makeSUT().execute(payload: payload, resolutions: [:], project: .none)
        }
        #expect(secretRepository.secrets.isEmpty, "보상 삭제가 돌지 않아 부분 성공이 남았다")
    }

    @Test("만료일은 받는 쪽 기준 그 날 23:59:59로 복원한다")
    func restoresExpiryAsEndOfDay() async throws {
        let components = DevaultDateComponents(year: 2026, month: 12, day: 31)
        let payload = DevaultContainerPayload(secrets: [export(name: "A", expiresAt: components)])

        let imported = try await makeSUT().execute(payload: payload, resolutions: [:], project: .none)

        #expect(imported.first?.expiresAt == components.endOfDay())
    }

    @Test("새 프로젝트 이름이 이미 있으면 만들지 않고 합류한다")
    func joinsExistingProjectOnNameClash() async throws {
        let existing = ProjectFixture.make(id: UUID(), name: "Side")
        projectRepository.seed(existing)
        let payload = DevaultContainerPayload(secrets: [export(name: "A")])

        let imported = try await makeSUT().execute(payload: payload, resolutions: [:], project: .create(name: "Side"))

        let links = secretRepository.projectLinks[try #require(imported.first?.id)]
        #expect(links == [existing.id])
        #expect(projectRepository.projects.count == 1)
    }

    @Test("프로젝트 한도에 걸리면 거부하고 시크릿도 만들지 않는다")
    func rejectsWhenProjectLimitReached() async throws {
        entitlement.canCreateProjectValue = false
        let payload = DevaultContainerPayload(secrets: [export(name: "A")])

        await #expect(throws: EntitlementError.limitReached) {
            try await makeSUT().execute(payload: payload, resolutions: [:], project: .create(name: "New"))
        }
        #expect(secretRepository.createCount == 0)
    }
}

/// 개봉 결과를 고정으로 돌려주는 스텁. 실제 암복호는 `DevaultContainerServiceImpl` 테스트가 본다.
private final class StubDevaultContainerService: DevaultContainerService, @unchecked Sendable {
    var errorOnImport: (any Error)?

    func export(payload: DevaultContainerPayload, password: SensitiveString, expiresAt: Date?) async throws -> Data {
        Data()
    }

    func `import`(data: Data, password: SensitiveString) async throws -> DevaultContainerPayload {
        if let errorOnImport { throw errorOnImport }
        return DevaultContainerPayload(secrets: [])
    }
}
