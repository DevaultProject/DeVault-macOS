// Copyright © 2026 Devault. All rights reserved

/// payload와 metadata를 case마다 페어로 묶어, 서로 다른 타입끼리 잘못 조합되는 상태를 표현 자체가 안 되게 막는다.
/// `CreateSecretPayload`와 같은 패턴.
public enum DevaultSecretContentBox: Equatable, Sendable, Codable {
    case apiKey(APIKeyPayload, APIKeyMetadata?)
    case accessToken(APIKeyPayload, APIKeyMetadata?)
    case webhookSecret(APIKeyPayload, APIKeyMetadata?)
    case oauthClient(OAuthClientPayload, OAuthClientMetadata?)
    case serviceAccount(ServiceAccountPayload, ServiceAccountMetadata?)
    case sshKey(SSHKeyPayload, SSHKeyMetadata?)
    case sslTlsCertificate(SSLCertPayload, SSLCertMetadata?)
    case licenseKey(LicenseKeyPayload, LicenseKeyMetadata?)
    case custom(CustomPayload)
    case database(DatabasePayload, DatabaseMetadata?)
    case envSet(EnvSetPayload)
}
