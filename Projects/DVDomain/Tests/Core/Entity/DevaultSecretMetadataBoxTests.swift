// Copyright © 2026 Devault. All rights reserved

import Testing
import Foundation

@testable import DVDomain

@Suite("DevaultSecretMetadataBox")
struct DevaultSecretMetadataBoxTests {

    private var allCases: [DevaultSecretMetadataBox] {
        [
            .apiKey(APIKeyMetadata(scope: "repo:read")),
            .accessToken(APIKeyMetadata(scope: "user:email")),
            .webhookSecret(APIKeyMetadata()),
            .oauthClient(OAuthClientMetadata(redirectUri: "https://example.com", scopes: "read write")),
            .serviceAccount(ServiceAccountMetadata(projectId: "proj", accountEmail: "a@b.com", authority: "owner")),
            .sshKey(SSHKeyMetadata(publicKey: "ssh-ed25519 AAAA", keyType: "ed25519", host: "example.com", username: "root")),
            .sslTlsCertificate(SSLCertMetadata(domain: "example.com", issuer: "Let's Encrypt", renewCommand: "certbot renew")),
            .licenseKey(LicenseKeyMetadata(licenseType: "pro", registrationEmail: "a@b.com", orderNumber: "123", website: "https://example.com")),
            .database(DatabaseMetadata(host: "localhost", port: 5432, databaseName: "db", username: "root", sslRequired: true)),
        ]
    }

    @Test("9종 metadata 전부 JSON 인코딩/디코딩 라운드트립된다")
    func roundTripsThroughJSON() throws {
        for box in allCases {
            let data = try JSONEncoder().encode(box)
            let decoded = try JSONDecoder().decode(DevaultSecretMetadataBox.self, from: data)
            #expect(decoded == box)
        }
    }
}
