// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVData
import DVDomain
import DVPresentation
import Foundation

extension SecretClient: @retroactive DependencyKey {
    public static let liveValue: SecretClient = {
        let secretRepo = LiveRepositories.secret
        let projectRepo = LiveRepositories.project
        let cryptoService: any SecretCryptoService = SecretCryptoServiceImpl()
        let authenticateUseCase: any AuthenticateUseCase = LiveUseCases.authenticate
        let fetchSecretUseCase: any FetchSecretUseCase = FetchSecretUseCaseImpl(
            repository: secretRepo
        )
        let decryptSecretPayloadUseCase: any DecryptSecretPayloadUseCase = DecryptSecretPayloadUseCaseImpl(
            repository: secretRepo,
            cryptoService: cryptoService
        )
        let revealSecretPayloadUseCase: any RevealSecretPayloadUseCase = RevealSecretPayloadUseCaseImpl(
            decryptPayloadUseCase: decryptSecretPayloadUseCase,
            authenticateUseCase: authenticateUseCase
        )
        let deleteSecretUseCase: any DeleteSecretUseCase = DeleteSecretUseCaseImpl(
            repository: secretRepo
        )
        let relationUseCase: any SecretProjectRelationUseCase = SecretProjectRelationUseCaseImpl(
            repository: secretRepo
        )
        let patchSecretUseCase: any PatchSecretUseCase = PatchSecretUseCaseImpl(
            repository: secretRepo,
            cryptoService: cryptoService,
            entitlementUseCase: LiveUseCases.entitlement
        )
        let fetchProjectUseCase: any FetchProjectUseCase = FetchProjectUseCaseImpl(
            repository: projectRepo
        )
        let createProjectUseCase: any CreateProjectUseCase = CreateProjectUseCaseImpl(
            repository: projectRepo,
            entitlementUseCase: LiveUseCases.entitlement
        )

        return SecretClient(
            fetchByQuery: { query in
                try await fetchSecretUseCase.fetch(query: query)
            },
            totalCountExcludingTrash: {
                try await fetchSecretUseCase.totalCountExcludingTrash()
            },
            softDelete: { id in
                let secret = try await deleteSecretUseCase.softDelete(id: id)
                await LiveUseCases.expirySchedule.cancel(secretID: secret.id)
                return secret
            },
            restore: { id in
                let secret = try await deleteSecretUseCase.restore(id: id)
                await LiveUseCases.expirySchedule.schedule(secret: secret)
                return secret
            },
            permanentlyDelete: { id in
                try await deleteSecretUseCase.permanentlyDelete(id: id)
                await LiveUseCases.expirySchedule.cancel(secretID: id)
            },
            // 일괄 삭제엔 알림 취소가 불필요하다 — Expired는 마크가 전부 과거라 pending 알림이 없고,
            // Deleted는 소프트 삭제 시점에 이미 취소됐다(+ syncAll reconcile가 안전망).
            softDeleteAll: { collection in
                try await deleteSecretUseCase.softDeleteAll(in: collection)
            },
            permanentlyDeleteAll: { collection in
                try await deleteSecretUseCase.permanentlyDeleteAll(in: collection)
            },
            revealPayload: { secret, reason in
                try await dispatchPayload(
                    secret: secret,
                    access: .reveal(revealSecretPayloadUseCase, reason: reason)
                )
            },
            loadPayloadForCopy: { secret in
                try await dispatchPayload(
                    secret: secret,
                    access: .copy(decryptSecretPayloadUseCase)
                )
            },
            setLiked: { id, liked in
                try await patchSecretUseCase.updateSimple(
                    id: id,
                    with: SecretPatch(liked: .set(liked))
                )
            },
            updateSecret: { id, patch, change, projectIds in
                let updated = try await dispatchUpdateSecret(
                    useCase: patchSecretUseCase,
                    id: id,
                    patch: patch,
                    change: change,
                    projectIDs: projectIds
                )
                // 만료일이 바뀌었을 수 있다. `schedule`은 예약 전에 이전 마크를 먼저 취소하므로
                // 만료일을 지운 경우의 정리까지 같은 호출이 처리한다.
                await LiveUseCases.expirySchedule.schedule(secret: updated)
                return updated
            },
            fetchLinkedProjects: { secretID in
                try await fetchSecretUseCase.fetchProjects(secretID: secretID)
            },
            authenticate: { reason in
                try await authenticateUseCase.authenticate(reason: reason)
            },
            copySensitiveValue: { value in
                try await LiveUseCases.copyToClipboard.execute(value, policy: .sensitive)
            },
            copyPlainValue: { value in
                try await LiveUseCases.copyToClipboard.execute(value, policy: .plain)
            },
            fetchProjects: {
                try await fetchProjectUseCase.fetchAll()
            },
            createProject: { name in
                try await createProjectUseCase.execute(name: name)
            },
            linkProject: { secretID, projectID in
                try await relationUseCase.link(secretID: secretID, projectID: projectID)
            }
        )
    }()
}

// MARK: - Update Dispatch

/// `dispatchCreateSecret`과 같은 이유로 존재한다 — 도메인 overload가 제네릭이라 Client 경계를
/// 넘지 못하고, 구체 payload·metadata 타입은 `CreateSecretPayload`의 case에서만 나온다.
private func dispatchUpdateSecret(
    useCase: any PatchSecretUseCase,
    id: UUID,
    patch: SecretPatch,
    change: SecretContentChange,
    projectIDs: PatchField<[UUID]>
) async throws -> Secret {
    // metadata 삭제는 overload가 아니라 patch로 표현한다 — metadata overload는 값을 요구해
    // nil을 실을 수 없는 반면 `SecretPatch.metadata`는 `.set(nil)`을 지원한다.
    let effectivePatch: SecretPatch = {
        guard change.clearsMetadata else { return patch }
        var next = patch
        next.metadata = .set(nil)
        return next
    }()

    /// metadata 스키마가 있는 9개 타입용.
    func write<Payload: SecretPayloadData, Metadata: SecretMetadataContent>(
        _ payload: Payload,
        _ metadata: Metadata?
    ) async throws -> Secret {
        // 폼이 metadata의 모든 필드를 비우면 조립 결과가 nil이 된다. 그 삭제는 위 patch가
        // 이미 처리했으므로 여기서는 값이 있을 때만 metadata overload로 간다.
        switch (change.writesPayload, change.writesMetadata ? metadata : nil) {
        case (true, let metadata?):
            return try await useCase.update(
                id: id, patch: effectivePatch, payload: payload, metadata: metadata, projectIDs: projectIDs
            )
        case (true, nil):
            return try await useCase.update(
                id: id, patch: effectivePatch, payload: payload, projectIDs: projectIDs
            )
        case (false, let metadata?):
            return try await useCase.update(
                id: id, patch: effectivePatch, metadata: metadata, projectIDs: projectIDs
            )
        case (false, nil):
            return try await useCase.update(id: id, patch: effectivePatch, projectIDs: projectIDs)
        }
    }

    /// metadata 스키마 자체가 없는 타입용(envSet · custom).
    func write<Payload: SecretPayloadData>(_ payload: Payload) async throws -> Secret {
        guard change.writesPayload else {
            return try await useCase.update(id: id, patch: effectivePatch, projectIDs: projectIDs)
        }
        return try await useCase.update(
            id: id, patch: effectivePatch, payload: payload, projectIDs: projectIDs
        )
    }

    // 다시 쓸 내용이 없으면 공통 필드·프로젝트 연결만 반영한다(metadata 삭제 포함).
    guard let content = change.content else {
        return try await useCase.update(id: id, patch: effectivePatch, projectIDs: projectIDs)
    }

    switch content {
    case .apiKey(let payload, let metadata),
         .accessToken(let payload, let metadata),
         .webhookSecret(let payload, let metadata):
        return try await write(payload, metadata)

    case .oauthClient(let payload, let metadata):
        return try await write(payload, metadata)

    case .serviceAccount(let payload, let metadata):
        return try await write(payload, metadata)

    case .database(let payload, let metadata):
        return try await write(payload, metadata)

    case .sshKey(let payload, let metadata):
        return try await write(payload, metadata)

    case .sslTlsCertificate(let payload, let metadata):
        return try await write(payload, metadata)

    case .licenseKey(let payload, let metadata):
        return try await write(payload, metadata)

    case .environmentVariableSet(let payload):
        return try await write(payload)

    case .custom(let payload):
        return try await write(payload)
    }
}

// MARK: - Payload Dispatch

private enum PayloadAccess {
    /// 열람·수정 진입. 인증을 타므로 시스템 시트에 띄울 사유를 함께 받는다 —
    /// 같은 복호화라도 사용자가 누른 버튼이 다르면 기대하는 문장이 다르다.
    case reveal(any RevealSecretPayloadUseCase, reason: AuthenticationReason)
    /// 복사. 인증 여부는 이어지는 `copySensitiveValue`가 설정을 읽어 결정하므로 여기서는 복호화만 한다.
    case copy(any DecryptSecretPayloadUseCase)

    func load<Payload: SecretPayloadData>(
        id: UUID,
        as type: Payload.Type
    ) async throws -> Payload {
        switch self {
        case .reveal(let useCase, let reason):
            return try await useCase.revealPayload(id: id, as: type, reason: reason)
        case .copy(let useCase):
            return try await useCase.decryptPayload(id: id, as: type)
        }
    }
}

private func dispatchPayload(
    secret: Secret,
    access: PayloadAccess
) async throws -> CreateSecretPayload {
    func decodeMeta<M: SecretMetadataContent>(_ type: M.Type) -> M? {
        secret.decodedMetadata(type)
    }

    switch (secret.secretType, secret.subType) {
    case (.apiKeyToken, .apiKey), (.apiKeyToken, nil):
        let p = try await access.load(id: secret.id, as: APIKeyPayload.self)
        return .apiKey(p, decodeMeta(APIKeyMetadata.self))
    case (.apiKeyToken, .accessToken):
        let p = try await access.load(id: secret.id, as: APIKeyPayload.self)
        return .accessToken(p, decodeMeta(APIKeyMetadata.self))
    case (.apiKeyToken, .webhookSecret):
        let p = try await access.load(id: secret.id, as: APIKeyPayload.self)
        return .webhookSecret(p, decodeMeta(APIKeyMetadata.self))
    case (.oauth, .oauthClient), (.oauth, nil):
        let p = try await access.load(id: secret.id, as: OAuthClientPayload.self)
        return .oauthClient(p, decodeMeta(OAuthClientMetadata.self))
    case (.oauth, .serviceAccount):
        let p = try await access.load(id: secret.id, as: ServiceAccountPayload.self)
        return .serviceAccount(p, decodeMeta(ServiceAccountMetadata.self))
    case (.database, _):
        let p = try await access.load(id: secret.id, as: DatabasePayload.self)
        return .database(p, decodeMeta(DatabaseMetadata.self))
    case (.sshAndCredentials, .sshKey), (.sshAndCredentials, nil):
        let p = try await access.load(id: secret.id, as: SSHKeyPayload.self)
        return .sshKey(p, decodeMeta(SSHKeyMetadata.self))
    case (.sshAndCredentials, .sslTlsCertificate):
        let p = try await access.load(id: secret.id, as: SSLCertPayload.self)
        return .sslTlsCertificate(p, decodeMeta(SSLCertMetadata.self))
    case (.environmentVariableSet, _):
        let p = try await access.load(id: secret.id, as: EnvSetPayload.self)
        return .environmentVariableSet(p)
    case (.etc, .licenseKey), (.etc, nil):
        let p = try await access.load(id: secret.id, as: LicenseKeyPayload.self)
        return .licenseKey(p, decodeMeta(LicenseKeyMetadata.self))
    case (.etc, .custom):
        let p = try await access.load(id: secret.id, as: CustomPayload.self)
        return .custom(p)
    default:
        assertionFailure("Unexpected (secretType, subType) combination: \(secret.secretType), \(String(describing: secret.subType))")
        throw SecretUseCaseError.unexpected
    }
}
