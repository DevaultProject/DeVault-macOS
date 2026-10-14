// Copyright © 2026 Devault. All rights reserved

import CryptoKit
import DVDomain
import Foundation

public struct DevaultCryptoServiceImpl: DevaultCryptoService {

    public init() {}

    public func seal(plaintext: Data, key: Data, aad: Data) throws -> (nonce: Data, sealedData: Data) {
        let sealedBox = try AES.GCM.seal(plaintext, using: SymmetricKey(data: key), authenticating: aad)
        return (nonce: Data(sealedBox.nonce), sealedData: sealedBox.ciphertext + sealedBox.tag)
    }

    public func open(sealedData: Data, key: Data, nonce: Data, aad: Data) throws -> Data {
        // nonce + sealedData(ciphertext+tag)를 combined 형태로 다시 묶어 CryptoKit이 길이 검증까지 하도록 맡긴다.
        let sealedBox = try AES.GCM.SealedBox(combined: nonce + sealedData)
        return try AES.GCM.open(sealedBox, using: SymmetricKey(data: key), authenticating: aad)
    }
}
