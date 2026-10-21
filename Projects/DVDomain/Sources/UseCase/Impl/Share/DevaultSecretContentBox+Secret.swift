// Copyright © 2026 Devault. All rights reserved

import Foundation

extension DevaultSecretContentBox {

    /// 저장된 Secret의 payload·metadata를 복호화해 `.dvt`에 담을 content로 묶는다.
    ///
    /// `(secretType, subType)` 쌍으로 어느 payload 타입인지 정해진다 — 그 쌍을 모르면 복호화할 타입을 고를 수 없으므로, 조합이 어긋난 Secret은 들고 있어도 내보낼 수 없다.
    /// - Parameters:
    ///   - secret: 내보낼 Secret
    ///   - cryptoService: payload 복호화·metadata 디코딩
    /// - Returns: content와 각 스키마 버전. metadata가 없으면 버전도 nil이다
    static func make(
        from secret: Secret,
        cryptoService: any SecretCryptoService
    ) async throws -> (content: Self, payloadSchemaVersion: Int, metadataSchemaVersion: Int?) {
        func decode<P: SecretPayloadData, M: SecretMetadataContent>(
            _ payloadType: P.Type,
            _ metadataType: M.Type,
            _ box: (P, M?) -> Self
        ) async throws -> (Self, Int, Int?) {
            let payload = try await cryptoService.decryptPayload(secret.payload, as: payloadType)
            let metadata = try secret.metadata.map { try cryptoService.decodeMetadata($0, as: metadataType) }
            return (box(payload, metadata), P.schemaVersion, metadata == nil ? nil : M.schemaVersion)
        }

        // metadata를 받지 않는 case — 박스가 payload만 담으므로 디코딩 자체를 하지 않는다.
        func decodeWithoutMetadata<P: SecretPayloadData>(
            _ payloadType: P.Type,
            _ box: (P) -> Self
        ) async throws -> (Self, Int, Int?) {
            let payload = try await cryptoService.decryptPayload(secret.payload, as: payloadType)
            return (box(payload), P.schemaVersion, nil)
        }

        switch (secret.secretType, secret.subType) {
        case (.apiKeyToken, .apiKey):
            return try await decode(APIKeyPayload.self, APIKeyMetadata.self, Self.apiKey)
        case (.apiKeyToken, .accessToken):
            return try await decode(APIKeyPayload.self, APIKeyMetadata.self, Self.accessToken)
        case (.apiKeyToken, .webhookSecret):
            return try await decode(APIKeyPayload.self, APIKeyMetadata.self, Self.webhookSecret)
        case (.oauth, .oauthClient):
            return try await decode(OAuthClientPayload.self, OAuthClientMetadata.self, Self.oauthClient)
        case (.oauth, .serviceAccount):
            return try await decode(ServiceAccountPayload.self, ServiceAccountMetadata.self, Self.serviceAccount)
        case (.sshAndCredentials, .sshKey):
            return try await decode(SSHKeyPayload.self, SSHKeyMetadata.self, Self.sshKey)
        case (.sshAndCredentials, .sslTlsCertificate):
            return try await decode(SSLCertPayload.self, SSLCertMetadata.self, Self.sslTlsCertificate)
        case (.etc, .licenseKey):
            return try await decode(LicenseKeyPayload.self, LicenseKeyMetadata.self, Self.licenseKey)
        case (.etc, .custom):
            return try await decodeWithoutMetadata(CustomPayload.self, Self.custom)
        case (.database, _):
            return try await decode(DatabasePayload.self, DatabaseMetadata.self, Self.database)
        case (.environmentVariableSet, _):
            return try await decodeWithoutMetadata(EnvSetPayload.self, Self.envSet)
        default:
            throw SecretUseCaseError.unexpected
        }
    }
}
