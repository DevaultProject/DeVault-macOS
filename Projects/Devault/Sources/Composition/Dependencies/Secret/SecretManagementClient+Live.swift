// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVData
import DVDomain
import DVPresentation
import Foundation

extension SecretManagementClient: @retroactive DependencyKey {
    public static let liveValue: SecretManagementClient = {
        let cryptoService: any SecretCryptoService = SecretCryptoServiceImpl()
        let createUseCase: any CreateSecretUseCase = CreateSecretUseCaseImpl(
            repository: LiveRepositories.secret,
            cryptoService: cryptoService,
            entitlementUseCase: LiveUseCases.entitlement
        )
        let fetchUseCase: any FetchSecretUseCase = FetchSecretUseCaseImpl(
            repository: LiveRepositories.secret
        )
        return SecretManagementClient(
            createSecret: { draft, payload, projectIds in
                let secret = try await dispatchCreateSecret(
                    useCase: createUseCase,
                    draft: draft,
                    payload: payload,
                    projectIDs: projectIds
                )
                await LiveUseCases.expirySchedule.schedule(secret: secret)
                return secret
            },
            isNameDuplicated: { name, secretType, excludingID in
                try await fetchUseCase.isNameDuplicated(
                    name: name,
                    secretType: secretType,
                    excludingID: excludingID
                )
            }
        )
    }()
}

private func dispatchCreateSecret(
    useCase: any CreateSecretUseCase,
    draft: SecretDraft,
    payload: CreateSecretPayload,
    projectIDs: [UUID]
) async throws -> Secret {
    switch payload {
    case .apiKey(let p, let meta):
        if let meta { return try await useCase.execute(draft: draft, payload: p, metadata: meta, projectIDs: projectIDs) }
        return try await useCase.execute(draft: draft, payload: p, projectIDs: projectIDs)

    case .accessToken(let p, let meta):
        if let meta { return try await useCase.execute(draft: draft, payload: p, metadata: meta, projectIDs: projectIDs) }
        return try await useCase.execute(draft: draft, payload: p, projectIDs: projectIDs)

    case .webhookSecret(let p, let meta):
        if let meta { return try await useCase.execute(draft: draft, payload: p, metadata: meta, projectIDs: projectIDs) }
        return try await useCase.execute(draft: draft, payload: p, projectIDs: projectIDs)

    case .oauthClient(let p, let meta):
        if let meta { return try await useCase.execute(draft: draft, payload: p, metadata: meta, projectIDs: projectIDs) }
        return try await useCase.execute(draft: draft, payload: p, projectIDs: projectIDs)

    case .serviceAccount(let p, let meta):
        if let meta { return try await useCase.execute(draft: draft, payload: p, metadata: meta, projectIDs: projectIDs) }
        return try await useCase.execute(draft: draft, payload: p, projectIDs: projectIDs)

    case .database(let p, let meta):
        if let meta { return try await useCase.execute(draft: draft, payload: p, metadata: meta, projectIDs: projectIDs) }
        return try await useCase.execute(draft: draft, payload: p, projectIDs: projectIDs)

    case .sshKey(let p, let meta):
        if let meta { return try await useCase.execute(draft: draft, payload: p, metadata: meta, projectIDs: projectIDs) }
        return try await useCase.execute(draft: draft, payload: p, projectIDs: projectIDs)

    case .sslTlsCertificate(let p, let meta):
        if let meta { return try await useCase.execute(draft: draft, payload: p, metadata: meta, projectIDs: projectIDs) }
        return try await useCase.execute(draft: draft, payload: p, projectIDs: projectIDs)

    case .environmentVariableSet(let p):
        return try await useCase.execute(draft: draft, payload: p, projectIDs: projectIDs)

    case .licenseKey(let p, let meta):
        // SecretMetaFields+Mapping.swift의 licenseKeyMetadata는 non-optional이므로 실제로 nil에 도달하지 않음
        if let meta { return try await useCase.execute(draft: draft, payload: p, metadata: meta, projectIDs: projectIDs) }
        return try await useCase.execute(draft: draft, payload: p, projectIDs: projectIDs)

    case .custom(let p):
        return try await useCase.execute(draft: draft, payload: p, projectIDs: projectIDs)
    }
}
