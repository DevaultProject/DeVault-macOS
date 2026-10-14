// Copyright © 2026 Devault. All rights reserved

import Foundation

/// AES-GCM으로 봉인/개봉하는 범용 암복호화 서비스입니다. `.dvt`가 뭔지는 모르고 바이트만 다룹니다.
public protocol DevaultCryptoService: Sendable {
    /// 새 nonce를 내부에서 생성해 평문을 봉인한다.
    /// - Parameters:
    ///   - plaintext: 봉인할 평문
    ///   - key: 대칭키
    ///   - aad: 인증에 포함할 추가 데이터(헤더 변조 탐지용)
    /// - Returns: 이번 봉인에 쓰인 nonce와, 봉인 결과(ciphertext+tag)
    func seal(plaintext: Data, key: Data, aad: Data) throws -> (nonce: Data, sealedData: Data)

    /// 봉인 시 쓰인 nonce를 그대로 받아 개봉한다.
    /// - Parameters:
    ///   - sealedData: 봉인 결과(ciphertext+tag)
    ///   - key: 대칭키
    ///   - nonce: 봉인 시 반환받은 nonce
    ///   - aad: 봉인 때와 동일해야 하는 추가 데이터
    /// - Returns: 복원된 평문
    func open(sealedData: Data, key: Data, nonce: Data, aad: Data) throws -> Data
}
