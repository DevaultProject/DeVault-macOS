// Copyright © 2026 Devault. All rights reserved

import Foundation
import Testing

@testable import DVData

@Suite("DevaultCryptoServiceImpl")
struct DevaultCryptoServiceImplTests {

    private let service = DevaultCryptoServiceImpl()
    private let key = Data(repeating: 0x11, count: 32)
    private let aad = Data(repeating: 0x22, count: 33)
    private let plaintext = Data("secret payload".utf8)

    @Test("봉인 후 같은 키·nonce·aad로 개봉하면 원문이 복원된다")
    func roundTrips() throws {
        let (nonce, sealedData) = try service.seal(plaintext: plaintext, key: key, aad: aad)
        let opened = try service.open(sealedData: sealedData, key: key, nonce: nonce, aad: aad)
        #expect(opened == plaintext)
    }

    @Test("같은 입력으로 두 번 봉인해도 nonce가 매번 다르다")
    func generatesFreshNonceEachSeal() throws {
        let first = try service.seal(plaintext: plaintext, key: key, aad: aad)
        let second = try service.seal(plaintext: plaintext, key: key, aad: aad)
        #expect(first.nonce != second.nonce)
    }

    @Test("키가 다르면 개봉이 실패한다")
    func failsWithWrongKey() throws {
        let (nonce, sealedData) = try service.seal(plaintext: plaintext, key: key, aad: aad)
        let wrongKey = Data(repeating: 0x33, count: 32)

        #expect(throws: (any Error).self) {
            try service.open(sealedData: sealedData, key: wrongKey, nonce: nonce, aad: aad)
        }
    }

    @Test("aad가 다르면(헤더 변조) 개봉이 실패한다")
    func failsWithTamperedAAD() throws {
        let (nonce, sealedData) = try service.seal(plaintext: plaintext, key: key, aad: aad)
        let tamperedAAD = Data(repeating: 0x99, count: 33)

        #expect(throws: (any Error).self) {
            try service.open(sealedData: sealedData, key: key, nonce: nonce, aad: tamperedAAD)
        }
    }

    @Test("ciphertext가 변조되면 개봉이 실패한다")
    func failsWithTamperedCiphertext() throws {
        let (nonce, sealedData) = try service.seal(plaintext: plaintext, key: key, aad: aad)
        var tampered = sealedData
        tampered[tampered.startIndex] ^= 0xFF

        #expect(throws: (any Error).self) {
            try service.open(sealedData: tampered, key: key, nonce: nonce, aad: aad)
        }
    }

    @Test("nonce가 다르면 개봉이 실패한다")
    func failsWithWrongNonce() throws {
        let (_, sealedData) = try service.seal(plaintext: plaintext, key: key, aad: aad)
        let wrongNonce = Data(repeating: 0x44, count: 12)

        #expect(throws: (any Error).self) {
            try service.open(sealedData: sealedData, key: key, nonce: wrongNonce, aad: aad)
        }
    }
}
