// Copyright © 2026 Devault. All rights reserved

import ComposableArchitecture
import DVCore
import DVDomain
import Foundation

/// Secret 생성/편집/삭제 Flow에서 소비하는 Client.
/// Live 조립은 Devault(App 타겟)에서 `CreateSecretUseCase.execute`의 두 overload를 `CreateSecretPayload` case 분기로 호출.
@DependencyClient
public struct SecretManagementClient: Sendable {
    
    /// Secret을 생성하고 지정된 Project들에 연결한다.
    /// `CreateSecretPayload` case에 따라 metadata 유무를 판단, 도메인 UseCase 두 overload 중 하나로 dispatch.
    public var createSecret: @Sendable (
        _ draft: SecretDraft,
        _ payload: CreateSecretPayload,
        _ projectIds: [UUID]
    ) async throws -> Secret

    /// 같은 타입에 같은 이름의 시크릿이 이미 있는지 확인한다. 생성·수정의 저장 직전 가드용이며, `excludingID`는 수정 화면이 자기 자신을 뺄 때만 채운다.
    public var isNameDuplicated: @Sendable (
        _ name: String,
        _ secretType: SecretType,
        _ excludingID: Secret.ID?
    ) async throws -> Bool
}

extension SecretManagementClient: TestDependencyKey {
    public static let testValue = SecretManagementClient()
    
    public static let previewValue = SecretManagementClient(
        createSecret: { draft, payload, projectIds in
            Log.info(
                """
                [Preview mock] SecretManagementClient.createSecret 호출됨
                  name: \(draft.name)
                  secretType: \(draft.secretType)
                  subType: \(draft.subType.map { String(describing: $0) } ?? "nil")
                  service: \(draft.service ?? "nil")
                  environment: \(draft.environment ?? "nil")
                  expiresAt: \(draft.expiresAt.map { String(describing: $0) } ?? "nil")
                  memo: \(draft.memo ?? "nil")
                  payload: \(payload)
                  projectIds: \(projectIds)
                """,
                category: .domain
            )
            return Secret(
                id: UUID(),
                name: draft.name,
                secretType: draft.secretType,
                subType: draft.subType,
                service: draft.service,
                environment: draft.environment,
                expiresAt: draft.expiresAt,
                memo: draft.memo,
                liked: draft.liked,
                createdAt: Date(),
                updatedAt: Date(),
                payload: SecretPayload(
                    encryptedData: Data(),
                    keyTag: "preview",
                    schemaVersion: 1
                ),
                metadata: nil
            )
        },
        isNameDuplicated: { _, _, _ in false }
    )
}

extension DependencyValues {
    public var secretManagementClient: SecretManagementClient {
        get { self[SecretManagementClient.self] }
        set { self[SecretManagementClient.self] = newValue }
    }
}
