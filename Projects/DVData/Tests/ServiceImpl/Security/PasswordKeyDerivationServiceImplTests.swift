// Copyright © 2026 Devault. All rights reserved

import DVDomain
import Foundation
import Testing
import argon2

@testable import DVData

@Suite("PasswordKeyDerivationServiceImpl")
struct PasswordKeyDerivationServiceImplTests {

    private let service = PasswordKeyDerivationServiceImpl()
    private let salt = Data(repeating: 0xAB, count: 16)

    @Test("같은 비밀번호·salt·길이면 항상 같은 키가 나온다")
    func deterministic() throws {
        let first = try service.deriveKey(password: "correct horse", salt: salt, derivedKeyByteCount: 32)
        let second = try service.deriveKey(password: "correct horse", salt: salt, derivedKeyByteCount: 32)
        #expect(first == second)
    }

    @Test("비밀번호가 다르면 다른 키가 나온다")
    func sensitiveToPassword() throws {
        let first = try service.deriveKey(password: "correct horse", salt: salt, derivedKeyByteCount: 32)
        let second = try service.deriveKey(password: "battery staple", salt: salt, derivedKeyByteCount: 32)
        #expect(first != second)
    }

    @Test("salt가 다르면 다른 키가 나온다")
    func sensitiveToSalt() throws {
        let otherSalt = Data(repeating: 0xCD, count: 16)
        let first = try service.deriveKey(password: "correct horse", salt: salt, derivedKeyByteCount: 32)
        let second = try service.deriveKey(password: "correct horse", salt: otherSalt, derivedKeyByteCount: 32)
        #expect(first != second)
    }

    @Test("요청한 바이트 길이만큼 키가 나온다")
    func respectsRequestedLength() throws {
        let key16 = try service.deriveKey(password: "correct horse", salt: salt, derivedKeyByteCount: 16)
        let key32 = try service.deriveKey(password: "correct horse", salt: salt, derivedKeyByteCount: 32)
        #expect(key16.count == 16)
        #expect(key32.count == 32)
    }

    @Test("빈 비밀번호·빈 salt·0 이하 길이는 invalidParameters를 던진다")
    func rejectsInvalidParameters() {
        #expect(throws: PasswordKeyDerivationError.invalidParameters) {
            try service.deriveKey(password: "", salt: salt, derivedKeyByteCount: 32)
        }
        #expect(throws: PasswordKeyDerivationError.invalidParameters) {
            try service.deriveKey(password: "correct horse", salt: Data(), derivedKeyByteCount: 32)
        }
        #expect(throws: PasswordKeyDerivationError.invalidParameters) {
            try service.deriveKey(password: "correct horse", salt: salt, derivedKeyByteCount: 0)
        }
    }

    @Test("공식 RFC 9106 Argon2id KAT 벡터와 일치한다")
    func matchesOfficialRFC9106Vector() {
        var passwordBytes = [UInt8](repeating: 0x01, count: 32)
        var saltBytes = [UInt8](repeating: 0x02, count: 16)
        var secretBytes = [UInt8](repeating: 0x03, count: 8)
        var adBytes = [UInt8](repeating: 0x04, count: 12)
        var outputBytes = [UInt8](repeating: 0, count: 32)

        let result = passwordBytes.withUnsafeMutableBufferPointer { pwdBuf in
            saltBytes.withUnsafeMutableBufferPointer { saltBuf in
                secretBytes.withUnsafeMutableBufferPointer { secretBuf in
                    adBytes.withUnsafeMutableBufferPointer { adBuf in
                        outputBytes.withUnsafeMutableBufferPointer { outBuf -> Int32 in
                            var context = argon2_context(
                                out: outBuf.baseAddress, outlen: UInt32(outBuf.count),
                                pwd: pwdBuf.baseAddress, pwdlen: UInt32(pwdBuf.count),
                                salt: saltBuf.baseAddress, saltlen: UInt32(saltBuf.count),
                                secret: secretBuf.baseAddress, secretlen: UInt32(secretBuf.count),
                                ad: adBuf.baseAddress, adlen: UInt32(adBuf.count),
                                t_cost: 3, m_cost: 32, lanes: 4, threads: 4,
                                version: 0x13,
                                allocate_cbk: nil, free_cbk: nil,
                                flags: 0
                            )
                            return argon2id_ctx(&context)
                        }
                    }
                }
            }
        }

        #expect(result == 0)
        #expect(Data(outputBytes) == Data([
            0x0d, 0x64, 0x0d, 0xf5, 0x8d, 0x78, 0x76, 0x6c,
            0x08, 0xc0, 0x37, 0xa3, 0x4a, 0x8b, 0x53, 0xc9,
            0xd0, 0x1e, 0xf0, 0x45, 0x2d, 0x75, 0xb6, 0x5e,
            0xb5, 0x25, 0x20, 0xe9, 0x6b, 0x01, 0xe6, 0x59
        ]))
    }
}
