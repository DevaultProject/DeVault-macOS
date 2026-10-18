// Copyright © 2026 Devault. All rights reserved

import CryptoKit
import DVDomain
import Foundation

public struct DevaultContainerServiceImpl: DevaultContainerService {
    private static let derivedKeyByteCount = 32 // AES-256

    private let passwordKeyDerivationService: PasswordKeyDerivationService
    private let cryptoService: DevaultCryptoService

    public init(
        passwordKeyDerivationService: PasswordKeyDerivationService,
        cryptoService: DevaultCryptoService
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

        let aad = DevaultContainerFileCodec.encodeHeaderPrefix(
            version: file.header.version,
            expiresAt: file.header.expiresAt,
            salt: file.header.salt
        )

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

    private static func wipe(_ data: inout Data) {
        data.withUnsafeMutableBytes { pointer in
            _ = memset_s(pointer.baseAddress, pointer.count, 0, pointer.count)
        }
    }
}
