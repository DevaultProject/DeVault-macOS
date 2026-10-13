// Copyright © 2026 Devault. All rights reserved

public enum DevaultSecretPayloadBox: Equatable, Sendable, Codable {
    case apiKey(APIKeyPayload)
    case accessToken(APIKeyPayload)
    case webhookSecret(APIKeyPayload)
    case oauthClient(OAuthClientPayload)
    case serviceAccount(ServiceAccountPayload)
    case sshKey(SSHKeyPayload)
    case sslTlsCertificate(SSLCertPayload)
    case licenseKey(LicenseKeyPayload)
    case custom(CustomPayload)
    case database(DatabasePayload)
    case envSet(EnvSetPayload)

    public var subType: SecretSubType? {
        switch self {
        case .apiKey: return .apiKey
        case .accessToken: return .accessToken
        case .webhookSecret: return .webhookSecret
        case .oauthClient: return .oauthClient
        case .serviceAccount: return .serviceAccount
        case .sshKey: return .sshKey
        case .sslTlsCertificate: return .sslTlsCertificate
        case .licenseKey: return .licenseKey
        case .custom: return .custom
        case .database, .envSet: return nil
        }
    }

    public var secretType: SecretType {
        switch self {
        case .database: return .database
        case .envSet: return .environmentVariableSet
        default: return subType!.secretType
        }
    }
}
