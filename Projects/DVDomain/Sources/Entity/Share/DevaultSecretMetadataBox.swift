// Copyright © 2026 Devault. All rights reserved

public enum DevaultSecretMetadataBox: Equatable, Sendable, Codable {
    case apiKey(APIKeyMetadata)
    case accessToken(APIKeyMetadata)
    case webhookSecret(APIKeyMetadata)
    case oauthClient(OAuthClientMetadata)
    case serviceAccount(ServiceAccountMetadata)
    case sshKey(SSHKeyMetadata)
    case sslTlsCertificate(SSLCertMetadata)
    case licenseKey(LicenseKeyMetadata)
    case database(DatabaseMetadata)
}
