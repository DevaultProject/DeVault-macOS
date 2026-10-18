// Copyright © 2026 Devault. All rights reserved

import Testing
import Foundation

@testable import DVDomain

@Suite("DevaultSecretPayloadBox")
struct DevaultSecretPayloadBoxTests {

    private var allCases: [DevaultSecretPayloadBox] {
        [
            .apiKey(APIKeyPayload(value: "a")),
            .accessToken(APIKeyPayload(value: "b")),
            .webhookSecret(APIKeyPayload(value: "c")),
            .oauthClient(OAuthClientPayload(clientId: "id", clientSecret: "secret")),
            .serviceAccount(ServiceAccountPayload(credentialJSON: "{}")),
            .sshKey(SSHKeyPayload(privateKey: "key", passphrase: "pass")),
            .sslTlsCertificate(SSLCertPayload(certificate: "cert", privateKey: "key")),
            .licenseKey(LicenseKeyPayload(licenseKey: "XXXX-YYYY")),
            .custom(CustomPayload(value: "custom")),
            .database(DatabasePayload(linkString: "postgres://localhost")),
            .envSet(EnvSetPayload(content: "KEY=VALUE")),
        ]
    }

    @Test("9종 payload 전부 JSON 인코딩/디코딩 라운드트립된다")
    func roundTripsThroughJSON() throws {
        for box in allCases {
            let data = try JSONEncoder().encode(box)
            let decoded = try JSONDecoder().decode(DevaultSecretPayloadBox.self, from: data)
            #expect(decoded == box)
        }
    }

    @Test("subType이 database·envSet만 nil이고 나머지는 대응하는 값을 반환한다")
    func subTypeMapping() {
        #expect(DevaultSecretPayloadBox.apiKey(APIKeyPayload(value: "")).subType == .apiKey)
        #expect(DevaultSecretPayloadBox.accessToken(APIKeyPayload(value: "")).subType == .accessToken)
        #expect(DevaultSecretPayloadBox.webhookSecret(APIKeyPayload(value: "")).subType == .webhookSecret)
        #expect(
            DevaultSecretPayloadBox.oauthClient(OAuthClientPayload(clientId: "", clientSecret: "")).subType
                == .oauthClient
        )
        #expect(
            DevaultSecretPayloadBox.serviceAccount(ServiceAccountPayload(credentialJSON: "")).subType
                == .serviceAccount
        )
        #expect(DevaultSecretPayloadBox.sshKey(SSHKeyPayload(privateKey: "")).subType == .sshKey)
        #expect(
            DevaultSecretPayloadBox.sslTlsCertificate(SSLCertPayload(certificate: "", privateKey: "")).subType
                == .sslTlsCertificate
        )
        #expect(DevaultSecretPayloadBox.licenseKey(LicenseKeyPayload(licenseKey: "")).subType == .licenseKey)
        #expect(DevaultSecretPayloadBox.custom(CustomPayload(value: "")).subType == .custom)
        #expect(DevaultSecretPayloadBox.database(DatabasePayload(linkString: "")).subType == nil)
        #expect(DevaultSecretPayloadBox.envSet(EnvSetPayload(content: "")).subType == nil)
    }

    @Test("SecretSubType case 개수가 늘어나면 이 테스트가 실패해 DevaultSecretPayloadBox 갱신을 상기시킨다")
    func subTypeCaseCountGuard() {
        #expect(SecretSubType.allCases.count == 9)
    }

    @Test("고정된 JSON 포맷이 깨지지 않는다 — case 이름이 바뀌면 이미 내보낸 .dvt 파일이 깨진다")
    func pinnedJSONFormatDoesNotBreak() throws {
        let fixtures: [(json: String, expected: DevaultSecretPayloadBox)] = [
            (#"{"apiKey":{"_0":{"value":"a"}}}"#, .apiKey(APIKeyPayload(value: "a"))),
            (#"{"accessToken":{"_0":{"value":"b"}}}"#, .accessToken(APIKeyPayload(value: "b"))),
            (#"{"webhookSecret":{"_0":{"value":"c"}}}"#, .webhookSecret(APIKeyPayload(value: "c"))),
            (
                #"{"oauthClient":{"_0":{"clientId":"id","clientSecret":"secret"}}}"#,
                .oauthClient(OAuthClientPayload(clientId: "id", clientSecret: "secret"))
            ),
            (
                #"{"serviceAccount":{"_0":{"credentialJSON":"{}"}}}"#,
                .serviceAccount(ServiceAccountPayload(credentialJSON: "{}"))
            ),
            (
                #"{"sshKey":{"_0":{"privateKey":"key","passphrase":"pass"}}}"#,
                .sshKey(SSHKeyPayload(privateKey: "key", passphrase: "pass"))
            ),
            (
                #"{"sslTlsCertificate":{"_0":{"certificate":"cert","privateKey":"key"}}}"#,
                .sslTlsCertificate(SSLCertPayload(certificate: "cert", privateKey: "key"))
            ),
            (#"{"licenseKey":{"_0":{"licenseKey":"XXXX-YYYY"}}}"#, .licenseKey(LicenseKeyPayload(licenseKey: "XXXX-YYYY"))),
            (#"{"custom":{"_0":{"value":"custom"}}}"#, .custom(CustomPayload(value: "custom"))),
            (
                #"{"database":{"_0":{"linkString":"postgres://localhost"}}}"#,
                .database(DatabasePayload(linkString: "postgres://localhost"))
            ),
            (#"{"envSet":{"_0":{"content":"KEY=VALUE"}}}"#, .envSet(EnvSetPayload(content: "KEY=VALUE"))),
        ]

        for fixture in fixtures {
            let decoded = try JSONDecoder().decode(DevaultSecretPayloadBox.self, from: Data(fixture.json.utf8))
            #expect(decoded == fixture.expected)
        }
    }

    @Test("secretType이 subType 없는 타입(database·envSet)도 올바르게 반환한다")
    func secretTypeMapping() {
        #expect(DevaultSecretPayloadBox.database(DatabasePayload(linkString: "")).secretType == .database)
        #expect(DevaultSecretPayloadBox.envSet(EnvSetPayload(content: "")).secretType == .environmentVariableSet)
        #expect(DevaultSecretPayloadBox.apiKey(APIKeyPayload(value: "")).secretType == .apiKeyToken)
    }
}
