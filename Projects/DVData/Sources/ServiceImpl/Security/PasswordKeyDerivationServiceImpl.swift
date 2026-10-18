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
        precondition(memoryCostKiB >= 8, "memoryCostKiB는 argon2 최소치(8KiB) 이상이어야 한다 — MiB 단위로 착각하지 않았는지 확인")
        precondition(timeCost >= 1, "timeCost는 1 이상이어야 한다")
        precondition(parallelism >= 1, "parallelism은 1 이상이어야 한다")
        self.memoryCostKiB = memoryCostKiB
        self.timeCost = timeCost
        self.parallelism = parallelism
    }

    public func deriveKey(
        password: String,
        salt: Data,
        derivedKeyByteCount: Int
    ) async throws -> Data {
        guard !password.isEmpty,
              salt.count >= Self.minimumSaltByteCount,
              derivedKeyByteCount >= 4
        else {
            throw PasswordKeyDerivationError.invalidParameters
        }

        var passwordBytes = Array(password.precomposedStringWithCanonicalMapping.utf8)
        defer {
            passwordBytes.withUnsafeMutableBytes { buffer in
                _ = memset_s(buffer.baseAddress, buffer.count, 0, buffer.count)
            }
        }
        var saltBytes = Array(salt)
        var output = [UInt8](repeating: 0, count: derivedKeyByteCount)
        defer {
            output.withUnsafeMutableBytes { buffer in
                _ = memset_s(buffer.baseAddress, buffer.count, 0, buffer.count)
            }
        }

        let result = argon2id_hash_raw(
            timeCost, memoryCostKiB, parallelism,
            &passwordBytes, passwordBytes.count,
            &saltBytes, saltBytes.count,
            &output, output.count
        )

        guard result == ARGON2_OK.rawValue else {
            throw PasswordKeyDerivationError.derivationFailed(code: result)
        }

        return Data(output)
    }
}
