// Copyright © 2026 Devault. All rights reserved

import Foundation

public struct ImportSecretsUseCaseImpl: ImportSecretsUseCase {
    private let secretRepository: any SecretRepository
    private let projectRepository: any ProjectRepository
    private let cryptoService: any SecretCryptoService
    private let containerService: any DevaultContainerService
    private let entitlementUseCase: any EntitlementUseCase
    private let idGenerator: @Sendable () -> UUID
    private let dateProvider: @Sendable () -> Date

    /// - Parameters:
    ///   - secretRepository: 중복 판정·저장
    ///   - projectRepository: 프로젝트 생성·조회
    ///   - cryptoService: payload 재암호화·metadata 인코딩
    ///   - containerService: `.dvt` 개봉
    ///   - entitlementUseCase: 무료 티어 한도 판정. **기본값을 두지 않는다** — 빠뜨리면 가드가 조용히 사라진다
    ///   - idGenerator: 새 Secret·Project의 ID
    ///   - dateProvider: 생성·수정 시각
    public init(
        secretRepository: any SecretRepository,
        projectRepository: any ProjectRepository,
        cryptoService: any SecretCryptoService,
        containerService: any DevaultContainerService,
        entitlementUseCase: any EntitlementUseCase,
        idGenerator: @escaping @Sendable () -> UUID = { UUID() },
        dateProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.secretRepository = secretRepository
        self.projectRepository = projectRepository
        self.cryptoService = cryptoService
        self.containerService = containerService
        self.entitlementUseCase = entitlementUseCase
        self.idGenerator = idGenerator
        self.dateProvider = dateProvider
    }

    // MARK: - Decrypt

    public func decrypt(data: Data, password: SensitiveString) async throws -> DevaultContainerPayload {
        do {
            return try await containerService.import(data: data, password: password)
        } catch let error as DevaultImportError {
            throw error
        } catch {
            // 키 유도 실패 등 컨테이너 밖에서 온 오류도 이 네 가지 안으로 닫는다 — 호출부가 분기할 것이 더 늘면 안 된다.
            throw DevaultImportError.invalidPassword
        }
    }

    // MARK: - Judge

    public func judgeDuplicates(
        payload: DevaultContainerPayload,
        resolutions: [Int: ImportDuplicateResolution]
    ) async throws -> ImportDuplicateJudgement {
        var conflicts: [ImportDuplicateConflict] = []
        // 앞선 항목이 차지한 이름. skip된 항목은 들어오지 않으므로 뒤 항목을 막지 않는다.
        var claimed: [NameKey: Int] = [:]

        for (index, export) in payload.secrets.enumerated() {
            let resolution = resolutions[index]
            if case .skip = resolution { continue }

            let effectiveName = resolution.renamedName ?? export.name
            guard let comparable = SecretUseCaseHelper.comparableName(effectiveName) else { continue }
            let key = NameKey(name: comparable, secretType: export.content.secretType)

            // 파일 내부 충돌을 먼저 본다 — 앞선 항목이 어떻게 처리될지 모르는 채로 금고 덮어쓰기를 제안할 수 없다.
            if let earlier = claimed[key] {
                conflicts.append(makeConflict(index: index, export: export, name: effectiveName, target: .itemInFile(index: earlier)))
                continue
            }
            claimed[key] = index

            if let existingID = try await existingSecretID(name: comparable, secretType: key.secretType) {
                conflicts.append(makeConflict(index: index, export: export, name: effectiveName, target: .existingSecret(id: existingID)))
            }
        }

        return ImportDuplicateJudgement(totalCount: payload.secrets.count, conflicts: conflicts)
    }

    /// 덮어쓸 대상 하나를 고른다.
    ///
    /// 동명·동타입이 여럿일 수 있다(유니크 제약 없음 + iCloud 동기화). **가장 먼저 만들어진 것을 고른다** — 저장소가 돌려주는 순서에 기대면 실행마다 대상이 달라져 사용자가 무엇을 덮어썼는지 알 수 없다.
    private func existingSecretID(name: String, secretType: SecretType) async throws -> UUID? {
        let ids = try await secretRepository.fetchSecretIDs(name: name, secretType: secretType)
        guard !ids.isEmpty else { return nil }

        var oldest: (id: UUID, createdAt: Date)?
        for id in ids {
            guard let secret = try await secretRepository.fetch(id: id) else { continue }
            if oldest == nil || secret.createdAt < oldest!.createdAt {
                oldest = (secret.id, secret.createdAt)
            }
        }
        return oldest?.id
    }

    private func makeConflict(
        index: Int,
        export: DevaultSecretExport,
        name: String,
        target: ImportDuplicateConflict.Target
    ) -> ImportDuplicateConflict {
        ImportDuplicateConflict(
            index: index,
            name: name,
            secretType: export.content.secretType,
            subType: nil,
            target: target
        )
    }

    // MARK: - Execute

    public func execute(
        payload: DevaultContainerPayload,
        resolutions: [Int: ImportDuplicateResolution],
        project: ImportProjectChoice
    ) async throws -> [Secret] {
        let judgement = try await judgeDuplicates(payload: payload, resolutions: resolutions)
        // 선택하지 않은 충돌이 남아 있으면 진행할 수 없다 — 덮어쓸지 건너뛸지를 추측하면 사용자 데이터가 조용히 사라진다.
        guard judgement.conflicts.allSatisfy({ resolutions[$0.index] != nil }) else {
            throw SecretUseCaseError.unexpected
        }

        try await ensureImportable(count: judgement.slotsConsumed(by: resolutions))

        let projectIDs = try await resolveProjectIDs(project)
        let overwriteTargets = Dictionary(
            uniqueKeysWithValues: judgement.conflicts.compactMap { conflict -> (Int, UUID)? in
                guard case .existingSecret(let id) = conflict.target else { return nil }
                return (conflict.index, id)
            }
        )

        var created: [Secret] = []
        var imported: [Secret] = []
        do {
            for (index, export) in payload.secrets.enumerated() {
                let resolution = resolutions[index]
                if case .skip = resolution { continue }

                if case .overwrite = resolution, let targetID = overwriteTargets[index] {
                    imported.append(try await overwrite(id: targetID, with: export, projectIDs: projectIDs))
                } else {
                    let name = resolution.renamedName ?? export.name
                    let secret = try await create(export, name: name, projectIDs: projectIDs)
                    created.append(secret)
                    imported.append(secret)
                }
            }
        } catch {
            await rollback(created)
            throw error
        }
        return imported
    }

    /// 화면이 이미 물었더라도 다시 지킨다 — 그 사이 다른 생성이 끼어들 수 있고, 화면을 우회한 호출도 있다.
    private func ensureImportable(count: Int) async throws {
        let allowed: Bool
        do {
            allowed = try await entitlementUseCase.canImportSecrets(count: count)
        } catch {
            throw SecretUseCaseError.map(error)
        }
        guard allowed else { throw EntitlementError.limitReached }
    }

    /// 중도 실패 시 이미 만든 것을 지운다.
    ///
    /// 벌크 생성 API가 없어 N건이 N트랜잭션으로 나뉘므로 보상 삭제 없이는 부분 성공이 남는다. **소프트 삭제가 아니라 영구 삭제다** — 사용자가 만든 적 없는 시크릿을 휴지통에 남기지 않는다. 보상 자체가 실패하면 삼키고 원래 오류를 올린다: 호출부가 알아야 할 것은 import가 실패했다는 사실이다.
    private func rollback(_ secrets: [Secret]) async {
        for secret in secrets {
            try? await secretRepository.delete(id: secret.id)
        }
    }

    private func create(_ export: DevaultSecretExport, name: String, projectIDs: [UUID]) async throws -> Secret {
        let name = try SecretUseCaseHelper.comparableName(name) ?? { throw SecretUseCaseError.invalidName }()
        let (secretType, subType, payload, metadata) = try await export.content.materialize(cryptoService: cryptoService)
        let now = dateProvider()
        let secret = Secret(
            id: idGenerator(),
            name: name,
            secretType: secretType,
            subType: subType,
            service: export.service,
            environment: export.environment,
            // 보낸 쪽의 시각은 버려졌으므로 받는 쪽 기준 그 날 23:59:59로 다시 세운다.
            expiresAt: export.expiresAt?.endOfDay(),
            memo: export.memo,
            liked: export.liked,
            createdAt: now,
            updatedAt: now,
            payload: payload,
            metadata: metadata
        )

        let limit = entitlementUseCase.current() == .free ? EntitlementLimits.maxSecrets : Int.max
        guard let saved = try await secretRepository.create(secret, projectIDs: projectIDs, withinTotalLimit: limit) else {
            throw EntitlementError.limitReached
        }
        return saved
    }

    /// 기존 시크릿을 들여온 내용으로 교체한다. 자리를 늘리지 않으므로 생성 한도가 아니라 수정 잠금(``EntitlementUseCase/canEditSecrets()``)을 본다.
    private func overwrite(id: UUID, with export: DevaultSecretExport, projectIDs: [UUID]) async throws -> Secret {
        guard try await entitlementUseCase.canEditSecrets() else { throw EntitlementError.editLocked }

        let (secretType, subType, payload, metadata) = try await export.content.materialize(cryptoService: cryptoService)
        let patch = SecretPatch(
            secretType: .set(secretType),
            subType: .set(subType),
            service: .set(export.service),
            environment: .set(export.environment),
            expiresAt: .set(export.expiresAt?.endOfDay()),
            memo: .set(export.memo),
            liked: .set(export.liked),
            payload: .set(payload),
            metadata: .set(metadata),
            updatedAt: .set(dateProvider())
        )
        return try await secretRepository.patch(id: id, with: patch, projectIDs: projectIDs)
    }

    /// 연결할 프로젝트를 정한다. 새로 만드는 경우만 생성 한도를 본다.
    private func resolveProjectIDs(_ choice: ImportProjectChoice) async throws -> [UUID] {
        switch choice {
        case .none:
            return []
        case .existing(let id):
            guard try await projectRepository.fetch(id: id) != nil else { return [] }
            return [id]
        case .create(let rawName):
            guard let name = SecretUseCaseHelper.comparableName(rawName) else {
                throw SecretUseCaseError.invalidName
            }
            // 이름이 유니크하므로 같은 이름이 이미 있으면 만들지 않고 합류한다 — 거절하면 사용자가 막힌다.
            if let existing = try await projectRepository.fetchAll().first(where: { $0.name == name }) {
                return [existing.id]
            }
            guard try await entitlementUseCase.canCreateProject() else { throw EntitlementError.limitReached }
            let limit = entitlementUseCase.current() == .free ? EntitlementLimits.maxProjects : Int.max
            let now = dateProvider()
            let project = Project(id: idGenerator(), name: name, createdAt: now, updatedAt: now)
            guard let created = try await projectRepository.create(project, withinTotalLimit: limit) else {
                throw EntitlementError.limitReached
            }
            return [created.id]
        }
    }
}

// MARK: - Helpers

/// 중복 판정의 비교 단위 — `(정규화된 이름, 타입)` 쌍.
private struct NameKey: Hashable {
    let name: String
    let secretType: SecretType
}

extension Optional where Wrapped == ImportDuplicateResolution {
    /// 이름을 바꾸기로 한 경우의 새 이름. 그 외에는 nil이라 원래 이름을 쓴다.
    var renamedName: String? {
        if case .rename(let name) = self { return name }
        return nil
    }
}
