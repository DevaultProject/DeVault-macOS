// Copyright © 2026 Devault. All rights reserved

import Foundation

public struct SecretMetadata: Equatable, Sendable {
    public var metadataJSON: Data
    public var schemaVersion: Int

    public init(
        metadataJSON: Data,
        schemaVersion: Int
    ) {
        self.metadataJSON = metadataJSON
        self.schemaVersion = schemaVersion
    }
}
