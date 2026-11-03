// Copyright © 2026 Devault. All rights reserved

import Foundation
import Testing

@testable import DVDomain

@Suite("ExportSecretsUseCaseImpl")
struct ExportSecretsUseCaseImplTests {

    private let repository = InMemorySecretRepository()
    private let crypto = FakeSecretCryptoService()
    private let container = FakeDevaultContainerService()

    private let fixedNow = Date(timeIntervalSince1970: 1_793_000_000)

    private func makeSUT() -> ExportSecretsUseCaseImpl {
        ExportSecretsUseCaseImpl(
            repository: repository,
            cryptoService: crypto,
            containerService: container,
            dateProvider: { [fixedNow] in fixedNow }
        )
    }

    /// 저장소에 넣을 때 payload를 Fake 규칙(JSON 그대로)으로 암호화해 둔다.
    private func seed(
        id: UUID = UUID(),
        name: String = "GitHub Token",
        secretType: SecretType = .apiKeyToken,
        subType: SecretSubType? = .apiKey,
        expiresAt: Date? = nil,
        deletedAt: Date? = nil,
        metadata: APIKeyMetadata? = nil
    ) throws -> Secret {
        let secret = SecretFixture.make(
            id: id,
            name: name,
            secretType: secretType,
            subType: subType,
            expiresAt: expiresAt,
            deletedAt: deletedAt,
            payload: SecretPayload(
                encryptedData: try JSONEncoder().encode(APIKeyPayload(value: "ghp_secret")),
                keyTag: "fake-key-tag",
                schemaVersion: APIKeyPayload.schemaVersion
            ),
            metadata: try metadata.map {
                SecretMetadata(metadataJSON: try JSONEncoder().encode($0), schemaVersion: APIKeyMetadata.schemaVersion)
            }
        )
        repository.seed(secret)
        return secret
    }

    @Test("선택한 시크릿을 봉인해 파일 URL을 돌려준다")
    func exportsSelectedSecrets() async throws {
        let secret = try seed()

        let url = try await makeSUT().execute(
            secretIDs: [secret.id],
            password: SensitiveString("correct horse"),
            expiresAt: nil
        )

        #expect(url.pathExtension == "dvt")
        #expect(container.lastPayload?.secrets.count == 1)
        #expect(container.lastPayload?.secrets.first?.name == "GitHub Token")
    }

    @Test("시크릿이 하나면 그 이름의 파일을 UUID 폴더 안에 쓴다")
    func namesFileAfterSingleSecret() async throws {
        let secret = try seed(name: "GitHub Token")

        let url = try await makeSUT().execute(
            secretIDs: [secret.id],
            password: SensitiveString("pw"),
            expiresAt: nil
        )
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        #expect(url.lastPathComponent == "GitHub Token.dvt")
        #expect(UUID(uuidString: url.deletingLastPathComponent().lastPathComponent) != nil)
    }

    @Test("모두 같은 프로젝트면 프로젝트 이름의 파일을 쓴다")
    func namesFileAfterSharedProject() async throws {
        let project = ProjectFixture.make(name: "DrinkiG")
        repository.seedProject(project)
        let first = try seed(name: "A")
        let second = try seed(name: "B")
        repository.projectLinks[first.id] = [project.id]
        repository.projectLinks[second.id] = [project.id]

        let url = try await makeSUT().execute(
            secretIDs: [first.id, second.id],
            password: SensitiveString("pw"),
            expiresAt: nil
        )
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        #expect(url.lastPathComponent == "DrinkiG.dvt")
    }

    @Test("프로젝트가 섞인 여러 시크릿은 날짜와 시각을 붙인 기본 이름을 쓴다")
    func namesFileWithTimestampForMixedSecrets() async throws {
        let first = try seed(name: "A")
        let second = try seed(name: "B")

        let url = try await makeSUT().execute(
            secretIDs: [first.id, second.id],
            password: SensitiveString("pw"),
            expiresAt: nil
        )
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }

        let expected = ExportFileName.make(secretNames: ["A", "B"], projectName: nil, now: fixedNow)
        #expect(url.lastPathComponent == expected)
    }

    @Test("같은 시크릿을 두 번 내보내도 서로 다른 폴더라 덮어쓰지 않는다")
    func doesNotOverwriteSameNamedFile() async throws {
        let secret = try seed(name: "GitHub Token")
        let sut = makeSUT()

        let first = try await sut.execute(secretIDs: [secret.id], password: SensitiveString("pw"), expiresAt: nil)
        let second = try await sut.execute(secretIDs: [secret.id], password: SensitiveString("pw"), expiresAt: nil)
        defer {
            try? FileManager.default.removeItem(at: first.deletingLastPathComponent())
            try? FileManager.default.removeItem(at: second.deletingLastPathComponent())
        }

        #expect(first != second)
        #expect(FileManager.default.fileExists(atPath: first.path))
        #expect(FileManager.default.fileExists(atPath: second.path))
    }

    @Test("휴지통 항목이 섞이면 전체를 거부하고 봉인하지 않는다")
    func rejectsWhenTrashedSecretIncluded() async throws {
        let alive = try seed(name: "Alive")
        let trashed = try seed(name: "Trashed", deletedAt: SecretFixture.fixedDate)

        await #expect(throws: (any Error).self) {
            try await makeSUT().execute(
                secretIDs: [alive.id, trashed.id],
                password: SensitiveString("pw"),
                expiresAt: nil
            )
        }
        #expect(container.exportCount == 0)
    }

    @Test("없는 id는 secretNotFound로 거부한다")
    func rejectsMissingSecret() async throws {
        let missing = UUID()

        await #expect(throws: SecretUseCaseError.secretNotFound(id: missing)) {
            try await makeSUT().execute(secretIDs: [missing], password: SensitiveString("pw"), expiresAt: nil)
        }
    }

    @Test("빈 선택은 거부한다 — 내용 없는 파일을 만들 이유가 없다")
    func rejectsEmptySelection() async throws {
        await #expect(throws: (any Error).self) {
            try await makeSUT().execute(secretIDs: [], password: SensitiveString("pw"), expiresAt: nil)
        }
        #expect(container.exportCount == 0)
    }

    @Test("만료일은 시각을 버리고 날짜 성분으로 담는다")
    func mapsExpiryToDateComponents() async throws {
        // 2026-12-31 23:59:59 UTC — 시각이 담기면 받는 쪽 시간대에서 하루가 밀린다.
        let expiry = Date(timeIntervalSince1970: 1_798_761_599)
        let secret = try seed(expiresAt: expiry)

        _ = try await makeSUT().execute(secretIDs: [secret.id], password: SensitiveString("pw"), expiresAt: nil)

        let components = try #require(container.lastPayload?.secrets.first?.expiresAt)
        let expected = DevaultDateComponents(date: expiry)
        #expect(components == expected)
    }

    @Test("metadata가 없으면 metadataSchemaVersion도 비운다")
    func omitsMetadataVersionWhenAbsent() async throws {
        let secret = try seed(metadata: nil)

        _ = try await makeSUT().execute(secretIDs: [secret.id], password: SensitiveString("pw"), expiresAt: nil)

        let export = try #require(container.lastPayload?.secrets.first)
        #expect(export.payloadSchemaVersion == APIKeyPayload.schemaVersion)
        #expect(export.metadataSchemaVersion == nil)
    }

    @Test("metadata가 있으면 함께 담고 버전도 채운다")
    func includesMetadataWhenPresent() async throws {
        let secret = try seed(metadata: APIKeyMetadata(scope: "repo:read"))

        _ = try await makeSUT().execute(secretIDs: [secret.id], password: SensitiveString("pw"), expiresAt: nil)

        let export = try #require(container.lastPayload?.secrets.first)
        #expect(export.metadataSchemaVersion == APIKeyMetadata.schemaVersion)
        #expect(export.content == .apiKey(APIKeyPayload(value: "ghp_secret"), APIKeyMetadata(scope: "repo:read")))
    }

    @Test("타입과 subType 조합이 어긋나면 거부한다 — 복호화할 타입을 고를 수 없다")
    func rejectsInconsistentTypePair() async throws {
        let secret = try seed(secretType: .apiKeyToken, subType: .sshKey)

        await #expect(throws: (any Error).self) {
            try await makeSUT().execute(secretIDs: [secret.id], password: SensitiveString("pw"), expiresAt: nil)
        }
    }

    @Test("모두 같은 프로젝트 하나에 속하면 그 이름을 담는다")
    func carriesSharedProjectName() async throws {
        let project = ProjectFixture.make(name: "Side Project")
        repository.seedProject(project)
        let first = try seed(name: "A")
        let second = try seed(name: "B")
        repository.projectLinks[first.id] = [project.id]
        repository.projectLinks[second.id] = [project.id]

        _ = try await makeSUT().execute(
            secretIDs: [first.id, second.id],
            password: SensitiveString("pw"),
            expiresAt: nil
        )

        #expect(container.lastPayload?.projectName == "Side Project")
    }

    @Test("소속이 갈리면 프로젝트 이름을 비운다 — 무엇을 적어도 거짓이 된다")
    func omitsProjectNameWhenMixed() async throws {
        let project = ProjectFixture.make(name: "Side Project")
        repository.seedProject(project)
        let linked = try seed(name: "A")
        let unlinked = try seed(name: "B")
        repository.projectLinks[linked.id] = [project.id]

        _ = try await makeSUT().execute(
            secretIDs: [linked.id, unlinked.id],
            password: SensitiveString("pw"),
            expiresAt: nil
        )

        #expect(container.lastPayload?.projectName == nil)
    }
}

