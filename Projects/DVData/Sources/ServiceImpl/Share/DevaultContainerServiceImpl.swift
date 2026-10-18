// Copyright © 2026 Devault. All rights reserved

import CryptoKit
import DVDomain
import Foundation

public struct DevaultContainerServiceImpl: DevaultContainerService {
    private static let derivedKeyByteCount = 32 // AES-256

    private let passwordKeyDerivationService: any PasswordKeyDerivationService
    private let dateProvider: @Sendable () -> Date

    public init(
        passwordKeyDerivationService: any PasswordKeyDerivationService,
        dateProvider: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.passwordKeyDerivationService = passwordKeyDerivationService
        self.dateProvider = dateProvider
    }

    public func export(
        payload: DevaultContainerPayload,
        password: String,
        expiresAt: Date?
    ) async throws -> Data {
        let salt = Data((0..<DevaultContainerHeader.saltByteCount).map { _ in UInt8.random(in: .min ... .max) })
        var key = try await passwordKeyDerivationService.deriveKey(
            password: password,
            salt: salt,
            derivedKeyByteCount: Self.derivedKeyByteCount
        )
        defer { Self.wipe(&key) }

        var plaintext = try JSONEncoder().encode(payload)
        defer { Self.wipe(&plaintext) }

        let aad = DevaultContainerFileCodec.encodeHeaderPrefix(
            version: DevaultContainerHeader.currentVersion,
            expiresAt: expiresAt,
            salt: salt
        )
        let sealedBox = try AES.GCM.seal(plaintext, using: SymmetricKey(data: key), authenticating: aad)
        guard let combined = sealedBox.combined else {
            preconditionFailure("AES.GCM.seal의 nonce는 항상 12바이트라 combined가 nil일 수 없다")
        }

        return aad + combined
    }

    public func `import`(data: Data, password: String) async throws -> DevaultContainerPayload {
        let file = try DevaultContainerFileCodec.decode(data)

        // 비밀번호를 아는 사람은 재봉인해서 이 체크를 우회할 수 있다.
        if let expiresAt = file.header.expiresAt, expiresAt < dateProvider() {
            throw DevaultImportError.expired
        }

        var key: Data
        do {
            key = try await passwordKeyDerivationService.deriveKey(
                password: password,
                salt: file.header.salt,
                derivedKeyByteCount: Self.derivedKeyByteCount
            )
        } catch {
            throw DevaultImportError.invalidPassword
        }
        defer { Self.wipe(&key) }

        // AAD는 재인코딩 대신 파일 원본 바이트를 그대로 쓴다.
        let aadLength = DevaultContainerHeader.byteCount - DevaultContainerHeader.nonceByteCount
        let aad = data.prefix(aadLength)
        let combined = data.dropFirst(aadLength) // nonce + ciphertext + tag

        var plaintext: Data
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: combined)
            plaintext = try AES.GCM.open(sealedBox, using: SymmetricKey(data: key), authenticating: aad)
        } catch CryptoKitError.authenticationFailure {
            throw DevaultImportError.invalidPassword
        } catch {
            throw DevaultImportError.corrupted
        }
        defer { Self.wipe(&plaintext) }

        do {
            return try JSONDecoder().decode(DevaultContainerPayload.self, from: plaintext)
        } catch {
            throw DevaultImportError.corrupted
        }
    }

    /// best-effort — `data`가 공유 중이면 CoW로 원본이 안 지워질 수 있다.
    private static func wipe(_ data: inout Data) {
        data.withUnsafeMutableBytes { pointer in
            _ = memset_s(pointer.baseAddress, pointer.count, 0, pointer.count)
        }
    }
}
