// Copyright © 2026 Devault. All rights reserved

import Testing
import Foundation

@testable import DVDomain

@Suite("DevaultSecretContentBox")
struct DevaultSecretContentBoxTests {

    private var allCases: [DevaultSecretContentBox] {
        [
            .apiKey(APIKeyPayload(value: "a"), APIKeyMetadata(scope: "repo:read")),
            .accessToken(APIKeyPayload(value: "b"), APIKeyMetadata(scope: "user:email")),
            .webhookSecret(APIKeyPayload(value: "c"), nil),
            .oauthClient(
                OAuthClientPayload(clientId: "id", clientSecret: "secret"),
                OAuthClientMetadata(redirectUri: "https://example.com", scopes: "read write")
            ),
            .serviceAccount(
                ServiceAccountPayload(credentialJSON: "{}"),
                ServiceAccountMetadata(projectId: "proj", accountEmail: "a@b.com", authority: "owner")
            ),
            .sshKey(
                SSHKeyPayload(privateKey: "key", passphrase: "pass"),
                SSHKeyMetadata(publicKey: "ssh-ed25519 AAAA", keyType: "ed25519", host: "example.com", username: "root")
            ),
            .sslTlsCertificate(
                SSLCertPayload(certificate: "cert", privateKey: "key"),
                SSLCertMetadata(domain: "example.com", issuer: "Let's Encrypt", renewCommand: "certbot renew")
            ),
            .licenseKey(LicenseKeyPayload(licenseKey: "XXXX-YYYY"), nil),
            .custom(CustomPayload(value: "custom")),
            .database(
                DatabasePayload(linkString: "postgres://localhost"),
                DatabaseMetadata(host: "localhost", port: 5432, databaseName: "db", username: "root", sslRequired: true)
            ),
            .envSet(EnvSetPayload(content: "KEY=VALUE")),
        ]
    }

    @Test("11종 payload·metadata 페어가 전부 JSON 인코딩/디코딩 라운드트립된다 — metadata가 nil인 케이스도 포함")
    func roundTripsThroughJSON() throws {
        for box in allCases {
            let data = try JSONEncoder().encode(box)
            let decoded = try JSONDecoder().decode(DevaultSecretContentBox.self, from: data)
            #expect(decoded == box)
        }
    }

    @Test("고정된 JSON 포맷이 깨지지 않는다 — case 이름이 바뀌면 이미 내보낸 .dvt 파일이 깨진다")
    func pinnedJSONFormatDoesNotBreak() throws {
        let fixtures: [(json: String, expected: DevaultSecretContentBox)] = [
            (#"{"apiKey":{"_0":{"value":"a"},"_1":{"scope":"repo:read"}}}"#, allCases[0]),
            (#"{"accessToken":{"_0":{"value":"b"},"_1":{"scope":"user:email"}}}"#, allCases[1]),
            (#"{"webhookSecret":{"_0":{"value":"c"}}}"#, allCases[2]),
            (
                #"{"oauthClient":{"_0":{"clientId":"id","clientSecret":"secret"},"_1":{"redirectUri":"https://example.com","scopes":"read write"}}}"#,
                allCases[3]
            ),
            (
                #"{"serviceAccount":{"_0":{"credentialJSON":"{}"},"_1":{"accountEmail":"a@b.com","authority":"owner","projectId":"proj"}}}"#,
                allCases[4]
            ),
            (
                #"{"sshKey":{"_0":{"passphrase":"pass","privateKey":"key"},"_1":{"host":"example.com","keyType":"ed25519","publicKey":"ssh-ed25519 AAAA","username":"root"}}}"#,
                allCases[5]
            ),
            (
                #"{"sslTlsCertificate":{"_0":{"certificate":"cert","privateKey":"key"},"_1":{"domain":"example.com","issuer":"Let's Encrypt","renewCommand":"certbot renew"}}}"#,
                allCases[6]
            ),
            (#"{"licenseKey":{"_0":{"licenseKey":"XXXX-YYYY"}}}"#, allCases[7]),
            (#"{"custom":{"_0":{"value":"custom"}}}"#, allCases[8]),
            (
                #"{"database":{"_0":{"linkString":"postgres://localhost"},"_1":{"databaseName":"db","host":"localhost","port":5432,"sslRequired":true,"username":"root"}}}"#,
                allCases[9]
            ),
            (#"{"envSet":{"_0":{"content":"KEY=VALUE"}}}"#, allCases[10]),
        ]

        for fixture in fixtures {
            let decoded = try JSONDecoder().decode(DevaultSecretContentBox.self, from: Data(fixture.json.utf8))
            #expect(decoded == fixture.expected)
        }
    }
}
