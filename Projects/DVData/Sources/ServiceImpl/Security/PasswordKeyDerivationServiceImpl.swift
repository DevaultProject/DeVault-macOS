// Copyright © 2026 Devault. All rights reserved

import DVDomain
import Foundation
import argon2

public struct PasswordKeyDerivationServiceImpl: PasswordKeyDerivationService {
    private static let minimumSaltByteCount = 16  // RFC 9106 권장 최소 salt 길이

    private let memoryCostKiB: UInt32
    private let timeCost: UInt32
    private let parallelism: UInt32

    /// m=64MiB·t=3·p=4는 잠정값 — 지원 최저 사양 기기 실측(m=192~256MiB) 후 교체 예정.
    public init(
        memoryCostKiB: UInt32 = 64 * 1024,
        timeCost: UInt32 = 3,
        parallelism: UInt32 = 4
    ) {
        self.memoryCostKiB = memoryCostKiB
        self.timeCost = timeCost
        self.parallelism = parallelism
    }

    public func deriveKey(
        password: String,
        salt: Data,
        derivedKeyByteCount: Int
    ) throws -> Data {
        guard !password.isEmpty,
              salt.count >= Self.minimumSaltByteCount,
              derivedKeyByteCount >= 4
        else {
            throw PasswordKeyDerivationError.invalidParameters
        }

        var passwordBytes = Array(password.precomposedStringWithCanonicalMapping.utf8)
        defer {
            for index in passwordBytes.indices {
                passwordBytes[index] = 0
            }
        }
        var saltBytes = Array(salt)
        var output = [UInt8](repeating: 0, count: derivedKeyByteCount)

        let result = argon2id_hash_raw(
            timeCost, memoryCostKiB, parallelism,
            &passwordBytes, passwordBytes.count,
            &saltBytes, saltBytes.count,
            &output, output.count
        )

        // ARGON2_OK == 0으로 문서화 존재 — 브리징된 enum 이름에 기대지 않고 원시 코드로 비교.
        guard result == 0 else {
            throw PasswordKeyDerivationError.derivationFailed(code: result)
        }

        return Data(output)
    }
}
