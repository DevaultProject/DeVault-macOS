// Copyright © 2026 Devault. All rights reserved

import Foundation

public struct CreateSecretUseCaseImpl: CreateSecretUseCase {
    private let repository: any SecretRepository
    private let cryptoService: any SecretCryptoService
    private let entitlementUseCase: any EntitlementUseCase
    private let idGenerator: @Sendable () -> UUID
    private let dateProvider: @Sendable () -> Date

    /// - Parameters:
    ///   - repository: Secret 저장소
    ///   - cryptoService: payload 암호화·metadata 인코딩
    ///   - entitlementUseCase: 무료 티어 한도 판정. **기본값을 두지 않는다** — 빠뜨리면 가드가 조용히 사라진다
    ///   - idGenerator: 새 Secret의 ID
    ///   - dateProvider: 생성·수정 시각
    public init(
        repository: any SecretRepository,
        cryptoService: any SecretCryptoService,
        entitlementUseCase: any EntitlementUseCase,
        idGenerator: @escaping @Sendable () -> UUID = { UUID() },
        dateProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.repository = repository
        self.cryptoService = cryptoService
        self.entitlementUseCase = entitlementUseCase
        self.idGenerator = idGenerator
        self.dateProvider = dateProvider
    }

    /// 한도를 지키며 저장한다. 앞선 판정 뒤 암호화가 끼어 있어, 동시 생성이 같은 개수를 보고 통과할 수 있으므로 다시 지킨다.
    ///
    /// 실제 판정은 저장소가 세기와 넣기를 한 번에 처리하며 내린다. 여기서는 Pro를 무한대로 바꿔 넘기는 것뿐이다.
    /// - Parameters:
    ///   - secret: 저장할 Secret
    ///   - projectIDs: 연결할 Project ID 목록
    /// - Returns: 저장된 Secret
    private func persist(_ secret: Secret, projectIDs: [UUID]) async throws -> Secret {
        let limit = entitlementUseCase.current() == .free ? EntitlementLimits.maxSecrets : Int.max
        guard let created = try await repository.create(
            secret,
            projectIDs: projectIDs,
            withinTotalLimit: limit
        ) else {
            throw EntitlementError.limitReached
        }
        return created
    }

    public func execute<Payload: SecretPayloadData>(
        draft: SecretDraft,
        payload: Payload,
        projectIDs: [UUID]
    ) async throws -> Secret {
        // 거부될 생성에 암호화를 들이지 않도록 먼저 판정한다.
        try await entitlementUseCase.ensureCanCreateSecret()

        do {
            let draft = try SecretUseCaseHelper.normalizedDraft(draft)
            let now = dateProvider()
            let encryptedPayload = try await cryptoService.encryptPayload(payload)
            let secret = Secret(
                id: idGenerator(),
                name: draft.name,
                secretType: draft.secretType,
                subType: draft.subType,
                service: draft.service,
                environment: draft.environment,
                expiresAt: draft.expiresAt,
                memo: draft.memo,
                liked: draft.liked,
                createdAt: now,
                updatedAt: now,
                payload: encryptedPayload
            )
            return try await persist(secret, projectIDs: projectIDs)
        } catch let error as EntitlementError {
            // 게이트 차단은 도메인 오류로 접지 않는다 — 접으면 호출부가 페이월을 띄울 근거를 잃는다.
            throw error
        } catch {
            throw SecretUseCaseError.map(error)
        }
    }

    public func execute<Payload: SecretPayloadData, Metadata: SecretMetadataContent>(
        draft: SecretDraft,
        payload: Payload,
        metadata: Metadata,
        projectIDs: [UUID]
    ) async throws -> Secret {
        try await entitlementUseCase.ensureCanCreateSecret()

        do {
            let draft = try SecretUseCaseHelper.normalizedDraft(draft)
            let now = dateProvider()
            let encryptedPayload = try await cryptoService.encryptPayload(payload)
            let encodedMetadata = try cryptoService.encodeMetadata(metadata)
            let secret = Secret(
                id: idGenerator(),
                name: draft.name,
                secretType: draft.secretType,
                subType: draft.subType,
                service: draft.service,
                environment: draft.environment,
                expiresAt: draft.expiresAt,
                memo: draft.memo,
                liked: draft.liked,
                createdAt: now,
                updatedAt: now,
                payload: encryptedPayload,
                metadata: encodedMetadata
            )
            return try await persist(secret, projectIDs: projectIDs)
        } catch let error as EntitlementError {
            // 게이트 차단은 도메인 오류로 접지 않는다 — 접으면 호출부가 페이월을 띄울 근거를 잃는다.
            throw error
        } catch {
            throw SecretUseCaseError.map(error)
        }
    }
}
