// Copyright © 2026 Devault. All rights reserved

import Foundation

public struct DevaultContainerHeader: Equatable, Sendable {
    public static let magic: [UInt8] = Array("DEVAULT".utf8)
    public static let currentVersion: UInt16 = 1
    public static let saltByteCount = 16
    public static let nonceByteCount = 12
    private static let versionByteCount = MemoryLayout<UInt16>.size
    private static let expiresAtByteCount = MemoryLayout<UInt64>.size
    public static let byteCount = magic.count + versionByteCount + expiresAtByteCount + saltByteCount + nonceByteCount

    public var version: UInt16
    public var expiresAt: Date?
    public var salt: Data
    public var nonce: Data

    public init(
        version: UInt16,
        expiresAt: Date?,
        salt: Data,
        nonce: Data
    ) {
        self.version = version
        self.expiresAt = expiresAt
        self.salt = salt
        self.nonce = nonce
    }
}
