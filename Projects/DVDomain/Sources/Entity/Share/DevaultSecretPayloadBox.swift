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
}
