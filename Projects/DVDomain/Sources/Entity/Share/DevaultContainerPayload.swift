// Copyright © 2026 Devault. All rights reserved

public struct DevaultContainerPayload: Equatable, Sendable, Codable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    /// Secret↔Project는 M:N인데 컨테이너는 단일 이름만 담는다 — 멀티선택 export는 이 정보가 버려진다.
    public var projectName: String?
    public var secrets: [DevaultSecretExport]

    public init(
        schemaVersion: Int = DevaultContainerPayload.currentSchemaVersion,
        projectName: String? = nil,
        secrets: [DevaultSecretExport]
    ) {
        self.schemaVersion = schemaVersion
        self.projectName = projectName
        self.secrets = secrets
    }
}
