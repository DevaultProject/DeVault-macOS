// Copyright © 2026 Devault. All rights reserved

import Testing
import Foundation

@testable import DVDomain

@Suite("DevaultContainerPayload")
struct DevaultContainerPayloadTests {

    @Test("여러 타입이 섞인 secrets 배열이 JSON 라운드트립된다")
    func roundTripsMixedSecretTypes() throws {
        let apiKeySecret = DevaultSecretExport(
            name: "GitHub Token",
            service: "github.com",
            environment: "production",
            expiresAt: DevaultDateComponents(year: 2026, month: 12, day: 31),
            memo: "메모",
            liked: true,
            content: .apiKey(APIKeyPayload(value: "ghp_1234"), APIKeyMetadata(scope: "repo:read")),
            payloadSchemaVersion: APIKeyPayload.schemaVersion,
            metadataSchemaVersion: APIKeyMetadata.schemaVersion
        )

        let databaseSecret = DevaultSecretExport(
            name: "Prod DB",
            // metadata 없음 — database도 metadata 타입은 있지만 이 시크릿엔 안 붙었다고 가정
            content: .database(DatabasePayload(linkString: "postgres://localhost"), nil),
            payloadSchemaVersion: DatabasePayload.schemaVersion
        )

        let customSecret = DevaultSecretExport(
            name: "Custom Note",
            // custom은 애초에 metadata 타입 자체가 없음
            content: .custom(CustomPayload(value: "free text")),
            payloadSchemaVersion: CustomPayload.schemaVersion
        )

        let payload = DevaultContainerPayload(
            projectName: "My Project",
            secrets: [apiKeySecret, databaseSecret, customSecret]
        )

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(DevaultContainerPayload.self, from: data)

        #expect(decoded == payload)
    }

    @Test("projectName이 nil이어도(멀티선택 export) 라운드트립된다")
    func roundTripsWithoutProjectName() throws {
        let secret = DevaultSecretExport(
            name: "Env",
            content: .envSet(EnvSetPayload(content: "KEY=1")),
            payloadSchemaVersion: EnvSetPayload.schemaVersion
        )
        let payload = DevaultContainerPayload(projectName: nil, secrets: [secret])

        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(DevaultContainerPayload.self, from: data)

        #expect(decoded == payload)
    }
}
