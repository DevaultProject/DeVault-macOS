// Copyright © 2026 Devault. All rights reserved

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
        let key = try passwordKeyDerivationService.deriveKey(
            password: password,
            salt: salt,
            derivedKeyByteCount: Self.derivedKeyByteCount
        )

        let plaintext = try JSONEncoder().encode(payload)
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

        let key = try passwordKeyDerivationService.deriveKey(
            password: password,
            salt: file.header.salt,
            derivedKeyByteCount: Self.derivedKeyByteCount
        )

        let aad = DevaultContainerFileCodec.encodeHeaderPrefix(
            version: file.header.version,
            expiresAt: file.header.expiresAt,
            salt: file.header.salt
        )

        let plaintext: Data
        do {
            plaintext = try cryptoService.open(
                sealedData: file.ciphertext,
                key: key,
                nonce: file.header.nonce,
                aad: aad
            )
        } catch {
            throw DevaultImportError.wrongPassword
        }

        do {
            return try JSONDecoder().decode(DevaultContainerPayload.self, from: plaintext)
        } catch {
            throw DevaultImportError.corrupted
        }
    }
}
