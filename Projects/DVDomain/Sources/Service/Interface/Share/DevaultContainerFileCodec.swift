// Copyright © 2026 Devault. All rights reserved

import Foundation

/// `.dvt` 컨테이너의 45바이트 헤더 + 암호문을 바이트로 조립/분리한다.
///
/// 레이아웃(고정 45바이트): magic(7) + version(2, big-endian) + expiresAt(8, unix seconds·big-endian·0=영구) + salt(16) + nonce(12).
public enum DevaultContainerFileCodec {

    public static func encode(header: DevaultContainerHeader, ciphertext: Data) -> Data {
        encodeHeader(header) + ciphertext
    }

    public static func decode(_ data: Data, now: Date = Date()) throws -> DevaultContainerFile {
        guard data.count >= DevaultContainerHeader.byteCount else {
            throw DevaultImportError.corrupted
        }

        let header = try decodeHeader(Array(data.prefix(DevaultContainerHeader.byteCount)), now: now)
        let ciphertext = Data(data.dropFirst(DevaultContainerHeader.byteCount))

        return DevaultContainerFile(header: header, ciphertext: ciphertext)
    }

    public static func encodeHeader(_ header: DevaultContainerHeader) -> Data {
        encodeHeaderPrefix(version: header.version, expiresAt: header.expiresAt, salt: header.salt) + header.nonce
    }

    /// nonce 확정 전에 AAD로 써야 해서 헤더에서 nonce만 뺀 33바이트.
    public static func encodeHeaderPrefix(version: UInt16, expiresAt: Date?, salt: Data) -> Data {
        var bytes = Data()
        bytes.append(contentsOf: DevaultContainerHeader.magic)
        bytes.append(contentsOf: bigEndianBytes(version))
        bytes.append(contentsOf: bigEndianBytes(unixSeconds(expiresAt)))
        bytes.append(salt)
        return bytes
    }

    private static func decodeHeader(_ bytes: [UInt8], now: Date) throws -> DevaultContainerHeader {
        var cursor = 0

        let magicCount = DevaultContainerHeader.magic.count
        guard Array(bytes[cursor..<cursor + magicCount]) == DevaultContainerHeader.magic else {
            throw DevaultImportError.corrupted
        }
        cursor += magicCount

        let version = uint16(fromBigEndianBytes: bytes[cursor..<cursor + 2])
        guard version == DevaultContainerHeader.currentVersion else {
            throw DevaultImportError.versionMismatch
        }
        cursor += 2

        let expiresAtSeconds = uint64(fromBigEndianBytes: bytes[cursor..<cursor + 8])
        let expiresAt = date(fromUnixSeconds: expiresAtSeconds)
        cursor += 8

        if let expiresAt, expiresAt < now {
            throw DevaultImportError.expired
        }

        let salt = Data(bytes[cursor..<cursor + DevaultContainerHeader.saltByteCount])
        cursor += DevaultContainerHeader.saltByteCount

        let nonce = Data(bytes[cursor..<cursor + DevaultContainerHeader.nonceByteCount])

        return DevaultContainerHeader(version: version, expiresAt: expiresAt, salt: salt, nonce: nonce)
    }

    private static func unixSeconds(_ date: Date?) -> UInt64 {
        guard let date else { return 0 }
        let seconds = date.timeIntervalSince1970
        guard seconds.isFinite else { return UInt64.max }
        if seconds < 1 { return 1 }
        guard seconds < Double(UInt64.max) else { return UInt64.max }
        return UInt64(seconds)
    }

    private static func date(fromUnixSeconds seconds: UInt64) -> Date? {
        seconds == 0 ? nil : Date(timeIntervalSince1970: TimeInterval(seconds))
    }

    private static func bigEndianBytes(_ value: UInt16) -> [UInt8] {
        withUnsafeBytes(of: value.bigEndian) { Array($0) }
    }

    private static func bigEndianBytes(_ value: UInt64) -> [UInt8] {
        withUnsafeBytes(of: value.bigEndian) { Array($0) }
    }

    private static func uint16(fromBigEndianBytes bytes: ArraySlice<UInt8>) -> UInt16 {
        bytes.reduce(0) { ($0 << 8) | UInt16($1) }
    }

    private static func uint64(fromBigEndianBytes bytes: ArraySlice<UInt8>) -> UInt64 {
        bytes.reduce(0) { ($0 << 8) | UInt64($1) }
    }
}
