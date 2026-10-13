// Copyright © 2026 Devault. All rights reserved

import Foundation

public struct SecretPayload: Equatable, Sendable {
    public var encryptedData: Data
    public var keyTag: String
    public var schemaVersion: Int

    public init(
        encryptedData: Data,
        keyTag: String,
        schemaVersion: Int
    ) {
        self.encryptedData = encryptedData
        self.keyTag = keyTag
        self.schemaVersion = schemaVersion
    }
}
