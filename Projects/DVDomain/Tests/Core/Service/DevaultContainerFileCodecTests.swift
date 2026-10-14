// Copyright © 2026 Devault. All rights reserved

import Foundation
import Testing

@testable import DVDomain

@Suite("DevaultContainerFileCodec")
struct DevaultContainerFileCodecTests {

    private let salt = Data(repeating: 0xAB, count: DevaultContainerHeader.saltByteCount)
    private let nonce = Data(repeating: 0xCD, count: DevaultContainerHeader.nonceByteCount)
    private let ciphertext = Data([0x01, 0x02, 0x03, 0x04, 0x05])

    @Test("영구(만료 없음) 헤더를 인코딩/디코딩하면 원본과 같다")
    func roundTripsPermanentHeader() throws {
        let header = DevaultContainerHeader(version: 1, expiresAt: nil, salt: salt, nonce: nonce)
        let encoded = DevaultContainerFileCodec.encode(header: header, ciphertext: ciphertext)

        let decoded = try DevaultContainerFileCodec.decode(encoded)

        #expect(decoded.header == header)
        #expect(decoded.ciphertext == ciphertext)
    }

    @Test("만료일이 있는 헤더를 인코딩/디코딩하면 초 단위까지 원본과 같다")
    func roundTripsHeaderWithExpiry() throws {
        let expiresAt = Date(timeIntervalSince1970: 2_000_000_000) // 정수 초 — 서브초 절삭 영향 없음
        let header = DevaultContainerHeader(version: 1, expiresAt: expiresAt, salt: salt, nonce: nonce)
        let encoded = DevaultContainerFileCodec.encode(header: header, ciphertext: ciphertext)

        let decoded = try DevaultContainerFileCodec.decode(encoded, now: Date(timeIntervalSince1970: 1_000_000_000))

        #expect(decoded.header == header)
    }

    @Test("길이가 45바이트 미만이면 corrupted를 던진다")
    func rejectsTooShortData() {
        let tooShort = Data(repeating: 0, count: DevaultContainerHeader.byteCount - 1)
        #expect(throws: DevaultImportError.corrupted) {
            try DevaultContainerFileCodec.decode(tooShort)
        }
    }

    @Test("magic이 틀리면 corrupted를 던진다")
    func rejectsWrongMagic() {
        let header = DevaultContainerHeader(version: 1, expiresAt: nil, salt: salt, nonce: nonce)
        var encoded = DevaultContainerFileCodec.encode(header: header, ciphertext: ciphertext)
        encoded[encoded.startIndex] = 0x00 // magic 첫 바이트 훼손

        #expect(throws: DevaultImportError.corrupted) {
            try DevaultContainerFileCodec.decode(encoded)
        }
    }

    @Test("version이 currentVersion과 다르면 versionMismatch를 던진다")
    func rejectsVersionMismatch() {
        let header = DevaultContainerHeader(version: 999, expiresAt: nil, salt: salt, nonce: nonce)
        let encoded = DevaultContainerFileCodec.encode(header: header, ciphertext: ciphertext)

        #expect(throws: DevaultImportError.versionMismatch) {
            try DevaultContainerFileCodec.decode(encoded)
        }
    }

    @Test("now가 expiresAt보다 미래면 expired를 던진다")
    func rejectsExpiredHeader() {
        let expiresAt = Date(timeIntervalSince1970: 1_000_000_000)
        let header = DevaultContainerHeader(version: 1, expiresAt: expiresAt, salt: salt, nonce: nonce)
        let encoded = DevaultContainerFileCodec.encode(header: header, ciphertext: ciphertext)

        #expect(throws: DevaultImportError.expired) {
            try DevaultContainerFileCodec.decode(encoded, now: Date(timeIntervalSince1970: 2_000_000_000))
        }
    }

    @Test("encodeHeader 결과는 encode(header:ciphertext:) 앞 45바이트와 같다 — AAD 재사용 정합성")
    func encodeHeaderMatchesFilePrefix() {
        let header = DevaultContainerHeader(version: 1, expiresAt: nil, salt: salt, nonce: nonce)
        let headerBytes = DevaultContainerFileCodec.encodeHeader(header)
        let fileBytes = DevaultContainerFileCodec.encode(header: header, ciphertext: ciphertext)

        #expect(headerBytes == fileBytes.prefix(DevaultContainerHeader.byteCount))
    }

    @Test("극단적으로 먼 미래의 expiresAt을 인코딩해도 크래시하지 않는다")
    func doesNotCrashOnExtremeFutureDate() {
        let extremeFuture = Date(timeIntervalSince1970: .greatestFiniteMagnitude)
        let header = DevaultContainerHeader(version: 1, expiresAt: extremeFuture, salt: salt, nonce: nonce)

        let encoded = DevaultContainerFileCodec.encodeHeader(header)

        #expect(encoded.count == DevaultContainerHeader.byteCount)
    }

    @Test("1970년 근접 expiresAt은 영구(nil) sentinel과 충돌하지 않는다")
    func nearEpochExpiryDoesNotCollideWithPermanentSentinel() throws {
        let nearEpoch = Date(timeIntervalSince1970: 0.5)
        let header = DevaultContainerHeader(version: 1, expiresAt: nearEpoch, salt: salt, nonce: nonce)
        let encoded = DevaultContainerFileCodec.encode(header: header, ciphertext: ciphertext)

        // now를 epoch 이전으로 둬서 expired 분기를 피하고, 디코딩된 expiresAt이 nil로 뭉개지지 않았는지만 확인한다.
        let decoded = try DevaultContainerFileCodec.decode(encoded, now: Date(timeIntervalSince1970: 0))

        #expect(decoded.header.expiresAt != nil)
    }
}
