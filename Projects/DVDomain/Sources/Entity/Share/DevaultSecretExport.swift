// Copyright © 2026 Devault. All rights reserved

public struct DevaultSecretExport: Equatable, Sendable, Codable {
    public var name: String
    public var service: String?
    public var environment: String?
    public var expiresAt: DevaultDateComponents?
    public var memo: String?
    public var liked: Bool
    public var content: DevaultSecretContentBox
    public var payloadSchemaVersion: Int
    public var metadataSchemaVersion: Int?

    public init(
        name: String,
        service: String? = nil,
        environment: String? = nil,
        expiresAt: DevaultDateComponents? = nil,
        memo: String? = nil,
        liked: Bool = false,
        content: DevaultSecretContentBox,
        payloadSchemaVersion: Int,
        metadataSchemaVersion: Int? = nil
    ) {
        self.name = name
        self.service = service
        self.environment = environment
        self.expiresAt = expiresAt
        self.memo = memo
        self.liked = liked
        self.content = content
        self.payloadSchemaVersion = payloadSchemaVersion
        self.metadataSchemaVersion = metadataSchemaVersion
    }
}
