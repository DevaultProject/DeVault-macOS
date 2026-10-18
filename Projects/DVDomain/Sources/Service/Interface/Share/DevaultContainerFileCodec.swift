// Copyright © 2026 Devault. All rights reserved

import Foundation

/// `.dvt` 컨테이너의 45바이트 헤더 + 암호문을 바이트로 조립/분리한다.
///
/// 레이아웃(고정 45바이트): magic(7) + version(2, big-endian) + expiresAt(8, unix seconds·big-endian·0=영구) + salt(16) + nonce(12).
public enum DevaultContainerFileCodec {

    /// 헤더와 ciphertext를 이어붙여 `.dvt` 파일 바이트를 만든다.
    /// - Parameters:
    ///   - header: 파일 앞부분에 쓸 헤더
    ///   - ciphertext: 헤더 뒤에 이어붙일 암호문
    /// - Returns: 완성된 `.dvt` 파일 바이트
    public static func encode(header: DevaultContainerHeader, ciphertext: Data) -> Data {
        encodeHeader(header) + ciphertext
    }

    /// `.dvt` 파일 바이트에서 헤더를 해석하고 암호문을 분리한다.
    /// - Parameters:
    ///   - data: `.dvt` 파일 전체 바이트
    ///   - now: 만료 판정에 쓸 현재 시각
    /// - Returns: 해석된 헤더와 분리된 암호문
    /// - Throws: 길이가 부족하거나 magic이 안 맞으면 `.corrupted`, 지원하는 버전이 아니면 `.versionMismatch`,
    ///   이미 만료됐으면 `.expired`
    public static func decode(_ data: Data, now: Date = Date()) throws -> DevaultContainerFile {
        guard data.count >= DevaultContainerHeader.byteCount else {
            throw DevaultImportError.corrupted
        }

        let header = try decodeHeader(Array(data.prefix(DevaultContainerHeader.byteCount)), now: now)
        let ciphertext = Data(data.dropFirst(DevaultContainerHeader.byteCount))

        return (header: header, ciphertext: ciphertext)
    }

    public static func encodeHeader(_ header: DevaultContainerHeader) -> Data {
        encodeHeaderPrefix(version: header.version, expiresAt: header.expiresAt, salt: header.salt) + header.nonce
    }

    /// nonce 확정 전에 AAD로 써야 해서 헤더에서 nonce만 뺀 바이트를 만든다.
    /// - Parameters:
    ///   - version: 포맷 버전
    ///   - expiresAt: 만료 시각(nil이면 영구)
    ///   - salt: KDF salt — 항상 `DevaultContainerHeader.saltByteCount`바이트여야 한다
    /// - Returns: `DevaultContainerHeader.byteCount - DevaultContainerHeader.nonceByteCount`바이트
    public static func encodeHeaderPrefix(version: UInt16, expiresAt: Date?, salt: Data) -> Data {
        precondition(
            salt.count == DevaultContainerHeader.saltByteCount,
            "salt는 항상 \(DevaultContainerHeader.saltByteCount)바이트여야 한다"
        )
        var bytes = Data()
        bytes.append(contentsOf: DevaultContainerHeader.magic)
        bytes.append(contentsOf: bigEndianBytes(version))
        bytes.append(contentsOf: bigEndianBytes(unixSeconds(expiresAt)))
        bytes.append(salt)
        return bytes
    }

    private static func decodeHeader(_ bytes: [UInt8], now: Date) throws -> DevaultContainerHeader {
        guard bytes.count == DevaultContainerHeader.byteCount else {
            throw DevaultImportError.corrupted
        }

        var cursor = 0

        let magicCount = DevaultContainerHeader.magic.count
        guard Array(bytes[cursor..<cursor + magicCount]) == DevaultContainerHeader.magic else {
            throw DevaultImportError.corrupted
        }
        cursor += magicCount

        let version: UInt16 = value(fromBigEndianBytes: bytes[cursor..<cursor + 2])
        guard version == DevaultContainerHeader.currentVersion else {
            throw DevaultImportError.versionMismatch
        }
        cursor += 2

        let expiresAtSeconds: UInt64 = value(fromBigEndianBytes: bytes[cursor..<cursor + 8])
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

    private static func bigEndianBytes<T: FixedWidthInteger>(_ value: T) -> [UInt8] {
        withUnsafeBytes(of: value.bigEndian, Array.init)
    }

    private static func value<T: FixedWidthInteger>(fromBigEndianBytes bytes: ArraySlice<UInt8>) -> T {
        bytes.reduce(0) { ($0 << 8) | T($1) }
    }
}
