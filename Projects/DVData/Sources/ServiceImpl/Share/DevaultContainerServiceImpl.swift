// Copyright © 2026 Devault. All rights reserved

import CryptoKit
import DVDomain
import Foundation

public struct DevaultContainerServiceImpl: DevaultContainerService {
    private static let derivedKeyByteCount = 32 // AES-256

    private let passwordKeyDerivationService: any PasswordKeyDerivationService
    private let cryptoService: any DevaultCryptoService

    public init(
        passwordKeyDerivationService: any PasswordKeyDerivationService,
        cryptoService: any DevaultCryptoService
    ) {
        self.passwordKeyDerivationService = passwordKeyDerivationService
        self.cryptoService = cryptoService
    }

    public func export(
        payload: DevaultContainerPayload,
        password: String,
        expiresAt: Date?
    ) throws -> Data {
        let salt = Data((0..<DevaultContainerHeader.saltByteCount).map { _ in UInt8.random(in: .min ... .max) })
        var key = try passwordKeyDerivationService.deriveKey(
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
        let (nonce, sealedData) = try cryptoService.seal(plaintext: plaintext, key: key, aad: aad)

        let header = DevaultContainerHeader(
            version: DevaultContainerHeader.currentVersion,
            expiresAt: expiresAt,
            salt: salt,
            nonce: nonce
        )
        return DevaultContainerFileCodec.encode(header: header, ciphertext: sealedData)
    }

    public func `import`(data: Data, password: String) throws -> DevaultContainerPayload {
        let file = try DevaultContainerFileCodec.decode(data)

        var key: Data
        do {
            key = try passwordKeyDerivationService.deriveKey(
                password: password,
                salt: file.header.salt,
                derivedKeyByteCount: Self.derivedKeyByteCount
            )
        } catch {
            throw DevaultImportError.invalidPassword
        }
        defer { Self.wipe(&key) }

        // AAD는 재인코딩 대신 파일 원본 바이트를 그대로 쓴다.
        let aad = data.prefix(DevaultContainerHeader.byteCount - DevaultContainerHeader.nonceByteCount)

        var plaintext: Data
        do {
            plaintext = try cryptoService.open(
                sealedData: file.ciphertext,
                key: key,
                nonce: file.header.nonce,
                aad: aad
            )
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
