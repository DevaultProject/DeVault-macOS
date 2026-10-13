// Copyright © 2026 Devault. All rights reserved

import Foundation

public struct Secret: Equatable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    public var secretType: SecretType
    public var subType: SecretSubType?
    public var service: String?
    public var environment: String?
    public var expiresAt: Date?
    public var memo: String?
    public var liked: Bool
    public var deletedAt: Date?
    public var createdAt: Date
    public var updatedAt: Date
    public var payload: SecretPayload
    public var metadata: SecretMetadata?

    public init(
        id: UUID,
        name: String,
        secretType: SecretType,
        subType: SecretSubType? = nil,
        service: String? = nil,
        environment: String? = nil,
        expiresAt: Date? = nil,
        memo: String? = nil,
        liked: Bool = false,
        deletedAt: Date? = nil,
        createdAt: Date,
        updatedAt: Date,
        payload: SecretPayload,
        metadata: SecretMetadata? = nil
    ) {
        self.id = id
        self.name = name
        self.secretType = secretType
        self.subType = subType
        self.service = service
        self.environment = environment
        self.expiresAt = expiresAt
        self.memo = memo
        self.liked = liked
        self.deletedAt = deletedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.payload = payload
        self.metadata = metadata
    }
}
