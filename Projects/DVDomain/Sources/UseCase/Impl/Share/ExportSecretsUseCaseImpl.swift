// Copyright © 2026 Devault. All rights reserved

import Foundation

public struct ExportSecretsUseCaseImpl: ExportSecretsUseCase {
    private let repository: any SecretRepository
    private let cryptoService: any SecretCryptoService
    private let containerService: any DevaultContainerService
    private let fileWriter: @Sendable (Data) throws -> URL

    /// - Parameters:
    ///   - repository: 내보낼 Secret 조회
    ///   - cryptoService: 저장된 payload 복호화·metadata 디코딩
    ///   - containerService: `.dvt` 봉인
    ///   - fileWriter: 봉인된 바이트를 파일로 쓰고 URL을 돌려준다. 테스트가 디스크를 건드리지 않게 주입받는다
    public init(
        repository: any SecretRepository,
        cryptoService: any SecretCryptoService,
        containerService: any DevaultContainerService,
        fileWriter: @escaping @Sendable (Data) throws -> URL = ExportSecretsUseCaseImpl.writeToTemporaryFile
    ) {
        self.repository = repository
        self.cryptoService = cryptoService
        self.containerService = containerService
        self.fileWriter = fileWriter
    }

    public func execute(secretIDs: [UUID], password: SensitiveString, expiresAt: Date?) async throws -> URL {
        guard !secretIDs.isEmpty else { throw SecretUseCaseError.unexpected }

        let secrets = try await fetchExportable(secretIDs)
        let projectName = try await sharedProjectName(of: secrets)

        var exports: [DevaultSecretExport] = []
        for secret in secrets {
            exports.append(try await makeExport(from: secret))
        }

        let payload = DevaultContainerPayload(projectName: projectName, secrets: exports)
        let sealed = try await containerService.export(payload: payload, password: password, expiresAt: expiresAt)
        return try fileWriter(sealed)
    }

    /// 요청한 id를 전부 찾고, 휴지통 항목이 섞이면 거부한다.
    ///
    /// 삭제된 시크릿은 조회·복사가 막혀 있으므로 내보내기도 막는다 — 화면이 이미 거르지만 화면을 우회한 호출도 있다. **하나라도 걸리면 전체를 거부한다**: 일부만 빼고 내보내면 사용자가 받은 파일에 무엇이 빠졌는지 알 방법이 없다.
    private func fetchExportable(_ ids: [UUID]) async throws -> [Secret] {
        var secrets: [Secret] = []
        for id in ids {
            guard let secret = try await repository.fetch(id: id) else {
                throw SecretUseCaseError.secretNotFound(id: id)
            }
            guard secret.deletedAt == nil else { throw SecretUseCaseError.unexpected }
            secrets.append(secret)
        }
        return secrets
    }

    /// 전부 같은 프로젝트 하나에만 속할 때만 그 이름을 담는다.
    ///
    /// 컨테이너는 이름 하나만 담는데 Secret↔Project는 M:N이라, 여럿이 섞이면 무엇을 적어도 거짓이 된다. 받는 쪽이 프로젝트를 고르는 선택지(``ImportProjectChoice``)를 이미 갖고 있으므로 모호하면 비워 보낸다.
    private func sharedProjectName(of secrets: [Secret]) async throws -> String? {
        var shared: Set<String>?
        for secret in secrets {
            let names = Set(try await repository.fetchProjects(secretID: secret.id).map(\.name))
            shared = shared.map { $0.intersection(names) } ?? names
            if shared?.isEmpty == true { return nil }
        }
        guard let shared, shared.count == 1 else { return nil }
        return shared.first
    }

    private func makeExport(from secret: Secret) async throws -> DevaultSecretExport {
        let (content, payloadVersion, metadataVersion) = try await DevaultSecretContentBox.make(
            from: secret,
            cryptoService: cryptoService
        )
        return DevaultSecretExport(
            name: secret.name,
            service: secret.service,
            environment: secret.environment,
            // 시각을 버리고 날짜 성분만 담는다 — 받는 쪽이 자기 시간대의 23:59:59로 다시 세운다.
            expiresAt: secret.expiresAt.map { DevaultDateComponents(date: $0) },
            memo: secret.memo,
            liked: secret.liked,
            content: content,
            payloadSchemaVersion: payloadVersion,
            metadataSchemaVersion: metadataVersion
        )
    }

    /// 임시 디렉터리에 `.dvt`로 쓴다. **삭제는 호출부 책임이다** — 시크릿 전체가 담긴 파일이라 공유·저장이 끝나면 지워야 한다.
    /// - Parameter data: 봉인된 컨테이너 바이트
    /// - Returns: 쓰인 파일 URL
    public static func writeToTemporaryFile(_ data: Data) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("dvt")
        try data.write(to: url, options: .completeFileProtection)
        return url
    }
}
